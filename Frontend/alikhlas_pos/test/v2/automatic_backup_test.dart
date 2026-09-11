import 'dart:io';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'missing destination is reported before next backup is due and clears on return',
    () async {
      final dir = await Directory.systemTemp.createTemp('backup-disconnect-');
      addTearDown(() => dir.delete(recursive: true));
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime(2026, 9, 11, 12);
      final uc = V2UseCases(db, clock: () => now);
      final destination = Directory('${dir.path}/usb/backups');
      await uc.setBackupDirectory(destination.path);
      expect(await uc.tryAutomaticBackup(), isNotNull);
      final successAt = (await db.select(db.appSettings).get())
          .singleWhere((s) => s.key == 'backup.lastSuccessAt')
          .value;
      final disconnected = await destination.rename('${dir.path}/unplugged');

      final reopenedStatus = (await V2UseCases(
        db,
        clock: () => now,
      ).workbenchSnapshot()).backupStatus;
      expect(reopenedStatus.warning, contains('مجلد النسخ غير متاح'));

      expect(await uc.tryAutomaticBackup(), isNull);
      expect(uc.backupWarning, contains('مجلد النسخ غير متاح'));
      final offline = (await uc.workbenchSnapshot()).backupStatus;
      expect(offline.warning, contains('مجلد النسخ غير متاح'));
      expect(offline.backupCount, 0);
      expect(await destination.exists(), isFalse);
      expect(
        (await db.select(db.appSettings).get())
            .singleWhere((s) => s.key == 'backup.lastSuccessAt')
            .value,
        successAt,
      );

      await disconnected.rename(destination.path);
      expect(await uc.tryAutomaticBackup(), isNull);
      expect(uc.backupWarning, isNull);
      final online = (await uc.workbenchSnapshot()).backupStatus;
      expect(online.warning, isNull);
      expect(online.backupCount, 1);
    },
  );

  test(
    'automatic backup runs again after thirty minutes and survives restart',
    () async {
      final dir = await Directory.systemTemp.createTemp('backup-interval-');
      addTearDown(() => dir.delete(recursive: true));
      final db = AppDatabase(NativeDatabase(File('${dir.path}/live.db')));
      addTearDown(db.close);
      var now = DateTime(2026, 9, 9, 9);
      var uc = V2UseCases(db, clock: () => now);
      await uc.setBackupDirectory('${dir.path}/backups');
      expect(await uc.runAutomaticBackupIfDue(), isNotNull);
      now = now.add(const Duration(minutes: 29));
      expect(await uc.runAutomaticBackupIfDue(), isNull);
      uc = V2UseCases(db, clock: () => now);
      expect(await uc.runAutomaticBackupIfDue(), isNull);
      now = now.add(const Duration(minutes: 1));
      expect(await uc.runAutomaticBackupIfDue(), isNotNull);
      expect(await Directory('${dir.path}/backups').list().length, 2);
    },
  );

  test(
    'failed backup retries after destination returns without advancing success',
    () async {
      final dir = await Directory.systemTemp.createTemp('backup-retry-');
      addTearDown(() => dir.delete(recursive: true));
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final uc = V2UseCases(db);
      final obstruction = File('${dir.path}/device');
      await obstruction.writeAsString('unavailable');
      await uc.setBackupDirectory('${obstruction.path}/backups');
      await uc.tryAutomaticBackup();
      expect(uc.backupWarning, isNotNull);
      expect(
        (await db.select(db.appSettings).get()).where(
          (s) => s.key == 'backup.lastSuccessAt',
        ),
        isEmpty,
      );
      await obstruction.delete();
      expect(await uc.tryAutomaticBackup(), isNotNull);
      expect(uc.backupWarning, isNull);
    },
  );

  test('concurrent automatic checks produce a single copy', () async {
    final dir = await Directory.systemTemp.createTemp('backup-concurrent-');
    addTearDown(() => dir.delete(recursive: true));
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final uc = V2UseCases(db);
    await uc.setBackupDirectory(dir.path);
    final results = await Future.wait(
      List.generate(5, (_) => uc.runAutomaticBackupIfDue()),
    );
    expect(results.whereType<File>(), hasLength(1));
    expect(await dir.list().length, 1);
  });
}
