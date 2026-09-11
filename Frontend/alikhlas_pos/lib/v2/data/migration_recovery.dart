import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Guards an on-device schema upgrade with a durable, verified pre-upgrade copy.
///
/// This runs before Drift opens the database. A process interruption while a
/// migration is running restores the old database and refuses another attempt
/// by this build, so it cannot silently compound partial schema changes.
class MigrationRecovery {
  MigrationRecovery(this.live, {required this.targetVersion});

  final File live;
  final int targetVersion;

  File get marker => File('${live.path}.migration-pending');
  File get _migratingMarker => File('${marker.path}.migrating');
  File get _failedMarker => File('${marker.path}.failed');

  /// The initial marker is never overwritten. State transitions publish a
  /// separate, immutable marker through temp -> flush -> rename. This avoids
  /// replacing an open file, which is not reliably atomic on Windows.
  List<(File, _MigrationState)> get _markerFiles => [
    (_failedMarker, _MigrationState.failed),
    (_migratingMarker, _MigrationState.migrating),
    (marker, _MigrationState.prepared),
  ];

  /// Creates the pre-upgrade copy or refuses a database from a newer build.
  Future<void> prepareForOpen() async {
    if (!await live.exists()) return;

    final previous = await _readMarker();
    if (previous != null) await _resolvePreviousAttempt(previous);

    final version = _checkedVersion(live);
    if (version > targetVersion) {
      throw DatabaseVersionTooNew(
        databaseVersion: version,
        supportedVersion: targetVersion,
      );
    }
    if (version == 0) {
      if (_hasUserTables(live)) throw const DatabaseSchemaVersionUnknown();
      return;
    }
    if (version < targetVersion) await _createVerifiedSnapshot(version);
  }

  /// Called as the first operation inside Drift's [MigrationStrategy.onUpgrade].
  Future<void> markMigrationStarted({
    required int from,
    required int to,
  }) async {
    final record = await _readMarker();
    // File-backed test connections may exercise a historical migration without
    // the production startup guard. They retain Drift's established behavior.
    if (record == null) return;
    if (record.from != from ||
        record.to != to ||
        record.target != targetVersion) {
      throw const DatabaseMigrationFailed(
        'بيانات حراسة التحديث لا تطابق قاعدة البيانات الحالية.',
      );
    }
    if (record.state == _MigrationState.prepared) {
      await _writeMarker(record.copyWith(state: _MigrationState.migrating));
      return;
    }
    if (record.state != _MigrationState.migrating) {
      throw const DatabaseMigrationFailed(
        'تحديث سابق لقاعدة البيانات يحتاج معالجة قبل المتابعة.',
      );
    }
  }

  /// Clears a completed marker only after Drift has recorded its new version.
  Future<void> finalizeIfSuccessful(int currentVersion) async {
    final record = await _readMarker();
    if (record == null) return;
    if (record.state != _MigrationState.migrating ||
        record.target != targetVersion ||
        record.to != currentVersion) {
      return;
    }
    await _verifiedSnapshot(record);
    await _deleteMarkers();
  }

  /// Exposed for narrow tests and diagnostics; the app never displays its path.
  Future<File?> pendingSnapshot() async {
    final record = await _readMarker();
    return record == null ? null : File(record.snapshotPath);
  }

  Future<void> _resolvePreviousAttempt(_MigrationMarker record) async {
    final snapshot = await _verifiedSnapshot(record);
    final currentVersion = _checkedVersion(live);
    if (record.state == _MigrationState.prepared &&
        currentVersion == record.from) {
      // The process ended before Drift began the migration. Start again with a
      // fresh snapshot instead of treating that harmless interruption as loss.
      await _deleteMarkers();
      return;
    }
    if (record.state == _MigrationState.migrating &&
        currentVersion == record.to &&
        record.target == targetVersion) {
      // Drift writes user_version only after all migration callbacks succeed.
      await _deleteMarkers();
      return;
    }
    if (record.state != _MigrationState.failed) {
      await _restoreSnapshot(snapshot, expectedVersion: record.from);
      await _writeMarker(record.copyWith(state: _MigrationState.failed));
    }
    throw const DatabaseMigrationFailed(
      'تعذر إكمال تحديث قاعدة البيانات. أُعيدت نسخة ما قبل التحديث ولم يُفتح المحل. افتح الإصدار السابق أو تواصل مع الدعم مع الاحتفاظ بالنسخة.',
    );
  }

  Future<void> _createVerifiedSnapshot(int from) async {
    final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final snapshot = File(
      '${live.path}.migration-preupgrade-$from-to$targetVersion-$stamp.db',
    );
    final partial = File('${snapshot.path}.partial');
    try {
      _vacuumInto(live, partial);
      final copiedVersion = _checkedVersion(partial);
      if (copiedVersion != from) {
        throw const FormatException(
          'نسخة ما قبل التحديث تحمل إصدارًا غير متوقع.',
        );
      }
      await _flush(partial);
      await partial.rename(snapshot.path);
      final digest = await _sha256File(snapshot);
      await _createMarker(
        _MigrationMarker(
          state: _MigrationState.prepared,
          from: from,
          to: targetVersion,
          target: targetVersion,
          snapshotPath: snapshot.absolute.path,
          snapshotSha256: digest,
        ),
      );
    } on DatabaseMigrationSnapshotFailed {
      rethrow;
    } on Object {
      if (await partial.exists()) await partial.delete();
      throw const DatabaseMigrationSnapshotFailed();
    }
  }

