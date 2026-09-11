import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a new shop creates its owner without a known default password',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final useCases = V2UseCases(db);
      await useCases.bootstrap(createDefaultOwner: false);

      expect(await useCases.hasOwner(), isFalse);
      expect(
        await useCases.login('owner', 'owner123'),
        isA<AppFailure<User>>(),
      );
      expect(
        await useCases.setupInitialOwner(
          fullName: 'صاحب المحل',
          password: 'secure-owner-password',
          shopName: ' ',
        ),
        isA<AppFailure<InitialOwnerSetup>>(),
      );
      expect(await useCases.hasOwner(), isFalse);

      final setup = await useCases.setupInitialOwner(
        fullName: 'صاحب المحل',
        password: 'secure-owner-password',
        shopName: 'إخلاص التجريبي',
      );
      expect(setup, isA<AppSuccess<InitialOwnerSetup>>());
      expect(
        (setup as AppSuccess<InitialOwnerSetup>).value.owner.mustChangePassword,
        isFalse,
      );
      expect((await useCases.shopSettings()).shopName, 'إخلاص التجريبي');
      expect(
        await useCases.login('owner', 'secure-owner-password'),
        isA<AppSuccess<User>>(),
      );
      expect(
        await useCases.setupInitialOwner(
          fullName: 'مالك آخر',
          password: 'another-secure-password',
          shopName: 'محل آخر',
        ),
        isA<AppFailure<InitialOwnerSetup>>(),
      );
    },
  );
}
