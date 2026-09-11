part of '../v2_use_cases.dart';

const _saleDraftKey = 'draft.sale.v1';
const _purchaseDraftKey = 'draft.purchase.v1';

/// Editable checkout data. A draft has no operation key and is never posted.
class SaleDraft {
  SaleDraft({
    this.customerId,
    required List<SaleLineInput> items,
    required this.cashMinor,
    required this.walletMinor,
    required this.discountMinor,
    required this.interestMinor,
    required this.installmentCount,
    required this.firstDueDate,
    required this.periodDays,
    required this.savedAt,
  }) : items = List.unmodifiable(items) {
    if (items.isEmpty || items.length > 500) {
      throw const FormatException('Invalid sale draft items');
    }
    if (items.any(
      (item) => item.productId <= 0 || item.qty <= 0 || item.unitPriceMinor < 0,
    )) {
      throw const FormatException('Invalid sale draft line');
    }
    if (cashMinor < 0 ||
        walletMinor < 0 ||
        discountMinor < 0 ||
        interestMinor < 0 ||
        installmentCount <= 0 ||
        periodDays <= 0) {
      throw const FormatException('Invalid sale draft values');
    }
  }

  final int? customerId;
  final List<SaleLineInput> items;
  final int cashMinor;
  final int walletMinor;
  final int discountMinor;
  final int interestMinor;
  final int installmentCount;
  final DateTime firstDueDate;
  final int periodDays;
  final DateTime savedAt;

  String encode() => jsonEncode({
    'version': 1,
    'customerId': customerId,
    'items': [
      for (final item in items) [item.productId, item.qty, item.unitPriceMinor],
    ],
    'cashMinor': cashMinor,
    'walletMinor': walletMinor,
    'discountMinor': discountMinor,
    'interestMinor': interestMinor,
    'installmentCount': installmentCount,
    'firstDueDate': firstDueDate.toIso8601String(),
    'periodDays': periodDays,
    'savedAt': savedAt.toIso8601String(),
  });

  factory SaleDraft.decode(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Unknown sale draft version');
    }
    return SaleDraft(
      customerId: data['customerId'] as int?,
      items: [
        for (final row in data['items'] as List<dynamic>)
          SaleLineInput(
            productId: (row as List<dynamic>)[0] as int,
            qty: row[1] as int,
            unitPriceMinor: row[2] as int,
          ),
      ],
      cashMinor: data['cashMinor'] as int,
      walletMinor: data['walletMinor'] as int,
      discountMinor: data['discountMinor'] as int,
      interestMinor: data['interestMinor'] as int,
      installmentCount: data['installmentCount'] as int,
      firstDueDate: DateTime.parse(data['firstDueDate'] as String),
      periodDays: data['periodDays'] as int,
      savedAt: DateTime.parse(data['savedAt'] as String),
    );
  }
}

class PurchaseDraft {
  PurchaseDraft({
    this.supplierId,
    required List<PurchaseLineInput> items,
    required this.cashMinor,
    required this.walletMinor,
    required this.savedAt,
  }) : items = List.unmodifiable(items) {
    if (items.isEmpty || items.length > 500) {
      throw const FormatException('Invalid purchase draft items');
    }
    if (items.any(
      (item) => item.productId <= 0 || item.qty <= 0 || item.unitCostMinor <= 0,
    )) {
      throw const FormatException('Invalid purchase draft line');
    }
    if (cashMinor < 0 || walletMinor < 0) {
      throw const FormatException('Invalid purchase draft values');
    }
  }

  final int? supplierId;
  final List<PurchaseLineInput> items;
  final int cashMinor;
  final int walletMinor;
  final DateTime savedAt;

  String encode() => jsonEncode({
    'version': 1,
    'supplierId': supplierId,
    'items': [
      for (final item in items) [item.productId, item.qty, item.unitCostMinor],
    ],
    'cashMinor': cashMinor,
    'walletMinor': walletMinor,
    'savedAt': savedAt.toIso8601String(),
  });

  factory PurchaseDraft.decode(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Unknown purchase draft version');
    }
    return PurchaseDraft(
      supplierId: data['supplierId'] as int?,
      items: [
        for (final row in data['items'] as List<dynamic>)
          PurchaseLineInput(
            productId: (row as List<dynamic>)[0] as int,
            qty: row[1] as int,
            unitCostMinor: row[2] as int,
          ),
      ],
      cashMinor: data['cashMinor'] as int,
      walletMinor: data['walletMinor'] as int,
      savedAt: DateTime.parse(data['savedAt'] as String),
    );
  }
}

extension V2InvoiceDraftUseCases on V2UseCases {
  Future<SaleDraft?> saleDraft() async {
    final row = await (db.select(
      db.appSettings,
    )..where((row) => row.key.equals(_saleDraftKey))).getSingleOrNull();
    return row == null ? null : SaleDraft.decode(row.value);
  }

  Future<void> saveSaleDraft(SaleDraft draft) => _writeTransaction(() async {
    if (await pendingSale() != null) {
      throw StateError('يوجد طلب بيع يحتاج التحقق قبل حفظ مسودة أخرى.');
    }
    await _upsertSetting(_saleDraftKey, draft.encode());
  });

  Future<void> discardSaleDraft() => _writeTransaction(() async {
    await (db.delete(
      db.appSettings,
    )..where((row) => row.key.equals(_saleDraftKey))).go();
  });

  Future<PurchaseDraft?> purchaseDraft() async {
    final row = await (db.select(
      db.appSettings,
    )..where((row) => row.key.equals(_purchaseDraftKey))).getSingleOrNull();
    return row == null ? null : PurchaseDraft.decode(row.value);
  }

  Future<void> savePurchaseDraft(PurchaseDraft draft) =>
      _writeTransaction(() async {
        if (await pendingPurchase() != null) {
          throw StateError('يوجد طلب شراء يحتاج التحقق قبل حفظ مسودة أخرى.');
        }
        await _upsertSetting(_purchaseDraftKey, draft.encode());
      });

  Future<void> discardPurchaseDraft() => _writeTransaction(() async {
    await (db.delete(
      db.appSettings,
    )..where((row) => row.key.equals(_purchaseDraftKey))).go();
  });
}
