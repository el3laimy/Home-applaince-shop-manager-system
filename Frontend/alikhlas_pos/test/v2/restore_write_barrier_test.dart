import 'dart:async';
import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'restore waits for an admitted write and rejects a later mutation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'alikhlas-restore-write-barrier-',
      );
      addTearDown(() => directory.delete(recursive: true));

      final db = AppDatabase(NativeDatabase(File('${directory.path}/live.db')));
      addTearDown(db.close);
      final barrier = V2WriteBarrier();
      final useCases = V2UseCases(db, writeBarrier: barrier);
      await useCases.bootstrap();
      final backup = await useCases.backupToDirectory(
        Directory('${directory.path}/backups'),
      );

      final enteredWrite = Completer<void>();
      final releaseWrite = Completer<void>();
      final admittedWrite = barrier.write(() async {
        enteredWrite.complete();
        await releaseWrite.future;
      });
      await enteredWrite.future;

      final restore = useCases.restoreFromBackup(backup);
      await Future<void>.delayed(Duration.zero);

      expect(useCases.databaseClosedForRestore, isFalse);
      await expectLater(
        useCases.createCustomer(name: 'لا تقبل أثناء الاسترجاع'),
        throwsA(isA<StateError>()),
      );

      releaseWrite.complete();
      await admittedWrite;
      await restore;
      expect(useCases.databaseClosedForRestore, isTrue);
    },
  );
}
