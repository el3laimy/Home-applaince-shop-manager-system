part of '../v2_use_cases.dart';

extension V2AuthShiftUseCases on V2UseCases {
  Future<void> bootstrap() async {
    final hasOwner = await db.select(db.users).getSingleOrNull();
    if (hasOwner == null) {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              username: 'owner',
              passwordHash: _hashPassword('owner123'),
              fullName: 'مالك المحل',
              mustChangePassword: const Value(true),
            ),
          );
    }

    await _upsertSetting('backup.keepCopies', '30');
    await _upsertSetting('app.currency', 'EGP');
    await _upsertSettingIfMissing('shop.name', 'إخلاص للأجهزة المنزلية');
    await _upsertSettingIfMissing('shop.receiptFooter', 'شكرا لتعاملكم معنا');
    await runAutomaticBackupIfDue();
  }

  Future<AppResult<User>> login(String username, String password) async {
    final user = await (db.select(
      db.users,
    )..where((u) => u.username.equals(username.trim()))).getSingleOrNull();
    if (user == null) {
      return const AppFailure('اسم المستخدم أو كلمة المرور غير صحيحة');
    }
    final verification = _verifyPassword(password, user.passwordHash);
    if (!verification.isValid) {
      return const AppFailure('اسم المستخدم أو كلمة المرور غير صحيحة');
    }
    if (!verification.needsRehash) return AppSuccess(user);

    final upgradedHash = _hashPassword(password);
    await (db.update(db.users)..where((u) => u.id.equals(user.id))).write(
      UsersCompanion(passwordHash: Value(upgradedHash)),
    );
    return AppSuccess(
      await (db.select(
        db.users,
      )..where((u) => u.id.equals(user.id))).getSingle(),
    );
  }

  Future<AppResult<User>> changePassword(int userId, String newPassword) async {
    if (newPassword.length < 6) {
      return const AppFailure('كلمة المرور يجب ألا تقل عن 6 أحرف');
    }
    await (db.update(db.users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(
        passwordHash: Value(_hashPassword(newPassword)),
        mustChangePassword: const Value(false),
      ),
    );
    final updated = await (db.select(
      db.users,
    )..where((u) => u.id.equals(userId))).getSingle();
    return AppSuccess(updated);
  }

  Future<AppResult<Shift>> openShift(int openingCashMinor) async {
    final open = await currentShift();
    if (open != null) {
      return const AppFailure('توجد وردية مفتوحة بالفعل');
    }

    final id = await db
        .into(db.shifts)
        .insert(
          ShiftsCompanion.insert(
            openedAt: DateTime.now(),
            openingCashMinor: openingCashMinor,
          ),
        );
    return AppSuccess(
      await (db.select(db.shifts)..where((s) => s.id.equals(id))).getSingle(),
    );
  }

  Future<Shift?> currentShift() {
    return (db.select(
      db.shifts,
    )..where((s) => s.status.equals('open'))).getSingleOrNull();
  }

  Future<AppResult<Shift>> closeShift(int actualCashMinor) async {
    final shift = await currentShift();
    if (shift == null) {
      return const AppFailure('لا توجد وردية مفتوحة');
    }

    final cashDelta = await _accountNetSince(AccountCodes.cash, shift.openedAt);
    final expected = shift.openingCashMinor + cashDelta;
    final difference = actualCashMinor - expected;
    final closedAt = DateTime.now();

    await (db.update(db.shifts)..where((s) => s.id.equals(shift.id))).write(
      ShiftsCompanion(
        closedAt: Value(closedAt),
        expectedCashMinor: Value(expected),
        actualCashMinor: Value(actualCashMinor),
        differenceMinor: Value(difference),
        status: const Value('closed'),
      ),
    );

    return AppSuccess(
      await (db.select(
        db.shifts,
      )..where((s) => s.id.equals(shift.id))).getSingle(),
    );
  }
}
