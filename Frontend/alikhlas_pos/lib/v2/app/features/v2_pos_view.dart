part of '../v2_app.dart';

class _PosView extends ConsumerStatefulWidget {
  const _PosView({required this.snapshot, required this.onDirtyChanged});
  final WorkbenchSnapshot snapshot;
  final ValueChanged<bool> onDirtyChanged;

  @override
  ConsumerState<_PosView> createState() => _PosViewState();
}

class _PosViewState extends ConsumerState<_PosView> with _PosViewActions {
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
