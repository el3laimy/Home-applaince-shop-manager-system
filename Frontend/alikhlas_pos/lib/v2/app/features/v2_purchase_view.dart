part of '../v2_app.dart';

class _PurchaseView extends ConsumerStatefulWidget {
  const _PurchaseView({required this.snapshot, required this.onDirtyChanged});
  final WorkbenchSnapshot snapshot;
  final ValueChanged<bool> onDirtyChanged;

  @override
  ConsumerState<_PurchaseView> createState() => _PurchaseViewState();
}

class _PurchaseViewState extends ConsumerState<_PurchaseView> {
  final _search = TextEditingController();
  final _cash = TextEditingController();
  final _wallet = TextEditingController();
  final _cart = <_PurchaseCartLine>[];
  int? _supplierId;
  bool _saving = false;
  PendingPurchase? _pendingPurchase;
  bool _recoveringPurchase = false;
  bool _loadingPending = true;
  bool _pendingLoadFailed = false;
  String? _pendingError;
  bool _dirty = false;
  bool _hasSavedDraft = false;
  String? _draftNotice;

  @override
  void initState() {
    super.initState();
    _loadPendingPurchase();
  }

  Future<void> _loadPendingPurchase() async {
    setState(() => _loadingPending = true);
    try {
      final useCases = ref.read(useCasesProvider);
      final request = await useCases.pendingPurchase();
      PurchaseDraft? draft;
      var draftUnreadable = false;
      if (request == null) {
        try {
          draft = await useCases.purchaseDraft();
        } catch (_) {
          draftUnreadable = true;
        }
      }
      if (!mounted) return;
      _pendingPurchase = request;
      _recoveringPurchase = request != null;
      if (draft != null) _restoreDraft(draft);
      if (draftUnreadable) {
        _hasSavedDraft = true;
        _draftNotice =
            'تعذر قراءة مسودة الشراء. لم تُسجل منها حركة مالية؛ يمكنك مسحها وبدء فاتورة جديدة.';
      }
      _pendingLoadFailed = false;
    } catch (_) {
      if (mounted) _pendingLoadFailed = true;
    } finally {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> _discardPendingPurchase() async {
    if (_saving || _pendingPurchase == null) return;
    setState(() => _saving = true);
    try {
      final removed = await ref
          .read(useCasesProvider)
          .restoreUncommittedPendingPurchaseAsDraft(
            _pendingPurchase!.operationKey,
          );
      if (!mounted) return;
      if (removed) {
        _pendingPurchase = null;
        _pendingError = null;
        final draft = await ref.read(useCasesProvider).purchaseDraft();
        if (!mounted) return;
        if (draft != null) _restoreDraft(draft);
      } else {
        _pendingError =
            'لا يمكن العودة للتعديل؛ قد تكون الفاتورة محفوظة أو توجد مسودة أخرى. استخدم التحقق.';
      }
    } catch (_) {
      if (mounted) _pendingError = 'تعذر إلغاء الطلب. أعد المحاولة.';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
    if (_loadingPending) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pendingLoadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تعذر قراءة طلب الشراء السابق. لن يبدأ شراء جديد حتى يتم التحقق.',
            ),
            TextButton(
              onPressed: _loadPendingPurchase,
              child: const Text('إعادة محاولة قراءة الطلب'),
            ),
          ],
        ),
      );
    }
    if (_pendingPurchase != null) {
      return _Screen(
        title: 'الشراء',
        subtitle: 'التحقق من نتيجة الحفظ',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'يوجد طلب شراء يحتاج استكمال التحقق. إعادة المحاولة تستخدم نفس الطلب.',
              ),
              const SizedBox(height: 12),
              Text('عدد الأصناف: ${_pendingPurchase!.items.length}'),
              if (_pendingError != null) Text(_pendingError!),
              FilledButton(
                onPressed: _saving ? null : _savePendingPurchase,
                child: Text(
                  _saving ? 'جاري التحقق...' : 'التحقق وإعادة المحاولة',
                ),
              ),
              TextButton(
                onPressed: _saving ? null : _discardPendingPurchase,
                child: const Text('العودة لتعديل المسودة'),
              ),
            ],
          ),
        ),
      );
    }
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
    return AbsorbPointer(
      absorbing: _saving,
      child: _Screen(
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
                                    onPressed: () {
                                      _markDirty();
                                      setState(() => _addToCart(product));
                                    },
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
                      onChanged: (value) {
                        _markDirty();
                        setState(() => _supplierId = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _PurchaseCart(
                        cart: _cart,
                        onChanged: () {
                          _markDirty();
                          setState(() {});
                        },
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: _moneyField(
                            _cash,
                            'كاش',
                            onChanged: (_) {
                              _markDirty();
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _moneyField(
                            _wallet,
                            'محفظة',
                            onChanged: (_) {
                              _markDirty();
                              setState(() {});
                            },
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
                    if (_draftNotice != null) ...[
                      Text(
                        _draftNotice!,
                        style: const TextStyle(color: V2DesignTokens.inkMuted),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving || _cart.isEmpty
                                ? null
                                : () => _submitPurchase(total),
                            icon: const Icon(Icons.check_circle),
                            label: Text(
                              _saving ? 'جاري الحفظ...' : 'تسجيل الشراء',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _saving || _cart.isEmpty
                              ? null
                              : _saveDraft,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            _hasSavedDraft ? 'تحديث المسودة' : 'حفظ مسودة',
                          ),
                        ),
                        if (_hasSavedDraft) ...[
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: _saving ? null : _discardDraft,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('مسح'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
      _markDirty();
      setState(() {
        _search.clear();
        _addToCart(product);
      });
      _refresh(ref);
    }
  }

  Future<void> _submitPurchase(int total) async {
    if (_saving ||
        _pendingPurchase != null ||
        _loadingPending ||
        _pendingLoadFailed) {
      return;
    }
    final cash = _requireMoney(context, _cash, 'كاش');
    final wallet = _requireMoney(context, _wallet, 'محفظة');
    if (cash == null || wallet == null) return;
    final invalidCost = _firstPurchaseCostError(_cart);
    if (invalidCost != null) {
      _showSnack(context, invalidCost);
      return;
    }
    final operationKey = ref.read(useCasesProvider).newPurchaseOperationKey();
    final supplierId = _supplierId;
    final items = [
      for (final line in _cart)
        PurchaseLineInput(
          productId: line.product.id,
          qty: line.qty,
          unitCostMinor: line.costMinor,
        ),
    ];
    final payments = [
      PaymentInput(PaymentMethod.cash, cash),
      PaymentInput(PaymentMethod.wallet, wallet),
    ];
    _recoveringPurchase = false;
    _pendingError = null;
    _pendingPurchase = PendingPurchase(
      operationKey: operationKey,
      supplierId: supplierId,
      items: items,
      payments: payments,
    );
    await _savePendingPurchase();
  }

  Future<void> _savePendingPurchase() async {
    if (_saving || _pendingPurchase == null) return;
    setState(() => _saving = true);
    try {
      final useCases = ref.read(useCasesProvider);
      final requestedKey = _pendingPurchase!.operationKey;
      final request = await useCases.stagePendingPurchase(_pendingPurchase!);
      if (!mounted) return;
      _pendingPurchase = request;
      if (request.operationKey != requestedKey) {
        _recoveringPurchase = true;
        _pendingError = 'يوجد طلب شراء سابق لم تُحسم نتيجته. راجعه أولًا.';
        return;
      }
      _hasSavedDraft = false;
      _draftNotice = null;
      _markClean();
      final result = await _runWithNegativeBalanceApproval(
        context,
        action: (allowNegativeBalance) => ref.read(purchaseWriterProvider)(
          operationKey: request.operationKey,
          supplierId: request.supplierId,
          items: request.items,
          payments: request.payments,
          allowNegativeBalance: allowNegativeBalance,
        ),
      );
      if (!mounted) return;
      if (result is AppFailure<int>) {
        _pendingError = result.message;
        if (!_recoveringPurchase) {
          final removed = await useCases.discardUncommittedPendingPurchase(
            request.operationKey,
          );
          if (!mounted) return;
          if (removed) {
            _pendingPurchase = null;
            _markDirty();
          }
        }
        _showResult(context, result, success: 'تم تسجيل الشراء');
      }
      if (result is AppSuccess<int>) {
        setState(() {
          _cart.clear();
          _cash.clear();
          _wallet.clear();
          _hasSavedDraft = false;
          _draftNotice = null;
        });
        _markClean();
        final acknowledged = await useCases.acknowledgePendingPurchase(
          request.operationKey,
        );
        if (!mounted) return;
        if (!acknowledged) {
          throw StateError('Purchase acknowledgement failed');
        }
        _pendingPurchase = null;
        _pendingError = null;
        final labels = _barcodeItemsFromPurchaseRequest(request);
        _refresh(ref);
        _showSnack(context, 'تم تسجيل الشراء');
        try {
          await _promptBarcodePrinting(labels);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            _showSnack(
              context,
              'تم حفظ الشراء. تعذرت طباعة الباركود؛ يمكنك إعادة طباعته من المخزون.',
            );
          }
        }
      }
    } catch (_) {
      if (mounted) {
        _pendingError = 'تعذر إكمال التحقق من الشراء. أعد المحاولة بنفس الطلب.';
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<BarcodeLabelItem> _barcodeItemsFromPurchaseRequest(
    PendingPurchase request,
  ) => [
    for (final item in request.items)
      for (final product in widget.snapshot.products.where(
        (product) => product.id == item.productId,
      ))
        BarcodeLabelItem(
          productName: product.name,
          barcode: product.barcode,
          quantity: item.qty,
        ),
  ];

  Future<void> _promptBarcodePrinting(List<BarcodeLabelItem> items) async {
    final printable = BarcodeLabelsPdf.printableItems(items);
    if (printable.isEmpty && items.isEmpty) return;
    final labels = await showDialog<List<BarcodeLabelItem>>(
      context: context,
      builder: (_) => _BarcodePrintPromptDialog(items: items),
    );
    if (labels == null || labels.isEmpty || !mounted) return;
    await ref.read(barcodeLabelPrinterProvider)(
      labels,
      widget.snapshot.barcodeLabelSettings,
    );
  }

  void _markDirty() {
    if (_dirty) return;
    _dirty = true;
    widget.onDirtyChanged(true);
  }

  void _markClean() {
    if (!_dirty) return;
    _dirty = false;
    widget.onDirtyChanged(false);
  }

  void _restoreDraft(PurchaseDraft draft) {
    final products = {
      for (final product in widget.snapshot.products) product.id: product,
    };
    var skipped = 0;
    _cart.clear();
    for (final item in draft.items) {
      final product = products[item.productId];
      if (product == null) {
        skipped += 1;
        continue;
      }
      _cart.add(
        _PurchaseCartLine(
          product,
          quantity: item.qty,
          unitCostMinor: item.unitCostMinor,
        ),
      );
    }
    final supplierExists =
        draft.supplierId == null ||
        widget.snapshot.suppliers.any(
          (supplier) => supplier.id == draft.supplierId,
        );
    _supplierId = supplierExists ? draft.supplierId : null;
    _cash.text = draft.cashMinor == 0 ? '' : _minorToInputText(draft.cashMinor);
    _wallet.text = draft.walletMinor == 0
        ? ''
        : _minorToInputText(draft.walletMinor);
    _hasSavedDraft = true;
    _dirty = false;
    widget.onDirtyChanged(false);
    final warnings = <String>[
      if (skipped > 0) 'تعذر استعادة $skipped صنف محذوف.',
      if (!supplierExists) 'المورد المحفوظ لم يعد متاحًا.',
    ];
    _draftNotice = warnings.isEmpty
        ? 'تمت استعادة مسودة الشراء المحفوظة.'
        : 'تمت استعادة المسودة. ${warnings.join(' ')}';
  }

  Future<void> _saveDraft() async {
    if (_saving || _cart.isEmpty) return;
    final cash = _requireMoney(context, _cash, 'كاش');
    final wallet = _requireMoney(context, _wallet, 'محفظة');
    if (cash == null || wallet == null) return;
    final invalidCost = _firstPurchaseCostError(_cart);
    if (invalidCost != null) {
      _showSnack(context, invalidCost);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(useCasesProvider)
          .savePurchaseDraft(
            PurchaseDraft(
              supplierId: _supplierId,
              items: [
                for (final line in _cart)
                  PurchaseLineInput(
                    productId: line.product.id,
                    qty: line.qty,
                    unitCostMinor: line.costMinor,
                  ),
              ],
              cashMinor: cash,
              walletMinor: wallet,
              savedAt: ref.read(appClockProvider)(),
            ),
          );
      if (!mounted) return;
      _hasSavedDraft = true;
      _draftNotice = 'تم حفظ مسودة الشراء. لم تُسجل فاتورة أو حركة مالية.';
      _markClean();
      _showSnack(context, 'تم حفظ مسودة الشراء');
    } catch (_) {
      if (mounted) _showSnack(context, 'تعذر حفظ المسودة. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discardDraft() async {
    if (_saving || !_hasSavedDraft) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('مسح مسودة الشراء؟'),
        content: const Text(
          'ستُمسح المسودة الحالية فقط. لا توجد فاتورة أو حركة مالية مسجلة منها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('مسح المسودة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(useCasesProvider).discardPurchaseDraft();
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _supplierId = null;
        _cash.clear();
        _wallet.clear();
        _hasSavedDraft = false;
        _draftNotice = null;
      });
      _markClean();
      _showSnack(context, 'تم مسح مسودة الشراء');
    } catch (_) {
      if (mounted) _showSnack(context, 'تعذر مسح المسودة. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
