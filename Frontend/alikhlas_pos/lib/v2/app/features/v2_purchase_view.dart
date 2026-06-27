part of '../v2_app.dart';

class _PurchaseView extends ConsumerStatefulWidget {
  const _PurchaseView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  ConsumerState<_PurchaseView> createState() => _PurchaseViewState();
}

class _PurchaseViewState extends ConsumerState<_PurchaseView> {
  final _search = TextEditingController();
  final _cash = TextEditingController();
  final _wallet = TextEditingController();
  final _cart = <_PurchaseCartLine>[];
  int? _supplierId;

  @override
  void dispose() {
    _search.dispose();
    _cash.dispose();
    _wallet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final products = widget.snapshot.products.where((product) {
      return query.isEmpty ||
          product.name.contains(query) ||
          (product.barcode?.contains(query) ?? false) ||
          (product.category?.contains(query) ?? false);
    }).toList();
    final total = _cart.fold<int>(
      0,
      (sum, line) => sum + line.qty * line.costMinor,
    );
    final cash = _parseMoney(_cash.text);
    final wallet = _parseMoney(_wallet.text);
    final paid = cash + wallet;
    final remaining = total - paid;
    final moneyError = _firstMoneyInputError({'كاش': _cash, 'محفظة': _wallet});
    final costError = _firstPurchaseCostError(_cart);
    return _Screen(
      title: 'الشراء',
      subtitle: 'فاتورة مشتريات مع تحديث WAC ودفع كاش/محفظة/آجل',
      child: Row(
        children: [
          Expanded(
            child: _GlassPane(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'بحث منتج أو باركود',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _openQuickProduct,
                        icon: const Icon(Icons.add_box),
                        label: const Text('منتج جديد'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: products.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('لا توجد منتجات مطابقة'),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _openQuickProduct,
                                  icon: const Icon(Icons.add_box),
                                  label: const Text('إضافة المنتج كجديد'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: products.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final product = products[index];
                              return ListTile(
                                leading: _ProductAvatar(product: product),
                                title: Text(product.name),
                                subtitle: Text(
                                  'رصيد ${product.stockQty} · تكلفة ${Money(product.avgCostMinor).format()}',
                                ),
                                trailing: IconButton(
                                  tooltip: 'إضافة للفاتورة',
                                  icon: const Icon(Icons.add),
                                  onPressed: () =>
                                      setState(() => _addToCart(product)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 430,
            child: _GlassPane(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: _supplierId,
                    decoration: const InputDecoration(
                      labelText: 'المورد عند الآجل',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('بدون مورد'),
                      ),
                      for (final supplier in widget.snapshot.suppliers)
                        DropdownMenuItem<int?>(
                          value: supplier.id,
                          child: Text(supplier.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _supplierId = value),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _PurchaseCart(
                      cart: _cart,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: _moneyField(
                          _cash,
                          'كاش',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _moneyField(
                          _wallet,
                          'محفظة',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AmountRow('الإجمالي', total, strong: true),
                  _AmountRow('المدفوع', paid),
                  _AmountRow('الآجل', remaining < 0 ? 0 : remaining),
                  if (moneyError != null || costError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      moneyError ?? costError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (remaining > 0 && _supplierId == null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'اختر موردًا لتسجيل الجزء الآجل',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _cart.isEmpty
                        ? null
                        : () => _submitPurchase(total),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('تسجيل الشراء'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart(Product product) {
    _PurchaseCartLine? existing;
    for (final line in _cart) {
      if (line.product.id == product.id) {
        existing = line;
        break;
      }
    }
    if (existing == null) {
      _cart.add(_PurchaseCartLine(product));
    } else {
      existing.qty++;
    }
  }

  Future<void> _openQuickProduct() async {
    final data = await showDialog<_ProductFormData>(
      context: context,
      builder: (_) => const _ProductDialog(quickPurchase: true),
    );
    if (data == null || !mounted) return;
    final result = await ref
        .read(useCasesProvider)
        .createProduct(
          name: data.name,
          barcode: data.barcode,
          category: data.category,
          imagePath: data.imagePath,
          salePriceMinor: data.salePriceMinor,
          openingQty: 0,
          openingCostMinor: 0,
          minStockQty: data.minStockQty,
        );
    if (!mounted) return;
    _showResult(context, result, success: 'تمت إضافة المنتج للفاتورة');
    if (result case AppSuccess<Product>(value: final product)) {
      setState(() {
        _search.clear();
        _addToCart(product);
      });
      _refresh(ref);
    }
  }

  Future<void> _submitPurchase(int total) async {
    final cash = _requireMoney(context, _cash, 'كاش');
    final wallet = _requireMoney(context, _wallet, 'محفظة');
    if (cash == null || wallet == null) return;
    final invalidCost = _firstPurchaseCostError(_cart);
    if (invalidCost != null) {
      _showSnack(context, invalidCost);
      return;
    }
    final result = await _runWithNegativeBalanceApproval(
      context,
      action: (allowNegativeBalance) => ref
          .read(useCasesProvider)
          .createPurchase(
            supplierId: _supplierId,
            items: [
              for (final line in _cart)
                PurchaseLineInput(
                  productId: line.product.id,
                  qty: line.qty,
                  unitCostMinor: line.costMinor,
                ),
            ],
            payments: [
              PaymentInput(PaymentMethod.cash, cash),
              PaymentInput(PaymentMethod.wallet, wallet),
            ],
            allowNegativeBalance: allowNegativeBalance,
          ),
    );
    if (!mounted) return;
    final barcodeItems = _barcodeItemsFromPurchaseCart(_cart);
    _showResult(context, result, success: 'تم تسجيل الشراء');
    if (result is AppSuccess<int>) {
      await _promptBarcodePrinting(barcodeItems);
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _cash.clear();
        _wallet.clear();
      });
      _refresh(ref);
    }
  }

  List<BarcodeLabelItem> _barcodeItemsFromPurchaseCart(
    List<_PurchaseCartLine> cart,
  ) {
    return [
      for (final line in cart)
        BarcodeLabelItem(
          productName: line.product.name,
          barcode: line.product.barcode,
          quantity: line.qty,
        ),
    ];
  }

  Future<void> _promptBarcodePrinting(List<BarcodeLabelItem> items) async {
    final printable = BarcodeLabelsPdf.printableItems(items);
    if (printable.isEmpty && items.isEmpty) return;
    final labels = await showDialog<List<BarcodeLabelItem>>(
      context: context,
      builder: (_) => _BarcodePrintPromptDialog(items: items),
    );
    if (labels == null || labels.isEmpty || !mounted) return;
    await ref.read(barcodeLabelPrinterProvider)(labels);
  }
}
