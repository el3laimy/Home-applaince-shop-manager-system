part of '../v2_use_cases.dart';

const _backupDestinationUnavailable =
    'مجلد النسخ غير متاح. اختر مجلدًا آخر أو أعد توصيل وسيط النسخ.';

extension V2BackupSettingsUseCases on V2UseCases {
  Future<File> backupToDirectory(Directory directory) async {
    if (_backupRunning || _restoreRunning || databaseClosedForRestore) {
      throw StateError('انتظر انتهاء النسخ أو الاسترجاع الحالي.');
    }
    _backupRunning = true;
    try {
      return await _writeBackup(directory);
    } finally {
      _backupRunning = false;
    }
  }

  Future<File> _writeBackup(Directory directory) async {
    await directory.create(recursive: true);
    final keep = await _backupRetentionCopies();
    final timestamp = clock().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final target = File(p.join(directory.path, 'alikhlas-v2-$timestamp.db'));
    await _writeDatabaseSnapshot(target);
    final pruneFailures = await _pruneBackups(directory, keep: keep);
    backupWarning = pruneFailures.isEmpty
        ? null
        : 'تم إنشاء النسخة الاحتياطية، لكن تعذر حذف ${pruneFailures.length} نسخة قديمة. راجع مساحة التخزين.';
    return target;
  }

  Future<void> _writeDatabaseSnapshot(File target) async {
    await target.parent.create(recursive: true);
    final escaped = target.path.replaceAll("'", "''");
    await db.customStatement("VACUUM INTO '$escaped';");
  }

  Future<File> _currentDatabaseFile() async {
    final current = await db.customSelect('PRAGMA database_list;').getSingle();
    final path = current.data['file'] as String?;
    if (path == null || path.isEmpty) {
      throw StateError('Cannot resolve current SQLite file path.');
    }
    return File(path);
  }

  Future<void> setBackupDirectory(String path) async {
    await _writeTransaction(() => _upsertSetting('backup.directory', path));
  }

  Future<File?> runAutomaticBackupIfDue() async {
    if (_automaticBackupRunning ||
        _backupRunning ||
        _restoreRunning ||
        databaseClosedForRestore) {
      return null;
    }
    _automaticBackupRunning = true;
    try {
      final path = await _settingValue('backup.directory');
      if (path == null || path.trim().isEmpty) return null;
      final now = clock();
      final last = DateTime.tryParse(
        await _settingValue('backup.lastSuccessAt') ?? '',
      );
      if (last != null &&
          !now.isBefore(last) &&
          now.difference(last) < const Duration(minutes: 30)) {
        // Keep destination health current even when another copy is not due.
        await _inspectBackupDestination(Directory(path));
        return null;
      }
      final backup = await backupToDirectory(Directory(path));
      await _upsertSetting('backup.lastSuccessAt', now.toIso8601String());
      await _upsertSetting('backup.lastDate', _dateKey(now));
      return backup;
    } finally {
      _automaticBackupRunning = false;
    }
  }

  Future<File?> tryAutomaticBackup() async {
    try {
      return await runAutomaticBackupIfDue();
    } on FileSystemException {
      backupWarning =
          'تعذر إنشاء النسخة الاحتياطية. تحقق من وسيط النسخ أو اختر مجلدًا آخر. سنعيد المحاولة تلقائيًا.';
    } on sqlite.SqliteException {
      backupWarning =
          'لم تكتمل النسخة الاحتياطية. تحقق من المساحة المتاحة. سنعيد المحاولة تلقائيًا.';
    }
    return null;
  }

  Future<void> restoreFromBackup(File backupFile) async {
    if (_backupRunning ||
        _automaticBackupRunning ||
        _restoreRunning ||
        databaseClosedForRestore) {
      throw StateError('انتظر انتهاء النسخ أو أعد فتح التطبيق بعد الاسترجاع.');
    }
    _restoreRunning = true;
    try {
      await _withRestoreWriteBarrier(() => _restoreBackupFile(backupFile));
    } finally {
      _restoreRunning = false;
    }
  }

  Future<void> _restoreBackupFile(File backupFile) async {
    if (!await backupFile.exists()) {
      throw ArgumentError('Backup file does not exist: ${backupFile.path}');
    }
    _validateRestoreFile(backupFile);
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
    final dbFile = await _currentDatabaseFile();
    final dbPath = dbFile.path;
    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');
    final recovery = RestoreRecovery(dbFile);
    final stagingDirectory = await Directory(
      p.dirname(dbPath),
    ).createTemp('restore-candidate-');
    final candidate = File(p.join(stagingDirectory.path, 'candidate.db'));
    await backupFile.copy(candidate.path);
    _validateRestoreFile(candidate);
    if (await recovery.marker.exists()) {
      throw StateError('يوجد استرجاع غير مكتمل. أعد تشغيل التطبيق أولًا.');
    }
    if (await recovery.rollback.exists()) await recovery.rollback.delete();
    final escapedRollback = recovery.rollback.path.replaceAll("'", "''");
    // SQLite creates a consistent snapshot, including committed WAL content.
    await db.customStatement("VACUUM INTO '$escapedRollback';");
    await db.close();
    databaseClosedForRestore = true;
    await recovery.markPending();
    try {
      await _restoreFiles.deleteFileIfExists(walFile);
      await _restoreFiles.deleteFileIfExists(shmFile);
      await _restoreFiles.copyFile(candidate, dbFile);
      _validateRestoreFile(dbFile);
      await recovery.commit();
    } catch (_) {
      await recovery.recoverIfPending();
      rethrow;
    } finally {
      try {
        await stagingDirectory.delete(recursive: true);
      } on FileSystemException {
        // Cleanup must not turn a committed restore into an apparent failure.
      }
    }
  }

