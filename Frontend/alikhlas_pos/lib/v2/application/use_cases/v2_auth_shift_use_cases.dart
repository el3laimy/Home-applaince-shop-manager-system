part of '../v2_use_cases.dart';

extension V2AuthShiftUseCases on V2UseCases {
  static const _recoveryHashKey = 'security.recovery.owner.hash';
  static const _recoveryAttemptKey = 'security.recovery.owner.failedAttempts';
  static const _recoveryLockedUntilKey = 'security.recovery.owner.lockedUntil';
  static const _recoveryCreatedAtKey = 'security.recovery.owner.createdAt';
  static const _recoveryUsedAtKey = 'security.recovery.owner.usedAt';
  static const _loginAttemptKey = 'security.login.failedAttempts';
  static const _loginLockedUntilKey = 'security.login.lockedUntil';
  static const _recoveryMaxAttempts = 5;
  static const _recoveryLockDuration = Duration(minutes: 15);

  String newShiftOperationKey() => newFinancialOperationKey();

  Future<void> bootstrap({bool createDefaultOwner = false}) async {
    await db.finalizeMigrationIfReady();
    await _write(() async {
      final hasOwner = await db.select(db.users).getSingleOrNull();
      if (hasOwner == null && createDefaultOwner) {
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
      await tryAutomaticBackup();
    });
  }

  Future<bool> hasOwner() async =>
      await db.select(db.users).getSingleOrNull() != null;

  Future<AppResult<User>> createInitialOwner({
    required String fullName,
    required String password,
  }) => _createInitialOwner(fullName: fullName, password: password);

  Future<AppResult<InitialOwnerSetup>> setupInitialOwner({
    required String fullName,
    required String password,
    required String shopName,
  }) async {
    if (shopName.trim().isEmpty) return const AppFailure('اسم المحل مطلوب');
    final recoveryCode = _newRecoveryCode();
    final result = await _createInitialOwner(
      fullName: fullName,
      password: password,
      recoveryCode: recoveryCode,
      shopName: shopName,
    );
    return switch (result) {
      AppSuccess<User>(value: final owner) => AppSuccess(
        InitialOwnerSetup(owner: owner, recoveryCode: recoveryCode),
      ),
      AppFailure<User>(message: final message) => AppFailure(message),
    };
  }

  Future<AppResult<User>> _createInitialOwner({
    required String fullName,
    required String password,
    String? recoveryCode,
    String? shopName,
  }) async {
    if (fullName.trim().isEmpty) return const AppFailure('اسم المالك مطلوب');
    if (password.length < 6) {
      return const AppFailure('كلمة المرور يجب ألا تقل عن 6 أحرف');
    }
    return _writeTransaction(() async {
      if (await db.select(db.users).getSingleOrNull() != null) {
        return const AppFailure('تم إعداد مالك المحل بالفعل.');
      }
      final id = await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              username: 'owner',
              passwordHash: _hashPassword(password),
              fullName: fullName.trim(),
              mustChangePassword: const Value(false),
            ),
          );
      if (recoveryCode != null) {
        await _saveRecoveryCode(recoveryCode);
      }
      if (shopName != null) {
        await _upsertSetting('shop.name', shopName.trim());
      }
      return AppSuccess(
        await (db.select(
          db.users,
        )..where((user) => user.id.equals(id))).getSingle(),
      );
    });
  }

  Future<AppResult<OwnerRecovery>> recoverOwnerAccess({
    required String recoveryCode,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      return const AppFailure('كلمة المرور يجب ألا تقل عن 6 أحرف');
    }
    final normalizedCode = _normalizeRecoveryCode(recoveryCode);
    if (normalizedCode.isEmpty) {
      return const AppFailure('أدخل رمز الاستعادة.');
    }

    return _writeTransaction(() async {
      final storedHash = await _settingValue(_recoveryHashKey);
      if (storedHash == null || storedHash.isEmpty) {
        return const AppFailure(
          'لا يوجد رمز استعادة مهيأ لهذا المحل. اتبع إجراء الدعم المعتمد.',
        );
      }

      final lockedUntil = DateTime.tryParse(
        await _settingValue(_recoveryLockedUntilKey) ?? '',
      );
      if (lockedUntil != null && lockedUntil.isAfter(clock())) {
        return AppFailure(
          'تم إيقاف محاولات الاستعادة مؤقتًا حتى ${lockedUntil.toLocal()}.',
        );
      }
      if (lockedUntil != null) {
        await _clearRecoveryAttempts();
      }

      if (!_verifyPassword('recovery::$normalizedCode', storedHash).isValid) {
        final attempts =
            (int.tryParse(await _settingValue(_recoveryAttemptKey) ?? '') ??
                0) +
            1;
        if (attempts >= _recoveryMaxAttempts) {
          final retryAt = clock().add(_recoveryLockDuration);
          await _upsertSetting(_recoveryAttemptKey, '0');
          await _upsertSetting(
            _recoveryLockedUntilKey,
            retryAt.toIso8601String(),
          );
          return AppFailure(
            'تم إيقاف محاولات الاستعادة لمدة 15 دقيقة حتى ${retryAt.toLocal()}.',
          );
        }
        await _upsertSetting(_recoveryAttemptKey, attempts.toString());
        return const AppFailure('رمز الاستعادة غير صحيح.');
      }

      final owner = await db.select(db.users).getSingleOrNull();
      if (owner == null) {
        return const AppFailure('لا يوجد حساب مالك لاستعادة الوصول إليه.');
      }

      final nextCode = _newRecoveryCode();
      await (db.update(
        db.users,
      )..where((user) => user.id.equals(owner.id))).write(
        UsersCompanion(
          passwordHash: Value(_hashPassword(newPassword)),
          mustChangePassword: const Value(false),
        ),
      );
      await _saveRecoveryCode(nextCode);
      await _upsertSetting(_recoveryUsedAtKey, clock().toIso8601String());
      await _clearRecoveryAttempts();
      final updated = await (db.select(
        db.users,
      )..where((user) => user.id.equals(owner.id))).getSingle();
      return AppSuccess(OwnerRecovery(owner: updated, recoveryCode: nextCode));
    });
  }

  String _newRecoveryCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = math.Random.secure();
    final characters = List.generate(
      25,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return List.generate(
      5,
      (group) => characters.substring(group * 5, (group + 1) * 5),
    ).join('-');
  }

  String _normalizeRecoveryCode(String code) =>
      code.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

  Future<void> _saveRecoveryCode(String code) async {
    await _upsertSetting(
      _recoveryHashKey,
      _hashPassword('recovery::${_normalizeRecoveryCode(code)}'),
    );
    await _upsertSetting(_recoveryCreatedAtKey, clock().toIso8601String());
  }

  Future<void> _clearRecoveryAttempts() async {
    for (final key in [_recoveryAttemptKey, _recoveryLockedUntilKey]) {
      await (db.delete(
        db.appSettings,
      )..where((setting) => setting.key.equals(key))).go();
    }
  }

  Future<AppResult<User>> login(String username, String password) async {
    return _writeTransaction(() async {
      final lockedUntil = DateTime.tryParse(
        await _settingValue(_loginLockedUntilKey) ?? '',
      );
      if (lockedUntil != null && lockedUntil.isAfter(clock())) {
        return AppFailure(
          'تم إيقاف محاولات الدخول مؤقتًا حتى ${lockedUntil.toLocal()}.',
        );
      }
      if (lockedUntil != null) await _clearLoginAttempts();

      final user = await (db.select(
        db.users,
      )..where((u) => u.username.equals(username.trim()))).getSingleOrNull();
      final verification = user == null
          ? (isValid: false, needsRehash: false)
          : _verifyPassword(password, user.passwordHash);
      if (!verification.isValid) {
        await _recordLoginFailure();
        return const AppFailure('اسم المستخدم أو كلمة المرور غير صحيحة');
      }

      final authenticatedUser = user!;
      await _clearLoginAttempts();
      if (!verification.needsRehash) return AppSuccess(authenticatedUser);
      await (db.update(db.users)
            ..where((u) => u.id.equals(authenticatedUser.id)))
          .write(UsersCompanion(passwordHash: Value(_hashPassword(password))));
      return AppSuccess(
        await (db.select(
          db.users,
        )..where((u) => u.id.equals(authenticatedUser.id))).getSingle(),
      );
    });
  }

  Future<void> _recordLoginFailure() async {
    final attempts =
        (int.tryParse(await _settingValue(_loginAttemptKey) ?? '') ?? 0) + 1;
    if (attempts < _recoveryMaxAttempts) {
      await _upsertSetting(_loginAttemptKey, attempts.toString());
      return;
    }
    final retryAt = clock().add(_recoveryLockDuration);
    await _upsertSetting(_loginAttemptKey, '0');
    await _upsertSetting(_loginLockedUntilKey, retryAt.toIso8601String());
  }

  Future<void> _clearLoginAttempts() async {
    for (final key in [_loginAttemptKey, _loginLockedUntilKey]) {
      await (db.delete(
        db.appSettings,
      )..where((setting) => setting.key.equals(key))).go();
    }
  }

  Future<AppResult<User>> changePassword(int userId, String newPassword) async {
    if (newPassword.length < 6) {
      return const AppFailure('كلمة المرور يجب ألا تقل عن 6 أحرف');
    }
    return _writeTransaction(() async {
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
    });
  }

  /// Used only by the legacy mandatory-password-change path so an existing
  /// shop receives a recovery code without requiring a fresh database setup.
  Future<AppResult<OwnerRecovery>> changePasswordAndIssueRecoveryCode(
    int userId,
    String newPassword,
  ) async {
    if (newPassword.length < 6) {
      return const AppFailure('كلمة المرور يجب ألا تقل عن 6 أحرف');
    }
    return _writeTransaction(() async {
      final owner = await (db.select(
        db.users,
      )..where((user) => user.id.equals(userId))).getSingleOrNull();
      if (owner == null) {
        return const AppFailure('تعذر العثور على حساب المالك.');
      }

      final recoveryCode = _newRecoveryCode();
      await (db.update(
        db.users,
      )..where((user) => user.id.equals(owner.id))).write(
        UsersCompanion(
          passwordHash: Value(_hashPassword(newPassword)),
          mustChangePassword: const Value(false),
        ),
      );
      await _saveRecoveryCode(recoveryCode);
      await _clearRecoveryAttempts();
      final updated = await (db.select(
        db.users,
      )..where((user) => user.id.equals(owner.id))).getSingle();
      return AppSuccess(
        OwnerRecovery(owner: updated, recoveryCode: recoveryCode),
      );
    });
  }

  Future<AppResult<Shift>> openShift(
    int openingCashMinor, {
    String? operationKey,
  }) async {
    if (operationKey == null) {
      return const AppFailure<Shift>(
        'معرّف فتح الوردية مطلوب لمنع تسجيل الحركة مرتين.',
      );
    }
    return _runIdempotentShiftOperation(
      namespace: 'shift.open',
      operationKey: operationKey,
      fingerprintPayload: ['open', openingCashMinor],
      conflictMessage: 'فتح الوردية محفوظ ببيانات مختلفة. راجع اليومية.',
      execute: () => _openShift(openingCashMinor),
    );
  }

  Future<AppResult<Shift>> _openShift(int openingCashMinor) async {
    if (openingCashMinor < 0) {
      return const AppFailure('رصيد فتح الوردية لا يمكن أن يكون سالبًا.');
    }
    final open = await currentShift();
    if (open != null) {
      return const AppFailure('توجد وردية مفتوحة بالفعل');
    }

    return _writeTransaction(() async {
      final id = await db
          .into(db.shifts)
          .insert(
            ShiftsCompanion.insert(
              openedAt: clock(),
              openingCashMinor: openingCashMinor,
            ),
          );
      return AppSuccess(
        await (db.select(db.shifts)..where((s) => s.id.equals(id))).getSingle(),
      );
    });
  }

  Future<Shift?> currentShift() {
    return (db.select(
      db.shifts,
    )..where((s) => s.status.equals('open'))).getSingleOrNull();
  }

  Future<AppResult<Shift>> closeShift(
    int actualCashMinor, {
    String? operationKey,
  }) async {
    if (operationKey == null) {
      return const AppFailure<Shift>(
        'معرّف إغلاق الوردية مطلوب لمنع تسجيل الحركة مرتين.',
      );
    }
    return _runIdempotentShiftOperation(
      namespace: 'shift.close',
      operationKey: operationKey,
      // The operation key is single-use, so this remains replayable after
      // the shift has closed and is no longer the current one.
      fingerprintPayload: ['close', actualCashMinor],
      conflictMessage: 'إغلاق الوردية محفوظ ببيانات مختلفة. راجع اليومية.',
      execute: () => _closeShift(actualCashMinor),
    );
  }

  Future<AppResult<Shift>> _closeShift(int actualCashMinor) async {
    if (actualCashMinor < 0) {
      return const AppFailure(
        'النقد الفعلي عند الإغلاق لا يمكن أن يكون سالبًا.',
      );
    }
    final shift = await currentShift();
    if (shift == null) {
      return const AppFailure('لا توجد وردية مفتوحة');
    }

    final cashDelta = await _accountNetSince(AccountCodes.cash, shift.openedAt);
    final expected = shift.openingCashMinor + cashDelta;
    final difference = actualCashMinor - expected;
    final closedAt = clock();

    return _writeTransaction(() async {
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
    });
  }
}
