part of '../v2_app.dart';

class _InventoryView extends ConsumerStatefulWidget {
  const _InventoryView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  ConsumerState<_InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends ConsumerState<_InventoryView> {
  final _search = TextEditingController();
  _InventoryFilter _filter = _InventoryFilter.all;
  _InventorySort _sort = _InventorySort.name;
  bool _csvBusy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts();
    final active = widget.snapshot.products.where((p) => p.isActive).toList();
    final lowStock = active.where((p) => p.stockQty <= p.minStockQty).length;
    final inactive = widget.snapshot.products.where((p) => !p.isActive).length;
    final inventoryValue = widget.snapshot.products.fold<int>(
      0,
      (sum, product) => sum + product.inventoryValueMinor,
    );

    return _Screen(
      title: 'المخزون',
      subtitle: 'منتجات وأسعار ورصيد وحد نقص',
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('product-csv-template'),
            onPressed: _csvBusy ? null : _saveCsvTemplate,
            icon: const Icon(Icons.download_outlined),
            label: const Text('قالب CSV'),
          ),
          OutlinedButton.icon(
            key: const ValueKey('product-csv-import'),
            onPressed: _csvBusy ? null : _openCsvImport,
            icon: const Icon(Icons.file_upload_outlined),
            label: Text(_csvBusy ? 'جاري الفحص...' : 'استيراد CSV'),
          ),
          FilledButton.icon(
            onPressed: () => _openProductDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('منتج جديد'),
          ),
        ],
      ),
      child: Column(
        children: [
          _TextMetricsGrid(
            metrics: [
              (
                'الأصناف',
                widget.snapshot.products.length.toString(),
                Icons.category,
              ),
              ('ناقص', lowStock.toString(), Icons.warning_amber),
              ('معطل', inactive.toString(), Icons.block),
              (
                'قيمة المخزون',
                Money(inventoryValue).format(),
                Icons.inventory_2,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _GlassPane(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'بحث بالاسم أو الباركود أو التصنيف',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<_InventoryFilter>(
                    initialValue: _filter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'فلتر'),
                    items: const [
                      DropdownMenuItem(
                        value: _InventoryFilter.all,
                        child: Text('الكل'),
                      ),
                      DropdownMenuItem(
                        value: _InventoryFilter.lowStock,
                        child: Text('ناقص'),
                      ),
                      DropdownMenuItem(
                        value: _InventoryFilter.active,
                        child: Text('نشط'),
                      ),
                      DropdownMenuItem(
                        value: _InventoryFilter.inactive,
                        child: Text('معطل'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _filter = value ?? _filter),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<_InventorySort>(
                    initialValue: _sort,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'ترتيب'),
                    items: const [
                      DropdownMenuItem(
                        value: _InventorySort.name,
                        child: Text('الاسم'),
                      ),
                      DropdownMenuItem(
                        value: _InventorySort.lowStockFirst,
                        child: Text('الأقل رصيد'),
                      ),
                      DropdownMenuItem(
                        value: _InventorySort.price,
                        child: Text('السعر'),
                      ),
                      DropdownMenuItem(
                        value: _InventorySort.updated,
                        child: Text('آخر تحديث'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _sort = value ?? _sort),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _GlassPane(
              child: products.isEmpty
                  ? const Center(child: Text('لا توجد منتجات مطابقة'))
                  : ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ListTile(
                          leading: _ProductAvatar(
                            product: product,
                            warning:
                                product.stockQty <= product.minStockQty &&
                                product.isActive,
                          ),
                          title: Text(product.name),
                          subtitle: Text(
                            'باركود ${product.barcode ?? '-'} · رصيد ${product.stockQty} · حد ${product.minStockQty} · تكلفة ${Money(product.avgCostMinor).format()}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(Money(product.salePriceMinor).format()),
                              IconButton(
                                tooltip: 'طباعة باركود بدل تالف',
                                onPressed: () =>
                                    _printBarcodeForProduct(context, product),
                                icon: const Icon(Icons.qr_code_2),
                              ),
                              IconButton(
                                tooltip: 'جرد وتسوية الرصيد',
                                onPressed: () => _openInventoryAdjustment(
                                  context,
                                  ref,
                                  product,
                                ),
                                icon: const Icon(Icons.fact_check_outlined),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'إجراءات المنتج',
                                onSelected: (action) async {
                                  if (action == 'edit') {
                                    await _openProductDialog(
                                      context,
                                      ref,
                                      product: product,
                                    );
                                    return;
                                  }
                                  if (action == 'deactivate') {
                                    final result = await ref
                                        .read(useCasesProvider)
                                        .deactivateProduct(product.id);
                                    if (!context.mounted) return;
                                    _showResult(
                                      context,
                                      result,
                                      success: 'تم تعطيل المنتج',
                                    );
                                    _refresh(ref);
                                    return;
                                  }
                                  if (action == 'reactivate') {
                                    final result = await ref
                                        .read(useCasesProvider)
                                        .reactivateProduct(product.id);
                                    if (!context.mounted) return;
                                    _showResult(
                                      context,
                                      result,
                                      success: 'تم تفعيل المنتج',
                                    );
                                    _refresh(ref);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      leading: Icon(Icons.edit),
                                      title: Text('تعديل بيانات المنتج'),
                                    ),
                                  ),
                                  if (product.isActive)
                                    const PopupMenuItem(
                                      value: 'deactivate',
                                      child: ListTile(
                                        leading: Icon(Icons.power_settings_new),
                                        title: Text('تعطيل المنتج'),
                                      ),
                                    ),
                                  if (!product.isActive)
                                    const PopupMenuItem(
                                      value: 'reactivate',
                                      child: ListTile(
                                        leading: Icon(Icons.restart_alt),
                                        title: Text('إعادة تفعيل المنتج'),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<Product> _filteredProducts() {
    final query = _search.text.trim();
    final products = widget.snapshot.products.where((product) {
      final matchesQuery =
          query.isEmpty ||
          product.name.contains(query) ||
          (product.barcode?.contains(query) ?? false) ||
          (product.category?.contains(query) ?? false);
      final matchesFilter = switch (_filter) {
        _InventoryFilter.all => true,
        _InventoryFilter.lowStock =>
          product.isActive && product.stockQty <= product.minStockQty,
        _InventoryFilter.active => product.isActive,
        _InventoryFilter.inactive => !product.isActive,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    products.sort((a, b) {
      return switch (_sort) {
        _InventorySort.name => a.name.compareTo(b.name),
        _InventorySort.lowStockFirst => a.stockQty.compareTo(b.stockQty),
        _InventorySort.price => a.salePriceMinor.compareTo(b.salePriceMinor),
        _InventorySort.updated => (b.updatedAt ?? b.createdAt).compareTo(
          a.updatedAt ?? a.createdAt,
        ),
      };
    });
    return products;
  }

  Future<void> _saveCsvTemplate() async {
    if (_csvBusy) return;
    setState(() => _csvBusy = true);
    try {
      final saved = await ref.read(productCsvTemplateSaverProvider)(
        ref.read(useCasesProvider).productCsvTemplate(),
      );
      if (!mounted) return;
      _showSnack(
        context,
        saved ? 'تم حفظ قالب المنتجات' : 'لم يتم اختيار مكان لحفظ القالب',
      );
    } on FileSystemException {
      if (!mounted) return;
      _showSnack(context, 'تعذر حفظ القالب في المكان المختار');
    } finally {
      if (mounted) setState(() => _csvBusy = false);
    }
  }

  Future<void> _openCsvImport() async {
    if (_csvBusy) return;
    setState(() => _csvBusy = true);
    try {
      final picked = await ref.read(productCsvFilePickerProvider)();
      if (!mounted || picked == null) return;
      if (picked.bytes.length > V2ProductCsvImportUseCases.productCsvMaxBytes) {
        _showSnack(context, 'ملف CSV أكبر من الحد المسموح وهو 2 ميجابايت');
        return;
      }
      late final String source;
      try {
        source = utf8.decode(picked.bytes, allowMalformed: false);
      } on FormatException {
        _showSnack(context, 'تعذر قراءة الملف. احفظه بصيغة CSV UTF-8');
        return;
      }
      final useCases = ref.read(useCasesProvider);
      final preview = await useCases.previewProductCsv(source);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _ProductCsvPreviewDialog(fileName: picked.name, preview: preview),
      );
      if (!mounted || confirmed != true || !preview.canImport) return;

      final request = PendingFinancialOperation.productCsvImport(
        operationKey: useCases.newProductCsvImportOperationKey(),
        rows: preview.rows,
      );
      final result = await _submitPendingFinancialOperation(
        useCases,
        request,
        allowNegativeBalance: false,
      );
      if (!mounted) return;
      _showResult(
        context,
        result,
        success: 'تم استيراد ${preview.rows.length} منتج بنجاح',
      );
      if (result is AppSuccess<int>) _refresh(ref);
    } on ProductCsvFileTooLarge {
      if (!mounted) return;
      _showSnack(context, 'ملف CSV أكبر من الحد المسموح وهو 2 ميجابايت');
    } on FileSystemException {
      if (!mounted) return;
      _showSnack(context, 'تعذر فتح ملف CSV المختار');
    } on Object {
      if (!mounted) return;
      _showSnack(
        context,
        'تعذر إكمال الاستيراد. لم نعتمد جزءًا من الملف؛ أعد فتح التطبيق للتحقق من الطلب السابق.',
      );
    } finally {
      if (mounted) setState(() => _csvBusy = false);
    }
  }

  Future<void> _printBarcodeForProduct(
    BuildContext context,
    Product product,
  ) async {
    final labels = await showDialog<List<BarcodeLabelItem>>(
      context: context,
      builder: (_) => _BarcodePrintPromptDialog(
        title: 'طباعة باركود المنتج',
        skipLabel: 'إلغاء',
        items: [
          BarcodeLabelItem(
            productName: product.name,
            barcode: product.barcode,
            quantity: 1,
          ),
        ],
      ),
    );
    if (labels == null || labels.isEmpty || !context.mounted) return;
    await ref.read(barcodeLabelPrinterProvider)(
      labels,
      widget.snapshot.barcodeLabelSettings,
    );
    if (!context.mounted) return;
    _showSnack(context, 'تم إرسال الباركود للطباعة');
  }

  Future<void> _openProductDialog(
    BuildContext context,
    WidgetRef ref, {
    Product? product,
  }) async {
    final data = await showDialog<_ProductFormData>(
      context: context,
      builder: (_) => _ProductDialog(product: product),
    );
    if (data == null || !context.mounted) return;
    final useCases = ref.read(useCasesProvider);
    try {
      if (product == null && data.openingQty > 0) {
        final result = await _submitPendingFinancialOperation(
          useCases,
          PendingFinancialOperation.openingStock(
            operationKey: useCases.newOpeningStockOperationKey(),
            name: data.name,
            barcode: data.barcode,
            category: data.category,
            imagePath: data.imagePath,
            salePriceMinor: data.salePriceMinor,
            openingQty: data.openingQty,
            openingCostMinor: data.openingCostMinor,
            minStockQty: data.minStockQty,
          ),
          allowNegativeBalance: false,
        );
        if (!context.mounted) return;
        _showResult(
          context,
          result,
          success: 'تمت إضافة المنتج ورصيده الافتتاحي',
        );
        _refresh(ref);
        return;
      }
      final result = product == null
          ? await useCases.createProduct(
              name: data.name,
              barcode: data.barcode,
              category: data.category,
              imagePath: data.imagePath,
              salePriceMinor: data.salePriceMinor,
              openingQty: data.openingQty,
              openingCostMinor: data.openingCostMinor,
              minStockQty: data.minStockQty,
            )
          : await useCases.updateProduct(
              id: product.id,
              name: data.name,
              barcode: data.barcode,
              category: data.category,
              imagePath: data.imagePath,
              salePriceMinor: data.salePriceMinor,
              minStockQty: data.minStockQty,
            );
      if (!context.mounted) return;
      _showResult(
        context,
        result,
        success: product == null ? 'تمت إضافة المنتج' : 'تم تحديث المنتج',
      );
      _refresh(ref);
    } on sqlite.SqliteException catch (error) {
      if (!_isDatabaseStorageFailure(error)) rethrow;
      if (!context.mounted) return;
      _showSnack(
        context,
        'تعذر حفظ المنتج. حرّر مساحة على القرص وتأكد من صلاحية مجلد التطبيق، ثم أعد المحاولة.',
      );
    }
  }

  Future<void> _openInventoryAdjustment(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final data = await showDialog<_InventoryAdjustmentFormData>(
      context: context,
      builder: (_) => _InventoryAdjustmentDialog(product: product),
    );
    if (data == null || !context.mounted) return;

    final difference = data.countedQty - product.stockQty;
    final valueDifference = difference * data.unitCostMinor;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد تسوية الجرد'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                product.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text('الرصيد المسجل: ${product.stockQty}'),
              Text('الكمية الفعلية: ${data.countedQty}'),
              Text('الفرق: ${difference > 0 ? '+' : ''}$difference'),
              Text('السبب: ${data.reason.label}'),
              if (data.note != null) Text('التوضيح: ${data.note}'),
              const SizedBox(height: 10),
              Text(
                'تغير قيمة المخزون: ${Money(valueDifference).format()}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              const Text(
                'سيُحفظ مستند تسوية وحركة مخزون وقيد متزن. لا يمكن حذف أثر العملية بعد اعتمادها.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع للمراجعة'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('اعتماد التسوية'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final useCases = ref.read(useCasesProvider);
    final result = await _submitPendingFinancialOperation(
      useCases,
      PendingFinancialOperation.inventoryAdjustment(
        operationKey: useCases.newInventoryAdjustmentOperationKey(),
        productId: product.id,
        expectedStockQty: product.stockQty,
        countedQty: data.countedQty,
        reason: data.reason,
        note: data.note,
        unitCostMinor: data.unitCostMinor,
      ),
      allowNegativeBalance: false,
    );
    if (!context.mounted) return;
    _showResult(context, result, success: 'تم تسجيل تسوية الجرد');
    _refresh(ref);
  }
}
