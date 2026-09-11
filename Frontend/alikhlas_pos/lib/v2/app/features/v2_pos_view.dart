part of '../v2_app.dart';

class _PosView extends ConsumerStatefulWidget {
  const _PosView({required this.snapshot, required this.onDirtyChanged});
  final WorkbenchSnapshot snapshot;
  final ValueChanged<bool> onDirtyChanged;

  @override
  ConsumerState<_PosView> createState() => _PosViewState();
}

class _PosViewState extends ConsumerState<_PosView> {
  final _search = TextEditingController();
  final _cash = TextEditingController();
  final _wallet = TextEditingController();
  final _discount = TextEditingController();
  final _installmentCount = TextEditingController(text: '3');
  final _customPeriodDays = TextEditingController(text: '30');
  final _interest = TextEditingController();
  final _cart = <_CartLine>[];
  late DateTime _firstDueDate = ref
      .read(appClockProvider)()
      .add(const Duration(days: 30));
  int _periodDays = 30;
  int? _customerId;
  bool _saving = false;
  PendingSale? _pendingSale;
  bool _loadingPending = true;
  bool _pendingLoadFailed = false;
  String? _pendingError;
  bool _dirty = false;
  bool _hasSavedDraft = false;
  String? _draftNotice;

  @override
  void initState() {
    super.initState();
    _loadPendingSale();
  }

  Future<void> _loadPendingSale() async {
    setState(() => _loadingPending = true);
    try {
      final useCases = ref.read(useCasesProvider);
      final request = await useCases.pendingSale();
      SaleDraft? draft;
      var draftUnreadable = false;
      if (request == null) {
        try {
          draft = await useCases.saleDraft();
        } catch (_) {
          draftUnreadable = true;
        }
      }
      if (!mounted) return;
      _pendingSale = request;
      if (draft != null) _restoreDraft(draft);
      if (draftUnreadable) {
        _hasSavedDraft = true;
        _draftNotice =
            'تعذر قراءة مسودة البيع. لم تُسجل منها حركة مالية؛ يمكنك مسحها وبدء فاتورة جديدة.';
      }
      _pendingLoadFailed = false;
    } catch (_) {
      if (mounted) _pendingLoadFailed = true;
    } finally {
      if (mounted) setState(() => _loadingPending = false);
    }
  }

