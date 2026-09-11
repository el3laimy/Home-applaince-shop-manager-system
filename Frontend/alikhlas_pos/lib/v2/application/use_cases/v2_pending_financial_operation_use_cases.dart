part of '../v2_use_cases.dart';

enum PendingFinancialOperationKind {
  customerInstallment,
  supplierInstallment,
  saleReturn,
  expense,
  openShift,
  closeShift,
  openingStock,
  inventoryAdjustment,
  openingBalance,
}

/// One explicitly recoverable mutation outside the sale and purchase carts.
///
/// Negative-liquid-balance consent is deliberately excluded: a recovered
/// request must ask the owner again before allowing a negative balance.
class PendingFinancialOperation {
  PendingFinancialOperation._({
    required this.kind,
    required this.operationKey,
    this.planId,
    this.saleId,
    this.amountMinor,
    this.method,
    Map<int, int>? saleItemQuantities,
    this.overflowRefundMethod,
    this.description,
    this.productName,
    this.productBarcode,
    this.productCategory,
    this.productImagePath,
    this.productSalePriceMinor,
    this.productOpeningCostMinor,
    this.productMinStockQty,
    this.productId,
    this.expectedStockQty,
    this.countedQty,
    this.inventoryAdjustmentReason,
    this.inventoryAdjustmentNote,
    this.inventoryAdjustmentUnitCostMinor,
    this.openingBalanceType,
    this.openingBalancePartyId,
    this.openingBalanceDueDate,
    this.openingBalanceNote,
  }) : saleItemQuantities = Map.unmodifiable(saleItemQuantities ?? const {}) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(operationKey)) {
      throw const FormatException('Invalid pending financial operation key');
    }
  }

  factory PendingFinancialOperation.customerInstallment({
    required String operationKey,
    required int planId,
    required int amountMinor,
    required PaymentMethod method,
  }) => PendingFinancialOperation._(
    kind: PendingFinancialOperationKind.customerInstallment,
    operationKey: operationKey,
    planId: planId,
    amountMinor: amountMinor,
    method: method,
  );

  factory PendingFinancialOperation.supplierInstallment({
    required String operationKey,
    required int planId,
    required int amountMinor,
    required PaymentMethod method,
  }) => PendingFinancialOperation._(
    kind: PendingFinancialOperationKind.supplierInstallment,
    operationKey: operationKey,
    planId: planId,
    amountMinor: amountMinor,
    method: method,
  );

  factory PendingFinancialOperation.saleReturn({
    required String operationKey,
    required int saleId,
    required Map<int, int> saleItemQuantities,
    required PaymentMethod refundMethod,
    PaymentMethod? overflowRefundMethod,
  }) => PendingFinancialOperation._(
    kind: PendingFinancialOperationKind.saleReturn,
    operationKey: operationKey,
    saleId: saleId,
    saleItemQuantities: saleItemQuantities,
    method: refundMethod,
    overflowRefundMethod: overflowRefundMethod,
  );

  factory PendingFinancialOperation.expense({
    required String operationKey,
    required String description,
    required int amountMinor,
    required PaymentMethod method,
  }) => PendingFinancialOperation._(
    kind: PendingFinancialOperationKind.expense,
    operationKey: operationKey,
    description: description,
    amountMinor: amountMinor,
    method: method,
  );

  factory PendingFinancialOperation.openShift({
    required String operationKey,
    required int openingCashMinor,
  }) => PendingFinancialOperation._(
    kind: PendingFinancialOperationKind.openShift,
    operationKey: operationKey,
    amountMinor: openingCashMinor,
  );

  factory PendingFinancialOperation.closeShift({
    required String operationKey,
    required int actualCashMinor,
  }) => PendingFinancialOperation._(
    kind: PendingFinancialOperationKind.closeShift,
    operationKey: operationKey,
    amountMinor: actualCashMinor,
  );

  factory PendingFinancialOperation.openingStock({
    required String operationKey,
    required String name,
    String? barcode,
    String? category,
    String? imagePath,
    required int salePriceMinor,
    required int openingQty,
    required int openingCostMinor,
    required int minStockQty,
  }) => PendingFinancialOperation._(
    kind: PendingFinancialOperationKind.openingStock,
    operationKey: operationKey,
    amountMinor: openingQty,
    productName: name,
    productBarcode: barcode,
    productCategory: category,
    productImagePath: imagePath,
    productSalePriceMinor: salePriceMinor,
    productOpeningCostMinor: openingCostMinor,
    productMinStockQty: minStockQty,
  );

  factory PendingFinancialOperation.inventoryAdjustment({
    required String operationKey,
    required int productId,
    required int expectedStockQty,
    required int countedQty,
    required InventoryAdjustmentReason reason,
    String? note,
    required int unitCostMinor,
  }) => PendingFinancialOperation._(
    kind: PendingFinancialOperationKind.inventoryAdjustment,
    operationKey: operationKey,
    productId: productId,
    expectedStockQty: expectedStockQty,
    countedQty: countedQty,
    inventoryAdjustmentReason: reason,
    inventoryAdjustmentNote: note,
    inventoryAdjustmentUnitCostMinor: unitCostMinor,
  );

  factory PendingFinancialOperation.openingBalance({
    required String operationKey,
    required OpeningBalanceType type,
    int? partyId,
    required int amountMinor,
    DateTime? dueDate,
    String? note,
  }) => PendingFinancialOperation._(
    kind: PendingFinancialOperationKind.openingBalance,
    operationKey: operationKey,
    amountMinor: amountMinor,
    openingBalanceType: type,
    openingBalancePartyId: partyId,
    openingBalanceDueDate: dueDate,
    openingBalanceNote: note,
  );

  final PendingFinancialOperationKind kind;
  final String operationKey;
  final int? planId;
  final int? saleId;
  final int? amountMinor;
  final PaymentMethod? method;
  final Map<int, int> saleItemQuantities;
  final PaymentMethod? overflowRefundMethod;
  final String? description;
  final String? productName;
  final String? productBarcode;
  final String? productCategory;
  final String? productImagePath;
  final int? productSalePriceMinor;
  final int? productOpeningCostMinor;
  final int? productMinStockQty;
  final int? productId;
  final int? expectedStockQty;
  final int? countedQty;
  final InventoryAdjustmentReason? inventoryAdjustmentReason;
  final String? inventoryAdjustmentNote;
  final int? inventoryAdjustmentUnitCostMinor;
  final OpeningBalanceType? openingBalanceType;
  final int? openingBalancePartyId;
  final DateTime? openingBalanceDueDate;
  final String? openingBalanceNote;

  String get receiptNamespace => switch (kind) {
    PendingFinancialOperationKind.customerInstallment => 'installment.customer',
    PendingFinancialOperationKind.supplierInstallment => 'installment.supplier',
    PendingFinancialOperationKind.saleReturn => 'sale_return',
    PendingFinancialOperationKind.expense => 'expense',
    PendingFinancialOperationKind.openShift => 'shift.open',
    PendingFinancialOperationKind.closeShift => 'shift.close',
    PendingFinancialOperationKind.openingStock => 'opening_stock',
    PendingFinancialOperationKind.inventoryAdjustment => 'inventory_adjustment',
    PendingFinancialOperationKind.openingBalance => 'opening_balance',
  };

  String get label => switch (kind) {
    PendingFinancialOperationKind.customerInstallment => 'تحصيل قسط عميل',
    PendingFinancialOperationKind.supplierInstallment => 'سداد قسط مورد',
    PendingFinancialOperationKind.saleReturn => 'مرتجع بيع',
    PendingFinancialOperationKind.expense => 'تسجيل مصروف',
    PendingFinancialOperationKind.openShift => 'فتح وردية',
    PendingFinancialOperationKind.closeShift => 'إغلاق وردية',
    PendingFinancialOperationKind.openingStock => 'إدخال رصيد افتتاحي للمخزون',
    PendingFinancialOperationKind.inventoryAdjustment =>
      'تسوية فرق جرد المخزون',
    PendingFinancialOperationKind.openingBalance => 'إدخال رصيد افتتاحي',
  };

  String encode() {
    final quantities = saleItemQuantities.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return jsonEncode({
      'version': 1,
      'kind': kind.name,
      'operationKey': operationKey,
      'planId': planId,
      'saleId': saleId,
      'amountMinor': amountMinor,
      'method': method?.name,
      'saleItemQuantities': [
        for (final item in quantities) [item.key, item.value],
      ],
      'overflowRefundMethod': overflowRefundMethod?.name,
      'description': description,
      'productName': productName,
      'productBarcode': productBarcode,
      'productCategory': productCategory,
      'productImagePath': productImagePath,
      'productSalePriceMinor': productSalePriceMinor,
      'productOpeningCostMinor': productOpeningCostMinor,
      'productMinStockQty': productMinStockQty,
      'productId': productId,
      'expectedStockQty': expectedStockQty,
      'countedQty': countedQty,
      'inventoryAdjustmentReason': inventoryAdjustmentReason?.name,
      'inventoryAdjustmentNote': inventoryAdjustmentNote,
      'inventoryAdjustmentUnitCostMinor': inventoryAdjustmentUnitCostMinor,
      'openingBalanceType': openingBalanceType?.name,
      'openingBalancePartyId': openingBalancePartyId,
      'openingBalanceDueDate': openingBalanceDueDate?.toIso8601String(),
      'openingBalanceNote': openingBalanceNote,
    });
  }

  factory PendingFinancialOperation.decode(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException(
        'Unknown pending financial operation version',
      );
    }
    final kind = PendingFinancialOperationKind.values.byName(
      data['kind'] as String,
    );
    final key = data['operationKey'] as String;
    final method = data['method'] as String?;
    final overflow = data['overflowRefundMethod'] as String?;
    final quantities = <int, int>{
      for (final row in data['saleItemQuantities'] as List<dynamic>)
        row[0] as int: row[1] as int,
    };

    return switch (kind) {
      PendingFinancialOperationKind.customerInstallment =>
        PendingFinancialOperation.customerInstallment(
          operationKey: key,
          planId: data['planId'] as int,
          amountMinor: data['amountMinor'] as int,
          method: PaymentMethod.values.byName(method!),
        ),
      PendingFinancialOperationKind.supplierInstallment =>
        PendingFinancialOperation.supplierInstallment(
          operationKey: key,
          planId: data['planId'] as int,
          amountMinor: data['amountMinor'] as int,
          method: PaymentMethod.values.byName(method!),
        ),
      PendingFinancialOperationKind.saleReturn =>
        PendingFinancialOperation.saleReturn(
          operationKey: key,
          saleId: data['saleId'] as int,
          saleItemQuantities: quantities,
          refundMethod: PaymentMethod.values.byName(method!),
          overflowRefundMethod: overflow == null
              ? null
              : PaymentMethod.values.byName(overflow),
        ),
      PendingFinancialOperationKind.expense =>
        PendingFinancialOperation.expense(
          operationKey: key,
          description: data['description'] as String,
          amountMinor: data['amountMinor'] as int,
          method: PaymentMethod.values.byName(method!),
        ),
      PendingFinancialOperationKind.openShift =>
        PendingFinancialOperation.openShift(
          operationKey: key,
          openingCashMinor: data['amountMinor'] as int,
        ),
      PendingFinancialOperationKind.closeShift =>
        PendingFinancialOperation.closeShift(
          operationKey: key,
          actualCashMinor: data['amountMinor'] as int,
        ),
      PendingFinancialOperationKind.openingStock =>
        PendingFinancialOperation.openingStock(
          operationKey: key,
          name: data['productName'] as String,
          barcode: data['productBarcode'] as String?,
          category: data['productCategory'] as String?,
          imagePath: data['productImagePath'] as String?,
          salePriceMinor: data['productSalePriceMinor'] as int,
          openingQty: data['amountMinor'] as int,
          openingCostMinor: data['productOpeningCostMinor'] as int,
          minStockQty: data['productMinStockQty'] as int,
        ),
      PendingFinancialOperationKind.inventoryAdjustment =>
        PendingFinancialOperation.inventoryAdjustment(
          operationKey: key,
          productId: data['productId'] as int,
          expectedStockQty: data['expectedStockQty'] as int,
          countedQty: data['countedQty'] as int,
          reason: InventoryAdjustmentReason.values.byName(
            data['inventoryAdjustmentReason'] as String,
          ),
          note: data['inventoryAdjustmentNote'] as String?,
          unitCostMinor: data['inventoryAdjustmentUnitCostMinor'] as int,
        ),
      PendingFinancialOperationKind.openingBalance =>
        PendingFinancialOperation.openingBalance(
          operationKey: key,
          type: OpeningBalanceType.values.byName(
            data['openingBalanceType'] as String,
          ),
          partyId: data['openingBalancePartyId'] as int?,
          amountMinor: data['amountMinor'] as int,
          dueDate: data['openingBalanceDueDate'] == null
              ? null
              : DateTime.parse(data['openingBalanceDueDate'] as String),
          note: data['openingBalanceNote'] as String?,
        ),
    };
  }
}

