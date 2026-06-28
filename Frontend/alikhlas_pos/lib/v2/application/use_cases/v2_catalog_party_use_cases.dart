part of '../v2_use_cases.dart';

extension V2CatalogPartyUseCases on V2UseCases {
  Future<AppResult<Product>> createProduct({
    required String name,
    String? barcode,
    String? category,
    String? imagePath,
    required int salePriceMinor,
    required int openingQty,
    required int openingCostMinor,
    int minStockQty = 1,
  }) async {
    if (name.trim().isEmpty) return const AppFailure('اسم المنتج مطلوب');
    if (salePriceMinor <= 0 || openingQty < 0 || openingCostMinor < 0) {
      return const AppFailure(
        'سعر البيع يجب أن يكون أكبر من صفر والقيم لا يمكن أن تكون سالبة',
      );
    }

    final requestedBarcode = _blankToNull(barcode);
    final cleanImagePath = _blankToNull(imagePath);
    if (requestedBarcode != null) {
      final duplicate = await (db.select(
        db.products,
      )..where((p) => p.barcode.equals(requestedBarcode))).getSingleOrNull();
      if (duplicate != null) return const AppFailure('الباركود مستخدم بالفعل');
    }

    final id = await db.transaction(() async {
      final cleanBarcode = requestedBarcode ?? await _nextProductBarcode();
      final productId = await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              name: name.trim(),
              barcode: Value(cleanBarcode),
              category: Value(
                category?.trim().isEmpty == true ? null : category?.trim(),
              ),
              imagePath: Value(cleanImagePath),
              salePriceMinor: salePriceMinor,
              stockQty: Value(openingQty),
              avgCostMinor: Value(openingCostMinor),
              minStockQty: Value(minStockQty),
            ),
          );

      if (openingQty > 0 && openingCostMinor > 0) {
        final value = openingQty * openingCostMinor;
        await _postLedger(
          referenceType: 'opening_stock',
          referenceId: productId,
          description: 'رصيد افتتاحي للمخزون',
          lines: [
            _LedgerLineDraft(AccountCodes.inventory, debitMinor: value),
            _LedgerLineDraft(AccountCodes.capital, creditMinor: value),
          ],
        );
      }
      return productId;
    });

    return AppSuccess(
      await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle(),
    );
  }

  Future<AppResult<Product>> updateProduct({
    required int id,
    required String name,
    String? barcode,
    String? category,
    String? imagePath,
    required int salePriceMinor,
    required int minStockQty,
  }) async {
    if (name.trim().isEmpty) return const AppFailure('اسم المنتج مطلوب');
    if (salePriceMinor <= 0 || minStockQty < 0) {
      return const AppFailure(
        'السعر يجب أن يكون أكبر من صفر والحد الأدنى غير سالب',
      );
    }

    final requestedBarcode = _blankToNull(barcode);
    if (requestedBarcode != null) {
      final duplicate =
          await (db.select(db.products)..where(
                (p) =>
                    p.barcode.equals(requestedBarcode) & p.id.equals(id).not(),
              ))
              .getSingleOrNull();
      if (duplicate != null) return const AppFailure('الباركود مستخدم بالفعل');
    }

    final cleanBarcode = requestedBarcode ?? await _nextProductBarcode();
    await (db.update(db.products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        name: Value(name.trim()),
        barcode: Value(cleanBarcode),
        category: Value(
          category?.trim().isEmpty == true ? null : category?.trim(),
        ),
        imagePath: Value(_blankToNull(imagePath)),
        salePriceMinor: Value(salePriceMinor),
        minStockQty: Value(minStockQty),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return AppSuccess(
      await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle(),
    );
  }

  Future<AppResult<void>> deactivateProduct(int id) async {
    await (db.update(db.products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return const AppSuccess(null);
  }

  Future<AppResult<Customer>> createCustomer({
    required String name,
    String? phone,
  }) async {
    if (name.trim().isEmpty) {
      return const AppFailure('اسم العميل مطلوب');
    }

    final id = await db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(
            name: name.trim(),
            phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
          ),
        );
    return AppSuccess(
      await (db.select(
        db.customers,
      )..where((c) => c.id.equals(id))).getSingle(),
    );
  }

  Future<AppResult<Customer>> updateCustomer({
    required int id,
    required String name,
    String? phone,
  }) async {
    if (name.trim().isEmpty) return const AppFailure('اسم العميل مطلوب');
    await (db.update(db.customers)..where((c) => c.id.equals(id))).write(
      CustomersCompanion(
        name: Value(name.trim()),
        phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
      ),
    );
    return AppSuccess(
      await (db.select(
        db.customers,
      )..where((c) => c.id.equals(id))).getSingle(),
    );
  }

  Future<AppResult<Supplier>> createSupplier({
    required String name,
    String? phone,
  }) async {
    if (name.trim().isEmpty) {
      return const AppFailure('اسم المورد مطلوب');
    }

    final id = await db
        .into(db.suppliers)
        .insert(
          SuppliersCompanion.insert(
            name: name.trim(),
            phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
          ),
        );
    return AppSuccess(
      await (db.select(
        db.suppliers,
      )..where((s) => s.id.equals(id))).getSingle(),
    );
  }

  Future<AppResult<Supplier>> updateSupplier({
    required int id,
    required String name,
    String? phone,
  }) async {
    if (name.trim().isEmpty) return const AppFailure('اسم المورد مطلوب');
    await (db.update(db.suppliers)..where((s) => s.id.equals(id))).write(
      SuppliersCompanion(
        name: Value(name.trim()),
        phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
      ),
    );
    return AppSuccess(
      await (db.select(
        db.suppliers,
      )..where((s) => s.id.equals(id))).getSingle(),
    );
  }
}
