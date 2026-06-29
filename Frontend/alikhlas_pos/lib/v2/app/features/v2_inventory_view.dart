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
    final inventoryValue = active.fold<int>(
      0,
      (sum, product) => sum + product.stockQty * product.avgCostMinor,
    );

    return _Screen(
      title: 'المخزون',
      subtitle: 'منتجات وأسعار ورصيد وحد نقص',
      trailing: FilledButton.icon(
        onPressed: () => _openProductDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('منتج جديد'),
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
                                tooltip: 'تعديل',
                                onPressed: () => _openProductDialog(
                                  context,
                                  ref,
                                  product: product,
                                ),
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                tooltip: 'تعطيل',
                                onPressed: product.isActive
                                    ? () async {
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
                                      }
                                    : null,
                                icon: const Icon(Icons.power_settings_new),
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
    final result = product == null
        ? await ref
              .read(useCasesProvider)
              .createProduct(
                name: data.name,
                barcode: data.barcode,
                category: data.category,
                imagePath: data.imagePath,
                salePriceMinor: data.salePriceMinor,
                openingQty: data.openingQty,
                openingCostMinor: data.openingCostMinor,
                minStockQty: data.minStockQty,
              )
        : await ref
              .read(useCasesProvider)
              .updateProduct(
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
  }
}
