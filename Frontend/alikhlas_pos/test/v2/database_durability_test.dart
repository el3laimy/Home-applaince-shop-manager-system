import 'dart:io';

import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file-backed database uses FULL synchronous durability', () async {
    final directory = await Directory.systemTemp.createTemp('alikhlas-v2-full-');
    final db = AppDatabase(NativeDatabase(File('${directory.path}/shop.db')));
    addTearDown(() async {
      await db.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final result = await db.customSelect('PRAGMA synchronous;').getSingle();

    expect(result.data.values.single, 2);
  });
}
