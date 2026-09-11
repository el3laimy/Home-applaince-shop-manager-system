import 'dart:io';
import 'package:alikhlas_pos/v2/app/v2_providers.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class CountingBackups extends V2UseCases {
  CountingBackups(super.db);
  int checks = 0;
  Future<File?> tryAutomaticBackup() async {
    checks++;
    return null;
  }
}

void main() {
  testWidgets(
    'scheduler checks every minute and stops when scope is disposed',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final uc = CountingBackups(db);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            useCasesProvider.overrideWithValue(uc),
            automaticBackupCheckProvider.overrideWithValue(
              uc.tryAutomaticBackup,
            ),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              ref.watch(bootstrapProvider);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      expect(uc.checks, 0);
      await tester.pump(const Duration(minutes: 1));
      expect(uc.checks, 1);
      await tester.pump(const Duration(minutes: 1));
      expect(uc.checks, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 2));
      expect(uc.checks, 2);
    },
  );
}
