import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

/// Invoked only before opening the live database, or after closing it.
/// Fixed sibling paths avoid trusting paths supplied by a marker file.
class RestoreRecovery {
  RestoreRecovery(this.live);
  final File live;
  File get rollback => File('${live.path}.restore-rollback.db');
  File get marker => File('${live.path}.restore-pending');

  Future<void> markPending() async {
    if (await marker.exists()) {
      throw StateError('يوجد استرجاع غير مكتمل. أعد تشغيل التطبيق أولًا.');
    }
    _checkDatabase(rollback);
    final digest = await sha256.bind(rollback.openRead()).first;
    final temporary = File('${marker.path}.tmp');
    await temporary.writeAsString(digest.toString(), flush: true);
    await temporary.rename(marker.path);
  }

  Future<void> commit() async {
    _checkDatabase(live);
    final handle = await live.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
    await marker.delete();
  }

  Future<void> recoverIfPending() async {
    if (!await marker.exists()) return;
    if (!await rollback.exists()) {
      throw const FormatException(
        'تعذر العثور على نسخة الرجوع. لم يتم فتح بيانات غير مكتملة.',
      );
    }
    final expected = await marker.readAsString();
    final actual = await sha256.bind(rollback.openRead()).first;
    if (expected != actual.toString()) {
      throw const FormatException(
        'نسخة الرجوع تغيرت أو تلفت. احتفظ بالملفات وتواصل مع الدعم.',
      );
    }
    _checkDatabase(rollback);
    final staging = File('${live.path}.restore-recovering');
    await rollback.copy(staging.path);
    final handle = await staging.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
    _checkDatabase(staging);
    // If interrupted anywhere below, the marker and rollback remain intact,
    // and this operation can be repeated before opening another connection.
    for (final file in [
      File('${live.path}-wal'),
      File('${live.path}-shm'),
      live,
    ]) {
      if (await file.exists()) await file.delete();
    }
    await staging.rename(live.path);
    await commit();
  }

  void _checkDatabase(File file) {
    Database? database;
    try {
      database = sqlite3.open(file.path, mode: OpenMode.readOnly);
      final rows = database.select('PRAGMA quick_check;');
      if (rows.length != 1 || rows.single.values.single != 'ok') {
        throw const FormatException('ملف قاعدة البيانات غير سليم.');
      }
    } on SqliteException {
      throw const FormatException('ملف قاعدة البيانات غير قابل للقراءة.');
    } finally {
      database?.close();
    }
  }
}