  Future<File> _verifiedSnapshot(_MigrationMarker record) async {
    if (record.target != targetVersion ||
        !_safeSnapshotPath(record.snapshotPath)) {
      throw const DatabaseMigrationFailed(
        'ملف حماية التحديث غير صالح. لم يتم فتح بيانات المحل.',
      );
    }
    final snapshot = File(record.snapshotPath);
    if (await FileSystemEntity.type(snapshot.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const DatabaseMigrationFailed(
        'نسخة ما قبل التحديث غير متاحة. لم يتم فتح بيانات المحل.',
      );
    }
    if (await _sha256File(snapshot) != record.snapshotSha256) {
      throw const DatabaseMigrationFailed(
        'نسخة ما قبل التحديث تغيرت أو تلفت. احتفظ بالملفات وتواصل مع الدعم.',
      );
    }
    if (_checkedVersion(snapshot) != record.from) {
      throw const DatabaseMigrationFailed(
        'نسخة ما قبل التحديث لا تطابق إصدارها المسجل. لم يتم فتح بيانات المحل.',
      );
    }
    return snapshot;
  }

  Future<void> _restoreSnapshot(
    File snapshot, {
    required int expectedVersion,
  }) async {
    final staging = File('${live.path}.migration-recovering');
    if (await staging.exists()) await staging.delete();
    await snapshot.copy(staging.path);
    await _flush(staging);
    if (_checkedVersion(staging) != expectedVersion) {
      throw const DatabaseMigrationFailed(
        'تعذر التحقق من استعادة نسخة ما قبل التحديث.',
      );
    }
    for (final file in [
      File('${live.path}-wal'),
      File('${live.path}-shm'),
      live,
    ]) {
      if (await file.exists()) await file.delete();
    }
    await staging.rename(live.path);
    if (_checkedVersion(live) != expectedVersion) {
      throw const DatabaseMigrationFailed(
        'تعذر التحقق من قاعدة البيانات بعد استعادة النسخة السابقة.',
      );
    }
  }

  Future<_MigrationMarker?> _readMarker() async {
    final records = <_MigrationMarker>[];
    for (final (file, expectedState) in _markerFiles) {
      if (!await file.exists()) continue;
      try {
        final record = _MigrationMarker.fromJson(
          jsonDecode(await file.readAsString()),
        );
        if (record.state != expectedState) throw const FormatException();
        records.add(record);
      } on Object {
        throw const DatabaseMigrationFailed(
          'ملف حماية تحديث قاعدة البيانات غير قابل للقراءة. لم يتم فتح بيانات المحل.',
        );
      }
    }
    if (records.isEmpty) return null;

    final first = records.first;
    if (records.any(
      (record) =>
          record.from != first.from ||
          record.to != first.to ||
          record.target != first.target ||
          record.snapshotPath != first.snapshotPath ||
          record.snapshotSha256 != first.snapshotSha256,
    )) {
      throw const DatabaseMigrationFailed(
        'ملفات حماية تحديث قاعدة البيانات متعارضة. لم يتم فتح بيانات المحل.',
      );
    }
    // The ordering above deliberately makes failed win over migrating, and
    // migrating win over prepared after an interrupted state transition.
    return first;
  }

  Future<void> _createMarker(_MigrationMarker record) async {
    if ((await Future.wait(
      _markerFiles.map((entry) => entry.$1.exists()),
    )).any((exists) => exists)) {
      throw const DatabaseMigrationFailed(
        'يوجد تحديث سابق لقاعدة البيانات يحتاج معالجة قبل المتابعة.',
      );
    }
    await _publishMarker(marker, record);
  }

  Future<void> _writeMarker(_MigrationMarker record) async {
    final destination = switch (record.state) {
      _MigrationState.prepared => marker,
      _MigrationState.migrating => _migratingMarker,
      _MigrationState.failed => _failedMarker,
    };
    if (record.state == _MigrationState.prepared) {
      throw StateError('The prepared migration marker is immutable.');
    }
    if (await destination.exists()) return;
    await _publishMarker(destination, record);
  }

  Future<void> _publishMarker(File destination, _MigrationMarker record) async {
    final temporary = File('${destination.path}.tmp');
    if (await temporary.exists()) await temporary.delete();
    await temporary.writeAsString(jsonEncode(record.toJson()), flush: true);
    await temporary.rename(destination.path);
  }

  Future<void> _deleteMarkers() async {
    for (final (file, _) in _markerFiles) {
      if (await file.exists()) await file.delete();
    }
  }

  bool _safeSnapshotPath(String source) {
    final snapshot = File(source).absolute.path;
    final prefix = '${live.absolute.path}.migration-preupgrade-';
    return snapshot.startsWith(prefix) && snapshot.endsWith('.db');
  }

  int _checkedVersion(File file) {
    sqlite.Database? database;
    try {
      database = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
      final integrity = database.select('PRAGMA quick_check;');
      if (integrity.length != 1 || integrity.single.values.single != 'ok') {
        throw const FormatException('ملف قاعدة البيانات غير سليم.');
      }
      return database.select('PRAGMA user_version;').single.values.single
          as int;
    } on sqlite.SqliteException {
      throw const DatabaseMigrationFailed(
        'ملف قاعدة البيانات غير قابل للقراءة. لم يتم بدء التحديث.',
      );
    } finally {
      database?.close();
    }
  }

  bool _hasUserTables(File file) {
    sqlite.Database? database;
    try {
      database = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
      return database
          .select(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' LIMIT 1;",
          )
          .isNotEmpty;
    } finally {
      database?.close();
    }
  }

  void _vacuumInto(File source, File target) {
    sqlite.Database? database;
    try {
      database = sqlite.sqlite3.open(source.path);
      final escaped = target.path.replaceAll("'", "''");
      database.execute("VACUUM INTO '$escaped';");
    } finally {
      database?.close();
    }
  }

  Future<void> _flush(File file) async {
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  Future<String> _sha256File(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();
}

enum _MigrationState { prepared, migrating, failed }

class _MigrationMarker {
  const _MigrationMarker({
    required this.state,
    required this.from,
    required this.to,
    required this.target,
    required this.snapshotPath,
    required this.snapshotSha256,
  });

  final _MigrationState state;
  final int from;
  final int to;
  final int target;
  final String snapshotPath;
  final String snapshotSha256;

  _MigrationMarker copyWith({_MigrationState? state}) => _MigrationMarker(
    state: state ?? this.state,
    from: from,
    to: to,
    target: target,
    snapshotPath: snapshotPath,
    snapshotSha256: snapshotSha256,
  );

  Map<String, Object> toJson() => {
    'formatVersion': 1,
    'state': state.name,
    'from': from,
    'to': to,
    'target': target,
    'snapshotPath': snapshotPath,
    'snapshotSha256': snapshotSha256,
  };

  factory _MigrationMarker.fromJson(Object source) {
    if (source is! Map ||
        source['formatVersion'] != 1 ||
        source['state'] is! String ||
        source['from'] is! int ||
        source['to'] is! int ||
        source['target'] is! int ||
        source['snapshotPath'] is! String ||
        source['snapshotSha256'] is! String) {
      throw const FormatException('Invalid migration marker');
    }
    final state = _MigrationState.values.where(
      (candidate) => candidate.name == source['state'],
    );
    final digest = source['snapshotSha256'] as String;
    if (state.length != 1 ||
        source['from'] as int <= 0 ||
        source['to'] as int <= 0 ||
        source['target'] as int <= 0 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const FormatException('Invalid migration marker');
    }
    return _MigrationMarker(
      state: state.single,
      from: source['from'] as int,
      to: source['to'] as int,
      target: source['target'] as int,
      snapshotPath: source['snapshotPath'] as String,
      snapshotSha256: digest,
    );
  }
}

class DatabaseVersionTooNew implements Exception {
  const DatabaseVersionTooNew({
    required this.databaseVersion,
    required this.supportedVersion,
  });

  final int databaseVersion;
  final int supportedVersion;

  @override
  String toString() =>
      'هذه البيانات أحدث من نسخة التطبيق الحالية. ثبّت إصدارًا أحدث ولا تفتحها بإصدار أقدم.';
}

class DatabaseSchemaVersionUnknown implements Exception {
  const DatabaseSchemaVersionUnknown();

  @override
  String toString() =>
      'تعذر تحديد إصدار بيانات المحل بأمان. لم يبدأ التحديث؛ احتفظ بالملف وتواصل مع الدعم.';
}

class DatabaseMigrationSnapshotFailed implements Exception {
  const DatabaseMigrationSnapshotFailed();

  @override
  String toString() =>
      'تعذر تحضير نسخة آمنة قبل تحديث البيانات. تحقق من مساحة القرص وصلاحية المجلد ثم أعد المحاولة؛ لم يبدأ التحديث.';
}

class DatabaseMigrationFailed implements Exception {
  const DatabaseMigrationFailed(this.message);
  final String message;

  @override
  String toString() => message;
}

class DatabaseMigrationFailedDuringUpgrade implements Exception {
  const DatabaseMigrationFailedDuringUpgrade({
    required this.from,
    required this.to,
  });

  final int from;
  final int to;

  @override
  String toString() =>
      'تعذر إكمال تحديث بيانات المحل. أغلق التطبيق؛ ستتم استعادة نسخة ما قبل التحديث عند التشغيل التالي.';
}