extension V2PendingFinancialOperationUseCases on V2UseCases {
  static const _pendingKey = 'pending.financial_operation.v1';

  Future<PendingFinancialOperation?> pendingFinancialOperation() async {
    final row = await (db.select(
      db.appSettings,
    )..where((row) => row.key.equals(_pendingKey))).getSingleOrNull();
    return row == null ? null : PendingFinancialOperation.decode(row.value);
  }

  Future<PendingFinancialOperation> stagePendingFinancialOperation(
    PendingFinancialOperation request,
  ) => _writeTransaction(() async {
    final existing = await pendingFinancialOperation();
    if (existing != null) return existing;
    await _upsertSetting(_pendingKey, request.encode());
    return request;
  });

  Future<AppResult<int>> submitPendingFinancialOperation(
    PendingFinancialOperation request, {
    bool allowNegativeBalance = false,
  }) => _writeTransaction(() async {
    final active = await pendingFinancialOperation();
    if (active == null || active.encode() != request.encode()) {
      return const AppFailure<int>(
        'الطلب المالي المعلّق تغير أو أُلغي. أعد فتح الشاشة.',
      );
    }
    return switch (request.kind) {
      PendingFinancialOperationKind.customerInstallment => collectInstallment(
        operationKey: request.operationKey,
        planId: request.planId!,
        amountMinor: request.amountMinor!,
        method: request.method!,
      ),
      PendingFinancialOperationKind.supplierInstallment =>
        paySupplierInstallment(
          operationKey: request.operationKey,
          planId: request.planId!,
          amountMinor: request.amountMinor!,
          method: request.method!,
          allowNegativeBalance: allowNegativeBalance,
        ),
      PendingFinancialOperationKind.saleReturn => createSaleReturn(
        operationKey: request.operationKey,
        saleId: request.saleId!,
        saleItemQuantities: request.saleItemQuantities,
        refundMethod: request.method!,
        overflowRefundMethod: request.overflowRefundMethod,
        allowNegativeBalance: allowNegativeBalance,
      ),
      PendingFinancialOperationKind.expense => recordExpense(
        operationKey: request.operationKey,
        description: request.description!,
        amountMinor: request.amountMinor!,
        method: request.method!,
        allowNegativeBalance: allowNegativeBalance,
      ),
      PendingFinancialOperationKind.openShift => openShift(
        request.amountMinor!,
        operationKey: request.operationKey,
      ).then(_shiftResultId),
      PendingFinancialOperationKind.closeShift => closeShift(
        request.amountMinor!,
        operationKey: request.operationKey,
      ).then(_shiftResultId),
      PendingFinancialOperationKind.openingStock => createProduct(
        operationKey: request.operationKey,
        name: request.productName!,
        barcode: request.productBarcode,
        category: request.productCategory,
        imagePath: request.productImagePath,
        salePriceMinor: request.productSalePriceMinor!,
        openingQty: request.amountMinor!,
        openingCostMinor: request.productOpeningCostMinor!,
        minStockQty: request.productMinStockQty!,
      ).then(_productResultId),
      PendingFinancialOperationKind.inventoryAdjustment => reconcileInventory(
        operationKey: request.operationKey,
        productId: request.productId!,
        expectedStockQty: request.expectedStockQty!,
        countedQty: request.countedQty!,
        reason: request.inventoryAdjustmentReason!,
        note: request.inventoryAdjustmentNote,
        unitCostMinor: request.inventoryAdjustmentUnitCostMinor!,
      ),
      PendingFinancialOperationKind.openingBalance => recordOpeningBalance(
        operationKey: request.operationKey,
        type: request.openingBalanceType!,
        partyId: request.openingBalancePartyId,
        amountMinor: request.amountMinor!,
        dueDate: request.openingBalanceDueDate,
        note: request.openingBalanceNote,
      ),
    };
  });

