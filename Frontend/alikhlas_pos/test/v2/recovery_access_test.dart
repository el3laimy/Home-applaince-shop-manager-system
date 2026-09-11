import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'recovery code is hashed, rotates after use, and changes the password',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      await useCases.bootstrap(createDefaultOwner: false);

      final setup = await _success(
        useCases.setupInitialOwner(
          fullName: 'صاحب المحل',
          password: 'first-owner-password',
          shopName: 'محل الاختبار',
        ),
      );
      expect(
        setup.recoveryCode,
        matches(RegExp(r'^[A-Z0-9]{5}(?:-[A-Z0-9]{5}){4}$')),
      );
      final stored =
          await (db.select(db.appSettings)..where(
                (setting) => setting.key.equals('security.recovery.owner.hash'),
              ))
              .getSingle();
      expect(stored.value, isNot(contains(setup.recoveryCode)));
      expect(stored.value, startsWith(r'pbkdf2_sha256$600000$'));

      expect(
        await useCases.recoverOwnerAccess(
          recoveryCode: 'wrong-code',
          newPassword: 'recovered-owner-password',
        ),
        isA<AppFailure<OwnerRecovery>>(),
      );

      final recovered = await _success(
        useCases.recoverOwnerAccess(
          recoveryCode: setup.recoveryCode.toLowerCase(),
          newPassword: 'recovered-owner-password',
        ),
      );
      expect(recovered.recoveryCode, isNot(setup.recoveryCode));
      expect(
        await useCases.login('owner', 'first-owner-password'),
        isA<AppFailure<User>>(),
      );
      expect(
        await useCases.login('owner', 'recovered-owner-password'),
        isA<AppSuccess<User>>(),
      );
      expect(
        await useCases.recoverOwnerAccess(
          recoveryCode: setup.recoveryCode,
          newPassword: 'another-owner-password',
        ),
        isA<AppFailure<OwnerRecovery>>(),
      );
    },
  );

  test(
    'five incorrect recovery codes pause further attempts before retry',
    () async {
      var now = DateTime(2026, 9, 11, 12);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db, clock: () => now);
      await useCases.bootstrap(createDefaultOwner: false);
      final setup = await _success(
        useCases.setupInitialOwner(
          fullName: 'صاحب المحل',
          password: 'first-owner-password',
          shopName: 'محل الاختبار',
        ),
      );

      for (var attempt = 0; attempt < 5; attempt += 1) {
        final result = await useCases.recoverOwnerAccess(
          recoveryCode: 'wrong-code',
          newPassword: 'recovered-owner-password',
        );
        expect(result, isA<AppFailure<OwnerRecovery>>());
      }
      expect(
        await useCases.recoverOwnerAccess(
          recoveryCode: setup.recoveryCode,
          newPassword: 'recovered-owner-password',
        ),
        isA<AppFailure<OwnerRecovery>>(),
      );

      now = now.add(const Duration(minutes: 16));
      expect(
        await useCases.recoverOwnerAccess(
          recoveryCode: setup.recoveryCode,
          newPassword: 'recovered-owner-password',
        ),
        isA<AppSuccess<OwnerRecovery>>(),
      );
    },
  );

  test(
    'legacy owner receives a recovery code while changing the default password',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      await useCases.bootstrap(createDefaultOwner: true);
      final owner = await _success(useCases.login('owner', 'owner123'));

      final changed = await _success(
        useCases.changePasswordAndIssueRecoveryCode(
          owner.id,
          'new-owner-password',
        ),
      );
      expect(changed.owner.mustChangePassword, isFalse);
      expect(changed.recoveryCode, isNotEmpty);
      expect(
        await useCases.login('owner', 'owner123'),
        isA<AppFailure<User>>(),
      );
      expect(
        await useCases.login('owner', 'new-owner-password'),
        isA<AppSuccess<User>>(),
      );
    },
  );
}

Future<T> _success<T>(Future<AppResult<T>> future) async {
  final result = await future;
  if (result case AppSuccess<T>(value: final value)) return value;
  throw StateError('Expected success, got $result');
}
