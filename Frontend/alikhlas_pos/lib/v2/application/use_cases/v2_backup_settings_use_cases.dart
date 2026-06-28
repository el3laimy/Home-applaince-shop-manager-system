part of '../v2_use_cases.dart';

extension V2BackupSettingsUseCases on V2UseCases {
  Future<File> backupToDirectory(Directory directory) async {
    await directory.create(recursive: true);
    final keep = await _backupRetentionCopies();
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final target = File(p.join(directory.path, 'alikhlas-v2-$timestamp.db'));
    final escaped = target.path.replaceAll("'", "''");
    await db.customStatement("VACUUM INTO '$escaped';");
    await _pruneBackups(directory, keep: keep);
    return target;
  }

  Future<void> setBackupDirectory(String path) async {
    await _upsertSetting('backup.directory', path);
  }

  Future<File?> runAutomaticBackupIfDue() async {
    final path = await _settingValue('backup.directory');
    if (path == null || path.trim().isEmpty) return null;

    final today = _dateKey(DateTime.now());
    final lastBackup = await _settingValue('backup.lastDate');
    if (lastBackup == today) return null;

    final backup = await backupToDirectory(Directory(path));
    await _upsertSetting('backup.lastDate', today);
    return backup;
  }

  Future<void> restoreFromBackup(File backupFile) async {
    if (!await backupFile.exists()) {
      throw ArgumentError('Backup file does not exist: ${backupFile.path}');
    }
    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
    final currentDir = await db
        .customSelect('PRAGMA database_list;')
        .getSingle();
    final dbPath = currentDir.data['file'] as String?;
    if (dbPath == null || dbPath.isEmpty) {
      throw StateError('Cannot resolve current SQLite file path.');
    }
    final dbFile = File(dbPath);
    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');
    final rollbackFile = File(
      '$dbPath.restore-${DateTime.now().microsecondsSinceEpoch}.bak',
    );
    if (await dbFile.exists()) {
      await _restoreFiles.copyFile(dbFile, rollbackFile);
    }
    await db.close();
    var restored = false;
    try {
      await _restoreFiles.deleteFileIfExists(walFile);
      await _restoreFiles.deleteFileIfExists(shmFile);
      await _restoreFiles.copyFile(backupFile, dbFile);
      restored = true;
    } catch (_) {
      if (await rollbackFile.exists()) {
        await _restoreFiles.deleteFileIfExists(walFile);
        await _restoreFiles.deleteFileIfExists(shmFile);
        await _restoreFiles.copyFile(rollbackFile, dbFile);
        await _restoreFiles.deleteFileIfExists(rollbackFile);
      }
      rethrow;
    } finally {
      if (restored) {
        try {
          await _restoreFiles.deleteFileIfExists(rollbackFile);
        } on FileSystemException {
          // A leftover rollback copy is safer than failing a completed restore.
        }
      }
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

  Future<void> _pruneBackups(Directory directory, {required int keep}) async {
    final backups = await _backupFiles(directory);
    for (final backup in backups.skip(keep)) {
      await backup.delete();
    }
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

    final directory = Directory(directoryPath);
    final backups = await _backupFiles(directory);
    return BackupStatus(
      directory: directoryPath,
      lastDate: await _settingValue('backup.lastDate'),
      latestBackupPath: backups.isEmpty ? null : backups.first.path,
      backupCount: backups.length,
      retentionCopies: retentionCopies,
    );
  }

  Future<List<File>> _backupFiles(Directory directory) async {
    if (!await directory.exists()) return [];
    final backups = await directory
        .list()
        .where(
          (entity) =>
              entity is File &&
              p.basename(entity.path).startsWith('alikhlas-v2-'),
        )
        .cast<File>()
        .toList();
    backups.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return backups;
  }

  Future<int> _backupRetentionCopies() async {
    final configuredCopies = int.tryParse(
      await _settingValue('backup.keepCopies') ?? '',
    );
    return configuredCopies == null || configuredCopies < 1
        ? 30
        : configuredCopies;
  }
}