  void _validateRestoreFile(File file) {
    sqlite.Database? candidate;
    try {
      candidate = sqlite.sqlite3.open(
        file.path,
        mode: sqlite.OpenMode.readOnly,
      );
      final integrity = candidate.select('PRAGMA quick_check;');
      if (integrity.length != 1 || integrity.single.values.single != 'ok') {
        throw const FormatException(
          'النسخة الاحتياطية تالفة. لم يتم اعتماد الاسترجاع.',
        );
      }
      final version = candidate
          .select('PRAGMA user_version;')
          .single
          .values
          .single;
      if (version != db.schemaVersion) {
        throw const FormatException(
          'إصدار النسخة غير متوافق. استخدم نسخة من نفس إصدار البيانات.',
        );
      }
      for (final table in db.allTables) {
        final columns = table.$columns
            .map((column) => '"${column.$name}"')
            .join(', ');
        candidate.select(
          'SELECT $columns FROM "${table.actualTableName}" LIMIT 0;',
        );
        final actualColumns = candidate
            .select('PRAGMA table_info("${table.actualTableName}");')
            .map((row) => row['name'])
            .toSet();
        if (!table.$columns.every(
          (column) => actualColumns.contains(column.$name),
        )) {
          throw const FormatException(
            'النسخة لا تحتوي بيانات التطبيق المطلوبة.',
          );
        }
      }
      if (candidate.select('PRAGMA foreign_key_check;').isNotEmpty) {
        throw const FormatException('النسخة تحتوي مراجع بيانات غير سليمة.');
      }
    } on sqlite.SqliteException {
      throw const FormatException('ملف النسخة غير صالح أو غير قابل للقراءة.');
    } finally {
      candidate?.close();
    }
  }

  Future<void> _upsertSetting(String key, String value) async {
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  Future<void> _upsertSettingIfMissing(String key, String value) async {
    final existing = await _settingValue(key);
    if (existing == null) {
      await _upsertSetting(key, value);
    }
  }

  Future<String?> _settingValue(String key) async {
    final setting = await (db.select(
      db.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return setting?.value;
  }

  Future<List<File>> _pruneBackups(
    Directory directory, {
    required int keep,
  }) async {
    final backups = await _backupFiles(directory);
    final failures = <File>[];
    for (final backup in backups.skip(keep)) {
      try {
        await _backupFileOperations.deleteFile(backup);
      } on FileSystemException {
        failures.add(backup);
      }
    }
    return failures;
  }

  Future<BackupStatus> _backupStatus() async {
    final directoryPath = await _settingValue('backup.directory');
    final retentionCopies = await _backupRetentionCopies();
    if (directoryPath == null || directoryPath.trim().isEmpty) {
      return BackupStatus(
        lastDate: await _settingValue('backup.lastDate'),
        retentionCopies: retentionCopies,
      );
    }

    final backups = await _inspectBackupDestination(Directory(directoryPath));
    return BackupStatus(
      directory: directoryPath,
      warning: backupWarning,
      lastDate: await _settingValue('backup.lastDate'),
      latestBackupPath: backups.isEmpty ? null : backups.first.path,
      backupCount: backups.length,
      retentionCopies: retentionCopies,
    );
  }

  Future<List<File>> _inspectBackupDestination(Directory directory) async {
    try {
      final backups = await _backupFiles(directory);
      // Reconnecting clears only this warning, not a previous write failure.
      if (backupWarning == _backupDestinationUnavailable) backupWarning = null;
      return backups;
    } on FileSystemException {
      backupWarning = _backupDestinationUnavailable;
      return [];
    }
  }

  Future<List<File>> _backupFiles(Directory directory) async {
    final backups = await directory
        .list()
        .where(
          (entity) =>
              entity is File &&
              p.basename(entity.path).startsWith('alikhlas-v2-') &&
              p.extension(entity.path) == '.db',
        )
        .cast<File>()
        .toList();
    backups.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return backups;
  }

  Future<int> _backupRetentionCopies() async {
    final configuredCopies = await _integerSetting(
      'backup.keepCopies',
      fallback: 30,
    );
    return configuredCopies < 1 ? 30 : configuredCopies;
  }

  Future<int> _integerSetting(String key, {required int fallback}) async {
    return int.tryParse(await _settingValue(key) ?? '') ?? fallback;
  }
}
