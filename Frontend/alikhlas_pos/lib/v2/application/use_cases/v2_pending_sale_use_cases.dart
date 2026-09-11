part of '../v2_use_cases.dart';

/// Durable single-checkout request, retained until the UI acknowledges a result.
class PendingSale {
  PendingSale({
    required this.operationKey,
    this.customerId,
    required List<SaleLineInput> items,
    required List<PaymentInput> payments,
    this.installmentTerms,
    this.discountMinor = 0,
  }) : items = List.unmodifiable(items),
       payments = List.unmodifiable(payments) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(operationKey)) {
      throw const FormatException('Invalid pending sale key');
    }
  }
  final String operationKey;
  final int? customerId;
  final List<SaleLineInput> items;
  final List<PaymentInput> payments;
  final InstallmentTerms? installmentTerms;
  final int discountMinor;

  String encode() => jsonEncode({
    'version': 1,
    'operationKey': operationKey,
    'customerId': customerId,
    'items': [
      for (final item in items) [item.productId, item.qty, item.unitPriceMinor],
    ],
    'payments': [
      for (final payment in payments)
        [payment.method.name, payment.amountMinor, payment.note],
    ],
    'discountMinor': discountMinor,
    'terms': installmentTerms == null
        ? null
        : [
            installmentTerms!.partyId,
            installmentTerms!.count,
            installmentTerms!.firstDueDate.toIso8601String(),
            installmentTerms!.interestMinor,
            installmentTerms!.periodDays,
          ],
  });

  factory PendingSale.decode(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Unknown pending sale version');
    }
    final terms = data['terms'] as List<dynamic>?;
    return PendingSale(
      operationKey: data['operationKey'] as String,
      customerId: data['customerId'] as int?,
      discountMinor: data['discountMinor'] as int,
      items: [
        for (final row in data['items'] as List<dynamic>)
          SaleLineInput(
            productId: row[0] as int,
            qty: row[1] as int,
            unitPriceMinor: row[2] as int,
          ),
      ],
      payments: [
        for (final row in data['payments'] as List<dynamic>)
          PaymentInput(
            PaymentMethod.values.byName(row[0] as String),
            row[1] as int,
            note: row.length > 2 ? row[2] as String? : null,
          ),
      ],
      installmentTerms: terms == null
          ? null
          : InstallmentTerms(
              partyId: terms[0] as int,
              count: terms[1] as int,
              firstDueDate: DateTime.parse(terms[2] as String),
              interestMinor: terms[3] as int,
              periodDays: terms[4] as int,
            ),
    );
  }
}

extension V2PendingSaleUseCases on V2UseCases {
  static const _pendingKey = 'pending.sale.v1';

  Future<PendingSale?> pendingSale() async {
    final row = await (db.select(
      db.appSettings,
    )..where((row) => row.key.equals(_pendingKey))).getSingleOrNull();
    return row == null ? null : PendingSale.decode(row.value);
  }

  /// Never replace an unresolved request, including after navigation/restart.
  Future<PendingSale> stagePendingSale(PendingSale request) =>
      _writeTransaction(() async {
        final existing = await pendingSale();
        if (existing != null) return existing;
        await _upsertSetting(_pendingKey, request.encode());
        await (db.delete(
          db.appSettings,
        )..where((row) => row.key.equals(_saleDraftKey))).go();
        return request;
      });

  Future<AppResult<int>> submitPendingSale(PendingSale request) =>
      _writeTransaction(() async {
        final active = await pendingSale();
        if (active == null || active.encode() != request.encode()) {
          return const AppFailure<int>(
            'طلب البيع المعلّق تغير أو أُلغي. أعد فتح شاشة البيع.',
          );
        }
        return createSale(
          operationKey: request.operationKey,
          customerId: request.customerId,
          items: request.items,
          payments: request.payments,
          installmentTerms: request.installmentTerms,
          discountMinor: request.discountMinor,
        );
      });

  /// Only an already committed operation may be acknowledged as completed.
  Future<bool> acknowledgePendingSale(
    String operationKey,
  ) => _writeTransaction(() async {
    final request = await pendingSale();
    if (request == null || request.operationKey != operationKey) return false;
    final saved =
        await (db.select(db.appSettings)
              ..where((row) => row.key.equals('operation.sale.$operationKey')))
            .getSingleOrNull();
    if (saved == null) return false;
    await (db.delete(
      db.appSettings,
    )..where((row) => row.key.equals(_pendingKey))).go();
    return true;
  });

  /// The check and removal share a transaction with competing sale commits.
  Future<bool> discardUncommittedPendingSale(
    String operationKey,
  ) => _writeTransaction(() async {
    final request = await pendingSale();
    if (request == null || request.operationKey != operationKey) return false;
    final saved =
        await (db.select(db.appSettings)
              ..where((row) => row.key.equals('operation.sale.$operationKey')))
            .getSingleOrNull();
    if (saved != null) return false;
    await (db.delete(
      db.appSettings,
    )..where((row) => row.key.equals(_pendingKey))).go();
    return true;
  });

  /// Converts an uncommitted request back to an editable, non-posting draft.
  /// A newer draft is never replaced by an older pending request.
  Future<bool> restoreUncommittedPendingSaleAsDraft(
    String operationKey,
  ) => _writeTransaction(() async {
    final request = await pendingSale();
    if (request == null || request.operationKey != operationKey) return false;
    final saved =
        await (db.select(db.appSettings)
              ..where((row) => row.key.equals('operation.sale.$operationKey')))
            .getSingleOrNull();
    if (saved != null || await saleDraft() != null) return false;
    final terms = request.installmentTerms;
    int paymentAmount(PaymentMethod method) => request.payments
        .where((payment) => payment.method == method)
        .fold(0, (total, payment) => total + payment.amountMinor);
    await _upsertSetting(
      _saleDraftKey,
      SaleDraft(
        customerId: request.customerId,
        items: request.items,
        cashMinor: paymentAmount(PaymentMethod.cash),
        walletMinor: paymentAmount(PaymentMethod.wallet),
        discountMinor: request.discountMinor,
        interestMinor: terms?.interestMinor ?? 0,
        installmentCount: terms?.count ?? 3,
        firstDueDate:
            terms?.firstDueDate ?? clock().add(const Duration(days: 30)),
        periodDays: terms?.periodDays ?? 30,
        savedAt: clock(),
      ).encode(),
    );
    await (db.delete(
      db.appSettings,
    )..where((row) => row.key.equals(_pendingKey))).go();
    return true;
  });
}
