part of '../v2_app.dart';

class _PosView extends ConsumerStatefulWidget {
  const _PosView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

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
  DateTime _firstDueDate = DateTime.now().add(const Duration(days: 30));
  int _periodDays = 30;
  int? _customerId;

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
      (sum, line) => sum + line.qty * line.product.salePriceMinor,
    );
    final discount = _parseMoney(_discount.text);
    final cash = _parseMoney(_cash.text);
    final wallet = _parseMoney(_wallet.text);
    final paid = cash + wallet;
    final netTotal = (total - discount).clamp(0, total);
    final remaining = netTotal - paid;
    final installmentCount = int.tryParse(_installmentCount.text) ?? 0;
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

    return _Screen(
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
                              ? () => setState(() => _addToCart(product))
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
                      onChanged: () => setState(() {}),
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
                    onChanged: (value) => setState(() => _customerId = value),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
                  _moneyField(
                    _discount,
                    'خصم الفاتورة',
                    onChanged: (_) => setState(() {}),
                  ),
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
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _moneyField(
                          _interest,
                          'فائدة اختيارية',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  if (remaining > 0) ...[
                    const SizedBox(height: 8),
                    _InstallmentScheduleEditor(
                      firstDueDate: _firstDueDate,
                      periodDays: _periodDays,
                      customPeriodController: _customPeriodDays,
                      installmentCount: installmentCount,
                      previewInstallmentMinor: previewInstallment,
                      onPickDate: _pickFirstDueDate,
                      onPeriodChanged: (value) =>
                          setState(() => _periodDays = value),
                      onCustomPeriodChanged: (_) => setState(() {}),
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
                  FilledButton.icon(
                    onPressed: _cart.isEmpty ? null : () => _submitSale(total),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('تسجيل البيع'),
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
    setState(() {
      _addToCart(match!);
      _search.clear();
    });
  }

  Future<void> _submitSale(int total) async {
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
    final installmentCount = int.tryParse(_installmentCount.text) ?? 0;
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
    final result = await ref
        .read(useCasesProvider)
        .createSale(
          customerId: _customerId,
          items: [
            for (final line in _cart)
              SaleLineInput(
                productId: line.product.id,
                qty: line.qty,
                unitPriceMinor: line.product.salePriceMinor,
              ),
          ],
          payments: [
            PaymentInput(PaymentMethod.cash, cash),
            PaymentInput(PaymentMethod.wallet, wallet),
          ],
          installmentTerms: terms,
          discountMinor: discount,
        );
    if (!mounted) return;
    _showResult(context, result, success: 'تم تسجيل البيع');
    if (result is AppSuccess<int>) {
      final receipt = await ref
          .read(useCasesProvider)
          .saleReceipt(result.value);
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _cash.clear();
        _wallet.clear();
        _discount.clear();
        _interest.clear();
      });
      _refresh(ref);
      await showDialog<void>(
        context: context,
        builder: (_) => _SaleReceiptDialog(receipt: receipt),
      );
    }
  }

  int _effectiveInstallmentPeriodDays() {
    if (_periodDays > 0) return _periodDays;
    return int.tryParse(_customPeriodDays.text) ?? 0;
  }

  Future<void> _pickFirstDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null || !mounted) return;
    setState(() => _firstDueDate = picked);
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