  AppResult<int> _shiftResultId(AppResult<Shift> result) => switch (result) {
    AppSuccess<Shift>(value: final shift) => AppSuccess<int>(shift.id),
    AppFailure<Shift>(message: final message) => AppFailure<int>(message),
  };

  AppResult<int> _productResultId(AppResult<Product> result) =>
      switch (result) {
        AppSuccess<Product>(value: final product) => AppSuccess<int>(
          product.id,
        ),
        AppFailure<Product>(message: final message) => AppFailure<int>(message),
      };

  Future<bool> acknowledgePendingFinancialOperation(String operationKey) =>
      _writeTransaction(() async {
        final request = await pendingFinancialOperation();
        if (request == null || request.operationKey != operationKey) {
          return false;
        }
        final saved =
            await (db.select(db.appSettings)..where(
                  (row) => row.key.equals(
                    'operation.${request.receiptNamespace}.$operationKey',
                  ),
                ))
                .getSingleOrNull();
        if (saved == null) return false;
        await (db.delete(
          db.appSettings,
        )..where((row) => row.key.equals(_pendingKey))).go();
        return true;
      });

  Future<bool> discardUncommittedPendingFinancialOperation(
    String operationKey,
  ) => _writeTransaction(() async {
    final request = await pendingFinancialOperation();
    if (request == null || request.operationKey != operationKey) return false;
    final saved =
        await (db.select(db.appSettings)..where(
              (row) => row.key.equals(
                'operation.${request.receiptNamespace}.$operationKey',
              ),
            ))
            .getSingleOrNull();
    if (saved != null) return false;
    await (db.delete(
      db.appSettings,
    )..where((row) => row.key.equals(_pendingKey))).go();
    return true;
  });
}
