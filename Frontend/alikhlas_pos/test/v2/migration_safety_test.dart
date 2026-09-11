import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:alikhlas_pos/v2/data/migration_recovery.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('a verified v4 snapshot survives the successful v8 migration', () async {
    final directory = await Directory.systemTemp.createTemp('migration-safe-');
    addTearDown(() => directory.delete(recursive: true));
    final live = File('${directory.path}/shop.db');
    await _createV4Database(live);
    final recovery = MigrationRecovery(
      live,
      targetVersion: kAppDatabaseSchemaVersion,
    );

    await recovery.prepareForOpen();

    final snapshot = await recovery.pendingSnapshot();
    expect(snapshot, isNotNull);
    expect(await snapshot!.exists(), isTrue);
    expect(_version(snapshot), 4);
    expect(_setting(snapshot, 'migration.evidence'), 'before-upgrade');
    expect(await recovery.marker.exists(), isTrue);

    final db = AppDatabase(NativeDatabase(live));
    addTearDown(db.close);
    await V2UseCases(db).bootstrap(createDefaultOwner: false);

    expect(_version(live), kAppDatabaseSchemaVersion);
    expect(_hasColumn(live, 'products', 'image_path'), isTrue);
    expect(_hasTable(live, 'inventory_adjustments'), isTrue);
    expect(_hasTable(live, 'opening_balances'), isTrue);
    expect(_hasTable(live, 'purchase_returns'), isTrue);
    expect(_hasTable(live, 'purchase_return_items'), isTrue);
    expect(_version(snapshot), 4);
    expect(_setting(snapshot, 'migration.evidence'), 'before-upgrade');
    expect(await recovery.marker.exists(), isFalse);
  });

  test(
    'a database written by a newer app is rejected before migration',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'migration-newer-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final live = File('${directory.path}/shop.db');
      await _createCurrentDatabase(live);
      final raw = sqlite.sqlite3.open(live.path);
      raw.execute('PRAGMA user_version = ${kAppDatabaseSchemaVersion + 1};');
      raw.close();
      final recovery = MigrationRecovery(
        live,
        targetVersion: kAppDatabaseSchemaVersion,
      );

      await expectLater(
        recovery.prepareForOpen(),
        throwsA(isA<DatabaseVersionTooNew>()),
      );

      expect(_version(live), kAppDatabaseSchemaVersion + 1);
      expect(await recovery.marker.exists(), isFalse);
      expect(await recovery.pendingSnapshot(), isNull);
    },
  );

  test(
    'a failed migration restores its pre-upgrade database and stays blocked',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'migration-fail-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final live = File('${directory.path}/shop.db');
      final raw = sqlite.sqlite3.open(live.path);
      raw
        ..execute('CREATE TABLE evidence(value TEXT NOT NULL);')
        ..execute("INSERT INTO evidence VALUES ('before-upgrade');")
        ..execute('PRAGMA user_version = 4;');
      raw.close();
      final recovery = MigrationRecovery(
        live,
        targetVersion: kAppDatabaseSchemaVersion,
      );
      await recovery.prepareForOpen();

      final db = AppDatabase(NativeDatabase(live));
      await expectLater(
        db.select(db.users).get(),
        throwsA(isA<DatabaseMigrationFailedDuringUpgrade>()),
      );
      await db.close();

      await expectLater(
        recovery.prepareForOpen(),
        throwsA(isA<DatabaseMigrationFailed>()),
      );
      expect(_version(live), 4);
      expect(_evidence(live), 'before-upgrade');
      expect(await recovery.marker.exists(), isTrue);
      expect(await recovery.pendingSnapshot(), isNotNull);
    },
  );
}

Future<void> _createCurrentDatabase(File file) async {
  final db = AppDatabase(NativeDatabase(file));
  try {
    await db.select(db.appSettings).get();
  } finally {
    await db.close();
  }
}

Future<void> _createV4Database(File file) async {
  await _createCurrentDatabase(file);
  final raw = sqlite.sqlite3.open(file.path);
  try {
    raw
      ..execute('ALTER TABLE products DROP COLUMN image_path;')
      ..execute(
        "INSERT OR REPLACE INTO app_settings(key, value) VALUES ('migration.evidence', 'before-upgrade');",
      )
      ..execute('PRAGMA user_version = 4;');
  } finally {
    raw.close();
  }
}

int _version(File file) {
  final raw = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
  try {
    return raw.select('PRAGMA user_version;').single.values.single as int;
  } finally {
    raw.close();
  }
}

String? _setting(File file, String key) {
  final raw = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
  try {
    final rows = raw.select('SELECT value FROM app_settings WHERE key = ?', [
      key,
    ]);
    return rows.isEmpty ? null : rows.single['value'] as String;
  } finally {
    raw.close();
  }
}

String _evidence(File file) {
  final raw = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
  try {
    return raw.select('SELECT value FROM evidence;').single['value'] as String;
  } finally {
    raw.close();
  }
}

bool _hasColumn(File file, String table, String column) {
  final raw = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
  try {
    return raw
        .select('PRAGMA table_info("$table");')
        .any((row) => row['name'] == column);
  } finally {
    raw.close();
  }
}

bool _hasTable(File file, String table) {
  final raw = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
  try {
    return raw.select(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?;",
      [table],
    ).isNotEmpty;
  } finally {
    raw.close();
  }
}