  Future<void> _discardPendingSale() async {
    if (_saving || _pendingSale == null) return;
    setState(() => _saving = true);
    try {
      final removed = await ref
          .read(useCasesProvider)
          .restoreUncommittedPendingSaleAsDraft(_pendingSale!.operationKey);
      if (!mounted) return;
      if (removed) {
        _pendingSale = null;
        _pendingError = null;
        final draft = await ref.read(useCasesProvider).saleDraft();
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
    _discount.dispose();
    _installmentCount.dispose();
    _customPeriodDays.dispose();
    _interest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPending) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pendingLoadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تعذر قراءة طلب البيع السابق. لن يُبدأ بيع جديد حتى يتم التحقق.',
            ),
            TextButton(
              onPressed: _loadPendingSale,
              child: const Text('إعادة محاولة قراءة الطلب'),
            ),
          ],
        ),
      );
    }
    if (_pendingSale != null) {
      return _Screen(
        title: 'البيع',
        subtitle: 'التحقق من نتيجة الحفظ',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'يوجد طلب بيع يحتاج استكمال التحقق. إعادة المحاولة تستخدم نفس الطلب.',
              ),
              const SizedBox(height: 12),
              Text('عدد الأصناف: ${_pendingSale!.items.length}'),
              if (_pendingError != null) Text(_pendingError!),
              FilledButton(
                onPressed: _saving ? null : _savePendingSale,
                child: Text(
                  _saving ? 'جاري التحقق...' : 'التحقق وإعادة المحاولة',
                ),
              ),
              TextButton(
                onPressed: _saving ? null : _discardPendingSale,
                child: const Text('العودة لتعديل المسودة'),
              ),
            ],
          ),
        ),
      );
    }
    final products = widget.snapshot.products
        .where((product) => product.isActive)
        .where((product) {
          final q = _search.text.trim();
          return q.isEmpty ||
              product.name.contains(q) ||
              (product.barcode?.contains(q) ?? false);
        })
        .toList();
    final total = _cart.fold<int>(
      0,
      (sum, line) => sum + line.qty * line.unitPriceMinor,
    );
    final discount = _parseMoney(_discount.text);
    final cash = _parseMoney(_cash.text);
    final wallet = _parseMoney(_wallet.text);
    final paid = cash + wallet;
    final netTotal = (total - discount).clamp(0, total);
    final remaining = netTotal - paid;
    final installmentCount =
        int.tryParse(normalizeArabicDigits(_installmentCount.text.trim())) ?? 0;
    final installmentTotal = remaining + _parseMoney(_interest.text);
    final previewInstallment =
        remaining > 0 && installmentCount > 0 && installmentTotal > 0
        ? allocateRemainderToLast(installmentTotal, installmentCount, 0)
        : 0;
    final moneyError = _firstMoneyInputError({
      'كاش': _cash,
      'محفظة': _wallet,
      'خصم الفاتورة': _discount,
      'فائدة اختيارية': _interest,
    });

    return AbsorbPointer(
      absorbing: _saving,
      child: _Screen(
        title: 'البيع',
        subtitle: 'سلة بيع كاملة مع دفع كاش/محفظة/تقسيط',
        child: Row(
          children: [
            Expanded(
              child: _GlassPane(
                child: Column(
                  children: [
                    TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'بحث أو باركود',
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _addBarcodeMatch(products),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return ListTile(
                            leading: _ProductAvatar(product: product),
                            title: Text(product.name),
                            subtitle: Text('الرصيد ${product.stockQty}'),
                            trailing: Text(
                              Money(product.salePriceMinor).format(),
                            ),
                            onTap: product.stockQty > 0
                                ? () {
                                    _markDirty();
                                    setState(() => _addToCart(product));
                                  }
                                : null,
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
                    Text(
                      'سلة البيع',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _CartList(
                        cart: _cart,
                        onChanged: () {
                          _markDirty();
                          setState(() {});
                        },
                      ),
                    ),
                    const Divider(),
                    DropdownButtonFormField<int?>(
                      initialValue: _customerId,
                      decoration: const InputDecoration(
                        labelText: 'العميل للتقسيط',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('بدون عميل'),
                        ),
                        for (final customer in widget.snapshot.customers)
                          DropdownMenuItem<int?>(
                            value: customer.id,
                            child: Text(customer.name),
                          ),
                      ],
                      onChanged: (value) {
                        _markDirty();
                        setState(() => _customerId = value);
                      },
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
                    _moneyField(
                      _discount,
                      'خصم الفاتورة',
                      onChanged: (_) {
                        _markDirty();
                        setState(() {});
                      },
                    ),
                    if (remaining > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _installmentCount,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'عدد الأقساط',
                              ),
                              onChanged: (_) {
                                _markDirty();
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _moneyField(
                              _interest,
                              'فائدة اختيارية',
                              onChanged: (_) {
                                _markDirty();
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _InstallmentScheduleEditor(
                        firstDueDate: _firstDueDate,
                        periodDays: _periodDays,
                        customPeriodController: _customPeriodDays,
                        installmentCount: installmentCount,
                        previewInstallmentMinor: previewInstallment,
                        onPickDate: _pickFirstDueDate,
                        onPeriodChanged: (value) {
                          _markDirty();
                          setState(() => _periodDays = value);
                        },
                        onCustomPeriodChanged: (_) {
                          _markDirty();
                          setState(() {});
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    _AmountRow('الإجمالي قبل الخصم', total),
                    _AmountRow('الخصم', discount),
                    _AmountRow('المطلوب', netTotal, strong: true),
                    _AmountRow('المدفوع', paid),
                    _AmountRow('المتبقي', remaining < 0 ? 0 : remaining),
                    if (moneyError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        moneyError,
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
                                : () => _submitSale(total),
                            icon: const Icon(Icons.check_circle),
                            label: Text(
                              _saving ? 'جاري الحفظ...' : 'تسجيل البيع',
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
    _CartLine? existing;
    for (final line in _cart) {
      if (line.product.id == product.id) {
        existing = line;
        break;
      }
    }
    if (existing == null) {
      _cart.add(_CartLine(product));
    } else if (existing.qty < product.stockQty) {
      existing.qty++;
    }
  }

  void _addBarcodeMatch(List<Product> products) {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    Product? match;
    for (final product in products) {
      if (product.barcode == query) {
        match = product;
        break;
      }
    }
    if (match == null) return;
    _markDirty();
    setState(() {
      _addToCart(match!);
      _search.clear();
    });
  }

  Future<void> _submitSale(int total) async {
    if (_saving ||
        _pendingSale != null ||
        _loadingPending ||
        _pendingLoadFailed) {
      return;
    }
    final cash = _requireMoney(context, _cash, 'كاش');
    final wallet = _requireMoney(context, _wallet, 'محفظة');
    final discount = _requireMoney(context, _discount, 'خصم الفاتورة');
    final interest = _requireMoney(context, _interest, 'فائدة اختيارية');
    if (cash == null ||
        wallet == null ||
        discount == null ||
        interest == null) {
      return;
    }
    final paid = cash + wallet;
    if (discount < 0) {
      _showSnack(context, 'الخصم لا يمكن أن يكون سالبًا');
      return;
    }
    if (discount >= total) {
      _showSnack(context, 'الخصم يجب أن يكون أقل من إجمالي الفاتورة');
      return;
    }
    final netTotal = total - discount;
    if (paid > netTotal) {
      _showSnack(context, 'المدفوع أكبر من إجمالي الفاتورة بعد الخصم');
      return;
    }
    if (cash > 0 && widget.snapshot.dashboard.openShift == null) {
      _showSnack(context, 'افتح وردية قبل البيع النقدي');
      return;
    }
    final remaining = netTotal - paid;
    if (remaining > 0 && _customerId == null) {
      _showSnack(context, 'اختر عميلًا للبيع بالتقسيط');
      return;
    }
    final installmentCount =
        int.tryParse(normalizeArabicDigits(_installmentCount.text.trim())) ?? 0;
    final periodDays = _effectiveInstallmentPeriodDays();
    if (remaining > 0 && installmentCount <= 0) {
      _showSnack(context, 'عدد الأقساط يجب أن يكون أكبر من صفر');
      return;
    }
    if (remaining > 0 && periodDays <= 0) {
      _showSnack(context, 'فترة الأقساط يجب أن تكون أكبر من صفر يوم');
      return;
    }
    final terms = remaining > 0 && _customerId != null
        ? InstallmentTerms(
            partyId: _customerId!,
            count: installmentCount,
            firstDueDate: _firstDueDate,
            interestMinor: interest,
            periodDays: periodDays,
          )
        : null;
    final operationKey = ref.read(useCasesProvider).newSaleOperationKey();
    final customerId = _customerId;
    final items = [
      for (final line in _cart)
        SaleLineInput(
          productId: line.product.id,
          qty: line.qty,
          unitPriceMinor: line.unitPriceMinor,
        ),
    ];
    final payments = [
      PaymentInput(PaymentMethod.cash, cash),
      PaymentInput(PaymentMethod.wallet, wallet),
    ];
    _pendingSale = PendingSale(
      operationKey: operationKey,
      customerId: customerId,
      items: items,
      payments: payments,
      installmentTerms: terms,
      discountMinor: discount,
    );
    await _savePendingSale();
  }

  Future<void> _savePendingSale() async {
    if (_saving || _pendingSale == null) return;
    setState(() => _saving = true);
    try {
      final useCases = ref.read(useCasesProvider);
      final requestedKey = _pendingSale!.operationKey;
      final request = await useCases.stagePendingSale(_pendingSale!);
      if (!mounted) return;
      _pendingSale = request;
      if (request.operationKey != requestedKey) {
        _pendingError =
            'يوجد طلب سابق لم تُحسم نتيجته. راجعه قبل تسجيل بيع جديد.';
        return;
      }
      _hasSavedDraft = false;
      _draftNotice = null;
      _markClean();
      final result = await ref.read(saleWriterProvider)(
        operationKey: request.operationKey,
        customerId: request.customerId,
        items: request.items,
        payments: request.payments,
        installmentTerms: request.installmentTerms,
        discountMinor: request.discountMinor,
      );
      if (!mounted) return;
      if (result is AppFailure<int>) {
        _pendingError = result.message;
      }
      if (result is AppSuccess<int>) {
        // Clear the saved draft before any fallible receipt loading/printing.
        setState(() {
          _cart.clear();
          _cash.clear();
          _wallet.clear();
          _discount.clear();
          _interest.clear();
          _hasSavedDraft = false;
          _draftNotice = null;
        });
        _markClean();
        final acknowledged = await useCases.acknowledgePendingSale(
          request.operationKey,
        );
        if (!mounted) return;
        if (!acknowledged) {
          throw StateError('Pending sale acknowledgement failed');
        }
        _pendingSale = null;
        _pendingError = null;
        _refresh(ref);
        try {
          final receipt = await ref.read(saleReceiptLoaderProvider)(
            result.value,
          );
          if (!mounted) return;
          _showSnack(context, 'تم تسجيل البيع');
          await showDialog<void>(
            context: context,
            builder: (_) => _SaleReceiptDialog(receipt: receipt),
          );
        } catch (_) {
          if (mounted) {
            _showSnack(
              context,
              'تم حفظ البيع. تعذر عرض الفاتورة؛ افتحها من سجل المرتجعات لإعادة الطباعة.',
            );
          }
        }
      }
    } catch (_) {
      if (mounted) {
        _pendingError = 'تعذر إكمال التحقق. أعد المحاولة بنفس الطلب.';
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _effectiveInstallmentPeriodDays() {
    if (_periodDays > 0) return _periodDays;
    return int.tryParse(normalizeArabicDigits(_customPeriodDays.text.trim())) ??
        0;
  }

  Future<void> _pickFirstDueDate() async {
    final today = ref.read(appClockProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDueDate.isBefore(today) ? today : _firstDueDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 3650)),
    );
    if (picked == null || !mounted) return;
    _markDirty();
    setState(() => _firstDueDate = picked);
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

  void _restoreDraft(SaleDraft draft) {
    final products = {
      for (final product in widget.snapshot.products) product.id: product,
    };
    var skipped = 0;
    var changedPrice = false;
    _cart.clear();
    for (final item in draft.items) {
      final product = products[item.productId];
      if (product == null || !product.isActive) {
        skipped += 1;
        continue;
      }
      if (product.salePriceMinor != item.unitPriceMinor) changedPrice = true;
      _cart.add(
        _CartLine(product, unitPriceMinor: item.unitPriceMinor)..qty = item.qty,
      );
    }
    final customerExists =
        draft.customerId == null ||
        widget.snapshot.customers.any(
          (customer) => customer.id == draft.customerId,
        );
    _customerId = customerExists ? draft.customerId : null;
    _cash.text = draft.cashMinor == 0 ? '' : _minorToInputText(draft.cashMinor);
    _wallet.text = draft.walletMinor == 0
        ? ''
        : _minorToInputText(draft.walletMinor);
    _discount.text = draft.discountMinor == 0
        ? ''
        : _minorToInputText(draft.discountMinor);
    _interest.text = draft.interestMinor == 0
        ? ''
        : _minorToInputText(draft.interestMinor);
    _installmentCount.text = draft.installmentCount.toString();
    _firstDueDate = draft.firstDueDate;
    if (const [7, 15, 30].contains(draft.periodDays)) {
      _periodDays = draft.periodDays;
      _customPeriodDays.text = draft.periodDays.toString();
    } else {
      _periodDays = -1;
      _customPeriodDays.text = draft.periodDays.toString();
    }
    _hasSavedDraft = true;
    _dirty = false;
    widget.onDirtyChanged(false);
    final warnings = <String>[
      if (skipped > 0) 'تعذر استعادة $skipped صنف محذوف أو موقوف.',
      if (!customerExists) 'العميل المحفوظ لم يعد متاحًا.',
      if (changedPrice)
        'تغير سعر صنف بعد الحفظ؛ احتفظنا بسعر المسودة للمراجعة.',
    ];
    _draftNotice = warnings.isEmpty
        ? 'تمت استعادة مسودة البيع المحفوظة.'
        : 'تمت استعادة المسودة. ${warnings.join(' ')}';
  }

  Future<void> _saveDraft() async {
    if (_saving || _cart.isEmpty) return;
    final cash = _requireMoney(context, _cash, 'كاش');
    final wallet = _requireMoney(context, _wallet, 'محفظة');
    final discount = _requireMoney(context, _discount, 'خصم الفاتورة');
    final interest = _requireMoney(context, _interest, 'فائدة اختيارية');
    if (cash == null ||
        wallet == null ||
        discount == null ||
        interest == null) {
      return;
    }
    var installmentCount =
        int.tryParse(normalizeArabicDigits(_installmentCount.text.trim())) ?? 0;
    var periodDays = _effectiveInstallmentPeriodDays();
    final total = _cart.fold<int>(
      0,
      (sum, line) => sum + line.qty * line.unitPriceMinor,
    );
    final needsInstallments = total - discount - cash - wallet > 0;
    if (needsInstallments && (installmentCount <= 0 || periodDays <= 0)) {
      _showSnack(context, 'راجع عدد الأقساط والفترة قبل حفظ المسودة');
      return;
    }
    if (installmentCount <= 0) installmentCount = 1;
    if (periodDays <= 0) periodDays = 30;
    setState(() => _saving = true);
    try {
      await ref
          .read(useCasesProvider)
          .saveSaleDraft(
            SaleDraft(
              customerId: _customerId,
              items: [
                for (final line in _cart)
                  SaleLineInput(
                    productId: line.product.id,
                    qty: line.qty,
                    unitPriceMinor: line.unitPriceMinor,
                  ),
              ],
              cashMinor: cash,
              walletMinor: wallet,
              discountMinor: discount,
              interestMinor: interest,
              installmentCount: installmentCount,
              firstDueDate: _firstDueDate,
              periodDays: periodDays,
              savedAt: ref.read(appClockProvider)(),
            ),
          );
      if (!mounted) return;
      _hasSavedDraft = true;
      _draftNotice = 'تم حفظ مسودة البيع. لم تُسجل فاتورة أو حركة مالية.';
      _markClean();
      _showSnack(context, 'تم حفظ مسودة البيع');
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
        title: const Text('مسح مسودة البيع؟'),
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
      await ref.read(useCasesProvider).discardSaleDraft();
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _customerId = null;
        _cash.clear();
        _wallet.clear();
        _discount.clear();
        _interest.clear();
        _installmentCount.text = '3';
        _periodDays = 30;
        _customPeriodDays.text = '30';
        _firstDueDate = ref
            .read(appClockProvider)()
            .add(const Duration(days: 30));
        _hasSavedDraft = false;
        _draftNotice = null;
      });
      _markClean();
      _showSnack(context, 'تم مسح مسودة البيع');
    } catch (_) {
      if (mounted) _showSnack(context, 'تعذر مسح المسودة. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _InstallmentScheduleEditor extends StatelessWidget {
  const _InstallmentScheduleEditor({
    required this.firstDueDate,
    required this.periodDays,
    required this.customPeriodController,
    required this.installmentCount,
    required this.previewInstallmentMinor,
    required this.onPickDate,
    required this.onPeriodChanged,
    required this.onCustomPeriodChanged,
  });

  final DateTime firstDueDate;
  final int periodDays;
  final TextEditingController customPeriodController;
  final int installmentCount;
  final int previewInstallmentMinor;
  final VoidCallback onPickDate;
  final ValueChanged<int> onPeriodChanged;
  final ValueChanged<String> onCustomPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(V2DesignTokens.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickDate,
                    icon: const Icon(Icons.event),
                    label: Text('أول قسط ${_date(firstDueDate)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: periodDays,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الفترة'),
                    items: const [
                      DropdownMenuItem(value: 30, child: Text('شهري')),
                      DropdownMenuItem(value: 15, child: Text('نصف شهري')),
                      DropdownMenuItem(value: 7, child: Text('أسبوعي')),
                      DropdownMenuItem(value: -1, child: Text('مخصص')),
                    ],
                    onChanged: (value) => onPeriodChanged(value ?? 30),
                  ),
                ),
              ],
            ),
            if (periodDays == -1) ...[
              const SizedBox(height: 8),
              TextField(
                controller: customPeriodController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'عدد الأيام بين كل قسط',
                ),
                onChanged: onCustomPeriodChanged,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              installmentCount <= 0
                  ? 'أدخل عدد الأقساط لعرض المعاينة'
                  : 'معاينة: $installmentCount أقساط · أول قسط ${Money(previewInstallmentMinor).format()}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: V2DesignTokens.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
