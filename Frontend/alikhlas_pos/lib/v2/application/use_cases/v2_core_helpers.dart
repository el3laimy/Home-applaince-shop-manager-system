part of '../v2_use_cases.dart';

extension V2CoreUseCaseHelpers on V2UseCases {
  String? _blankToNull(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  String _dateKey(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  Future<String> _nextNumber(String key, {required String prefix}) async {
    final current = await (db.select(
      db.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    final next = int.parse(current?.value ?? '0') + 1;
    await _upsertSetting(key, next.toString());
    return '$prefix-${clock().year}-${next.toString().padLeft(5, '0')}';
  }

  Future<String> _nextProductBarcode() {
    return _nextNumber('sequence.productBarcode', prefix: 'AK');
  }

  Future<void> _insertPayments(
    String ownerType,
    int ownerId,
    List<PaymentInput> payments,
  ) async {
    for (final payment in payments.where((p) => p.amountMinor > 0)) {
      await db
          .into(db.payments)
          .insert(
            PaymentsCompanion.insert(
              ownerType: ownerType,
              ownerId: ownerId,
              method: payment.method.name,
              amountMinor: payment.amountMinor,
              note: Value(payment.note),
            ),
          );
    }
  }

  Future<AppConfirmationRequired<int>?> _negativeBalanceConfirmationFor(
    List<_LedgerLineDraft> lines,
  ) async {
    final deltas = <String, int>{};
    for (final line in lines) {
      if (line.accountCode != AccountCodes.cash &&
          line.accountCode != AccountCodes.wallet) {
        continue;
      }
      final delta = line.debitMinor - line.creditMinor;
      if (delta == 0) continue;
      deltas.update(
        line.accountCode,
        (current) => current + delta,
        ifAbsent: () => delta,
      );
    }

    final impacts = <NegativeBalanceImpact>[];
    for (final entry in deltas.entries) {
      if (entry.value >= 0) continue;
      final current = await _accountBalance(entry.key);
      final next = current + entry.value;
      if (next >= 0) continue;
      impacts.add(
        NegativeBalanceImpact(
          accountCode: entry.key,
          label: _liquidAccountLabel(entry.key),
          currentMinor: current,
          deltaMinor: entry.value,
          newMinor: next,
        ),
      );
    }

    if (impacts.isEmpty) return null;
    return AppConfirmationRequired<int>(
      code: 'negative_liquid_balance',
      message: 'هذه العملية ستجعل رصيد الخزينة أو المحفظة سالبًا',
      payload: NegativeBalanceConfirmation(impacts: impacts),
    );
  }

  String _liquidAccountLabel(String accountCode) {
    return switch (accountCode) {
      AccountCodes.cash => 'الخزينة',
      AccountCodes.wallet => 'المحفظة',
      _ => accountCode,
    };
  }

  Future<int> _postLedger({
    required String referenceType,
    required int referenceId,
    required String description,
    required List<_LedgerLineDraft> lines,
  }) async {
    final debit = lines.fold<int>(0, (sum, line) => sum + line.debitMinor);
    final credit = lines.fold<int>(0, (sum, line) => sum + line.creditMinor);
    if (debit != credit || debit == 0) {
      throw StateError('Unbalanced ledger entry: debit=$debit credit=$credit');
    }

    final entryId = await db
        .into(db.ledgerEntries)
        .insert(
          LedgerEntriesCompanion.insert(
            referenceType: referenceType,
            referenceId: referenceId,
            description: description,
          ),
        );

    for (final line in lines) {
      if (line.debitMinor < 0 || line.creditMinor < 0) {
        throw StateError('Ledger lines cannot contain negative values.');
      }
      await db
          .into(db.ledgerLines)
          .insert(
            LedgerLinesCompanion.insert(
              entryId: entryId,
              accountCode: line.accountCode,
              debitMinor: Value(line.debitMinor),
              creditMinor: Value(line.creditMinor),
              partyType: Value(line.partyType),
              partyId: Value(line.partyId),
            ),
          );
    }
    return entryId;
  }

  Future<int> _accountBalance(String accountCode) async {
    return _accountNet(accountCode: accountCode);
  }

  Future<int> _accountNetSince(String accountCode, DateTime since) async {
    return _accountNet(accountCode: accountCode, start: since);
  }

  Future<int> _accountNetBetween(
    String accountCode,
    DateTime start,
    DateTime end, {
    String? referenceType,
  }) async {
    return _accountNet(
      accountCode: accountCode,
      start: start,
      end: end,
      referenceType: referenceType,
    );
  }

  Future<int> _accountNet({
    required String accountCode,
    DateTime? start,
    DateTime? end,
    String? referenceType,
  }) async {
    final usesLedgerEntry =
        start != null || end != null || referenceType != null;
    final where = <String>['l.account_code = ?'];
    final variables = <Variable>[Variable<String>(accountCode)];
    if (start != null) {
      where.add('e.created_at >= ?');
      variables.add(Variable<DateTime>(start));
    }
    if (end != null) {
      where.add('e.created_at < ?');
      variables.add(Variable<DateTime>(end));
    }
    if (referenceType != null) {
      where.add('e.reference_type = ?');
      variables.add(Variable<String>(referenceType));
    }

    final from = usesLedgerEntry
        ? 'ledger_lines l INNER JOIN ledger_entries e ON e.id = l.entry_id'
        : 'ledger_lines l';
    final row = await db
        .customSelect(
          '''
          SELECT COALESCE(SUM(l.debit_minor - l.credit_minor), 0) AS net
          FROM $from
          WHERE ${where.join(' AND ')}
          ''',
          variables: variables,
          readsFrom: usesLedgerEntry
              ? {db.ledgerLines, db.ledgerEntries}
              : {db.ledgerLines},
        )
        .getSingle();
    return row.data['net'] as int;
  }

  int _sumPayments(List<PaymentInput> payments, PaymentMethod method) {
    return payments
        .where((payment) => payment.method == method)
        .fold<int>(0, (sum, payment) => sum + payment.amountMinor);
  }
}
