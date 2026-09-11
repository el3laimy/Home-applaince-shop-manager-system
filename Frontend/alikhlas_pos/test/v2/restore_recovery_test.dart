import 'dart:io';
import 'package:alikhlas_pos/v2/data/restore_recovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  for (final missing in [false, true]) {
    test(
      'pending restore recovers original database; missing=$missing',
      () async {
        final dir = await Directory.systemTemp.createTemp('restore-recovery-');
        addTearDown(() => dir.delete(recursive: true));
        final live = File('${dir.path}/live.db');
        final recovery = RestoreRecovery(live);
        final original = sqlite3.open(recovery.rollback.path);
        original.execute('CREATE TABLE evidence(value TEXT);');
        original.execute("INSERT INTO evidence VALUES ('original');");
        original.close();
        await recovery.markPending();
        if (!missing) await live.writeAsString('partial copy');
        await File('${live.path}-wal').writeAsString('stale wal');
        await recovery.recoverIfPending();
        final restored = sqlite3.open(live.path);
        expect(
          restored.select('SELECT value FROM evidence').single['value'],
          'original',
        );
        restored.close();
        expect(await recovery.marker.exists(), isFalse);
        expect(await recovery.rollback.exists(), isTrue);
        await recovery.recoverIfPending();
      },
    );
  }
  test(
    'changed rollback fails closed and keeps current and pending files',
    () async {
      final dir = await Directory.systemTemp.createTemp('restore-bad-');
      addTearDown(() => dir.delete(recursive: true));
      final live = File('${dir.path}/live.db');
      final recovery = RestoreRecovery(live);
      final original = sqlite3.open(recovery.rollback.path);
      original.execute('CREATE TABLE evidence(value TEXT);');
      original.close();
      await recovery.markPending();
      await recovery.rollback.writeAsString('damaged');
      await live.writeAsString('do not touch');
      await expectLater(
        recovery.recoverIfPending(),
        throwsA(isA<FormatException>()),
      );
      expect(await live.readAsString(), 'do not touch');
      expect(await recovery.marker.exists(), isTrue);
    },
  );
}
