part of '../v2_app.dart';

class _QuickInstallmentDialog extends StatefulWidget {
  const _QuickInstallmentDialog({required this.party, required this.plans});

  final PartyBalance party;
  final List<InstallmentPlanPreview> plans;

  @override
  State<_QuickInstallmentDialog> createState() =>
      _QuickInstallmentDialogState();
}

class _QuickInstallmentDialogState extends State<_QuickInstallmentDialog> {
  late InstallmentPlanPreview _plan = widget.plans.first;
  late final _amount = TextEditingController(
    text: _minorToInputText(_plan.remainingMinor),
  );
  PaymentMethod _method = PaymentMethod.cash;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.party.type == 'customer' ? 'تحصيل سريع' : 'سداد سريع'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<InstallmentPlanPreview>(
              initialValue: _plan,
              decoration: const InputDecoration(labelText: 'خطة الأقساط'),
              items: [
                for (final plan in widget.plans)
                  DropdownMenuItem(
                    value: plan,
                    child: Text(
                      '${_date(plan.nextDueDate ?? plan.plan.createdAt)} · متبقي ${Money(plan.remainingMinor).format()}',
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _plan = value;
                  _amount.text = _minorToInputText(value.remainingMinor);
                });
              },
            ),
            const SizedBox(height: 10),
            _moneyField(_amount, 'القيمة'),
            const SizedBox(height: 10),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'طريقة الدفع'),
              items: const [
                DropdownMenuItem(value: PaymentMethod.cash, child: Text('كاش')),
                DropdownMenuItem(
                  value: PaymentMethod.wallet,
                  child: Text('محفظة'),
                ),
              ],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            final amount = _requireMoney(context, _amount, 'القيمة');
            if (amount == null) return;
            Navigator.pop(context, (
              plan: _plan,
              amount: amount,
              method: _method,
            ));
          },
          child: Text(widget.party.type == 'customer' ? 'تحصيل' : 'سداد'),
        ),
      ],
    );
  }
}

class _SaleReceiptDialog extends ConsumerStatefulWidget {
  const _SaleReceiptDialog({required this.receipt, this.currentStatus});
  final SaleReturnPreview? currentStatus;
  final SaleReceiptSnapshot receipt;

  @override
  ConsumerState<_SaleReceiptDialog> createState() => _SaleReceiptDialogState();
}

class _SaleReceiptDialogState extends ConsumerState<_SaleReceiptDialog> {
  bool _printing = false;
  String? _printError;

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    return AlertDialog(
      title: Text(
        '${receipt.shopSettings.shopName} · ${receipt.invoice.invoiceNo}',
      ),
      content: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (receipt.shopSettings.phone != null ||
                receipt.shopSettings.address != null) ...[
              _GlassPane(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (receipt.shopSettings.phone != null)
                      _InfoLine('هاتف المحل', receipt.shopSettings.phone!),
                    if (receipt.shopSettings.address != null)
                      _InfoLine('العنوان', receipt.shopSettings.address!),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: _ReceiptInfoBlock(
                    label: 'العميل',
                    value: receipt.customerName ?? 'نقدي',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ReceiptInfoBlock(
                    label: 'التاريخ',
                    value: _dateTime(receipt.invoice.createdAt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _GlassPane(
                padding: const EdgeInsets.all(12),
                child: receipt.lines.isEmpty
                    ? const Center(child: Text('لا توجد سطور في الفاتورة'))
                    : ListView.separated(
                        itemCount: receipt.lines.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final line = receipt.lines[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(line.productName),
                            subtitle: Text(
                              '${line.qty} × ${Money(line.unitPriceMinor).format()}',
                            ),
                            trailing: Text(Money(line.lineTotalMinor).format()),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (final payment in receipt.payments)
                        _InfoLine(
                          _paymentMethodText(payment.method),
                          Money(payment.amountMinor).format(),
                        ),
                      if (receipt.payments.isEmpty)
                        const _InfoLine('الدفع', 'بدون دفعة فورية'),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      _AmountRow('الإجمالي', receipt.invoice.subtotalMinor),
                      if (receipt.invoice.discountMinor > 0)
                        _AmountRow('الخصم', receipt.invoice.discountMinor),
                      if (receipt.invoice.interestMinor > 0)
                        _AmountRow('الفائدة', receipt.invoice.interestMinor),
                      _AmountRow('المطلوب', receipt.invoice.totalMinor),
                      _AmountRow('المدفوع', receipt.invoice.paidMinor),
                      _AmountRow(
                        'المتبقي',
                        receipt.invoice.remainingMinor,
                        strong: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.currentStatus case final status?) ...[
              const Divider(),
              _AmountRow(
                'تحصيل أقساط بعد البيع',
                status.collectedInstallmentsMinor,
              ),
              _AmountRow(
                'إجمالي المرتجع حتى الآن',
                status.lines.fold<int>(
                  0,
                  (sum, line) => sum + line.refundedMinor,
                ),
              ),
              if (status.remainingDebtMinor != null)
                _AmountRow(
                  'المديونية الحالية',
                  status.remainingDebtMinor!,
                  strong: true,
                ),
              const Text(
                'مبالغ الفاتورة المطبوعة تخص وقت البيع؛ التحصيل والمرتجعات موضحة هنا بشكل منفصل.',
              ),
            ],
            if (_printError != null)
              Text(
                _printError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (receipt.shopSettings.receiptFooter != null) ...[
              const SizedBox(height: 8),
              Text(
                receipt.shopSettings.receiptFooter!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _mutedInk),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _printing ? null : () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
        if (widget.currentStatus case final status?)
          TextButton(
            onPressed:
                _printing || !status.lines.any((line) => line.returnableQty > 0)
                ? null
                : () => Navigator.pop(context, true),
            child: const Text('إنشاء مرتجع'),
          ),
        FilledButton.icon(
          onPressed: _printing ? null : _print,
          icon: const Icon(Icons.print),
          label: Text(_printing ? 'جاري الطباعة...' : 'طباعة'),
        ),
      ],
    );
  }

  Future<void> _print() async {
    if (_printing) return;
    setState(() {
      _printing = true;
      _printError = null;
    });
    try {
      await ref.read(saleReceiptPrinterProvider)(widget.receipt);
    } catch (_) {
      if (mounted) {
        setState(
          () => _printError =
              'الفاتورة محفوظة، لكن تعذرت الطباعة. يمكنك إعادة المحاولة.',
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
}

class _ReceiptInfoBlock extends StatelessWidget {
  const _ReceiptInfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _mutedInk)),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _PartyDialog extends StatefulWidget {
  const _PartyDialog({required this.title});
  final String title;

  @override
  State<_PartyDialog> createState() => _PartyDialogState();
}

class _PartyDialogState extends State<_PartyDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'الهاتف'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _PartyFormData(_name.text, _phone.text)),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _PartyFormData {
  const _PartyFormData(this.name, this.phone);
  final String name;
  final String phone;
}

class _InstallmentPaymentDialog extends StatefulWidget {
  const _InstallmentPaymentDialog({
    required this.title,
    required this.initialMinor,
  });

  final String title;
  final int initialMinor;

  @override
  State<_InstallmentPaymentDialog> createState() =>
      _InstallmentPaymentDialogState();
}

class _InstallmentPaymentDialogState extends State<_InstallmentPaymentDialog> {
  late final _amount = TextEditingController(
    text: _minorToInputText(widget.initialMinor),
  );
  PaymentMethod _method = PaymentMethod.cash;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _moneyField(_amount, 'القيمة'),
            const SizedBox(height: 8),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'طريقة الدفع'),
              items: [
                const DropdownMenuItem(
                  value: PaymentMethod.cash,
                  child: Text('كاش'),
                ),
                DropdownMenuItem(
                  value: PaymentMethod.wallet,
                  child: Text('محفظة'),
                ),
              ],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            final amount = _requireMoney(context, _amount, 'القيمة');
            if (amount == null) return;
            Navigator.pop(context, (amount: amount, method: _method));
          },
          child: const Text('تسجيل'),
        ),
      ],
    );
  }
}

class _ReturnDialog extends StatefulWidget {
  const _ReturnDialog({required this.preview});
  final SaleReturnPreview preview;

  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  late final Map<int, int> _quantities = {
    for (final line in widget.preview.lines) line.saleItemId: 0,
  };
  PaymentMethod _method = PaymentMethod.cash;
  PaymentMethod? _overflowMethod;

  @override
  Widget build(BuildContext context) {
    final selected = _quantities.entries
        .where((entry) => entry.value > 0)
        .fold<int>(0, (sum, entry) => sum + entry.value);
    final refund = widget.preview.lines.fold<int>(
      0,
      (sum, line) =>
          sum + line.refundForQuantity(_quantities[line.saleItemId] ?? 0),
    );
    final debt = widget.preview.remainingDebtMinor ?? 0;
    final settlement = refund < debt ? refund : debt;
    final overflow = _method == PaymentMethod.installment
        ? refund - settlement
        : 0;
    return AlertDialog(
      title: const Text('إنشاء مرتجع'),
      content: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ReceiptInfoBlock(
                    label: 'الفاتورة',
                    value: widget.preview.receipt.invoice.invoiceNo,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ReceiptInfoBlock(
                    label: 'العميل',
                    value: widget.preview.receipt.customerName ?? 'نقدي',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _GlassPane(
                padding: const EdgeInsets.all(12),
                child: ListView.separated(
                  itemCount: widget.preview.lines.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final line = widget.preview.lines[index];
                    final qty = _quantities[line.saleItemId] ?? 0;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(line.productName),
                      subtitle: Text(
                        'مباع ${line.soldQty} · مرتجع سابق ${line.returnedQty} · متاح ${line.returnableQty}',
                      ),
                      trailing: _QtyStepper(
                        qty: qty,
                        minQty: 0,
                        maxQty: line.returnableQty,
                        onChanged: (value) => setState(
                          () => _quantities[line.saleItemId] = value,
                        ),
                        onRemove: () =>
                            setState(() => _quantities[line.saleItemId] = 0),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'طريقة الرد'),
              items: [
                const DropdownMenuItem(
                  value: PaymentMethod.cash,
                  child: Text('كاش'),
                ),
                const DropdownMenuItem(
                  value: PaymentMethod.wallet,
                  child: Text('محفظة'),
                ),
                if (widget.preview.remainingDebtMinor != null)
                  const DropdownMenuItem(
                    value: PaymentMethod.installment,
                    child: Text('خصم من العميل'),
                  ),
              ],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
            const SizedBox(height: 12),
            if (_method == PaymentMethod.installment)
              _AmountRow('خصم من المديونية', settlement),
            if (overflow > 0) ...[
              _AmountRow('فائض يُرد للعميل', overflow),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: _overflowMethod,
                decoration: const InputDecoration(
                  labelText: 'اختر طريقة رد الفائض',
                ),
                items: const [
                  DropdownMenuItem(
                    value: PaymentMethod.cash,
                    child: Text('رد الفائض كاش'),
                  ),
                  DropdownMenuItem(
                    value: PaymentMethod.wallet,
                    child: Text('رد الفائض بالمحفظة'),
                  ),
                ],
                onChanged: (value) => setState(() => _overflowMethod = value),
              ),
            ],
            _InfoLine('عدد القطع المختارة', selected.toString()),
            _AmountRow('قيمة المرتجع', refund, strong: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: selected == 0 || (overflow > 0 && _overflowMethod == null)
              ? null
              : () => Navigator.pop(context, (
                  quantities: Map<int, int>.fromEntries(
                    _quantities.entries.where((entry) => entry.value > 0),
                  ),
                  method: _method,
                  overflowMethod: _method == PaymentMethod.installment
                      ? _overflowMethod
                      : null,
                )),
          child: const Text('تسجيل'),
        ),
      ],
    );
  }
}

class _PurchaseReturnDialog extends ConsumerStatefulWidget {
  const _PurchaseReturnDialog();

  @override
  ConsumerState<_PurchaseReturnDialog> createState() =>
      _PurchaseReturnDialogState();
}

class _PurchaseReturnDialogState extends ConsumerState<_PurchaseReturnDialog> {
  final _search = TextEditingController();
  late Future<List<PurchaseInvoice>> _invoices;
  PurchaseReturnPreview? _preview;
  Map<int, int> _quantities = const {};
  PaymentMethod _method = PaymentMethod.cash;
  PaymentMethod? _overflowMethod;
  bool _loadingPreview = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _invoices = _fetchInvoices();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<PurchaseInvoice>> _fetchInvoices() => ref
      .read(useCasesProvider)
      .purchaseInvoiceHistory(query: _search.text, limit: 100);

  void _loadInvoices() {
    setState(() {
      _invoices = _fetchInvoices();
    });
  }

  Future<void> _selectPurchase(PurchaseInvoice invoice) async {
    if (_loadingPreview) return;
    setState(() => _loadingPreview = true);
    try {
      final preview = await ref
          .read(useCasesProvider)
          .purchaseReturnPreview(invoice.id);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _quantities = {
          for (final line in preview.lines) line.purchaseItemId: 0,
        };
        _method = PaymentMethod.cash;
        _overflowMethod = null;
      });
    } catch (_) {
      if (mounted) {
        _showSnack(context, 'تعذر تحميل فاتورة الشراء. أعد المحاولة.');
      }
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _submit() async {
    final preview = _preview;
    if (preview == null || _saving) return;
    final quantities = Map<int, int>.fromEntries(
      _quantities.entries.where((entry) => entry.value > 0),
    );
    if (quantities.isEmpty) return;
    setState(() => _saving = true);
    try {
      final useCases = ref.read(useCasesProvider);
      final request = PendingFinancialOperation.purchaseReturn(
        operationKey: useCases.newPurchaseReturnOperationKey(),
        purchaseId: preview.invoice.id,
        purchaseItemQuantities: quantities,
        settlementMethod: _method,
        overflowRefundMethod: _method == PaymentMethod.installment
            ? _overflowMethod
            : null,
      );
      final result = await _submitPendingFinancialOperation(
        useCases,
        request,
        allowNegativeBalance: false,
      );
      if (!mounted) return;
      if (result is AppSuccess<int>) {
        Navigator.pop(context, result);
      } else {
        _showResult(context, result, success: 'تم تسجيل مرتجع الشراء');
      }
    } catch (_) {
      if (mounted) {
        _showSnack(context, 'تعذر حفظ مرتجع الشراء. أعد المحاولة للتحقق.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    if (preview == null) return _buildPurchaseLookup();
    return _buildReturnForm(preview);
  }

  Widget _buildPurchaseLookup() {
    return AlertDialog(
      title: const Text('اختيار فاتورة شراء للمرتجع'),
      content: SizedBox(
        width: 720,
        height: 520,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      labelText: 'رقم فاتورة الشراء أو اسم المورد أو هاتفه',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _loadInvoices(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _loadingPreview ? null : _loadInvoices,
                  child: const Text('بحث'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<PurchaseInvoice>>(
                future: _invoices,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done ||
                      _loadingPreview) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: _loadInvoices,
                        child: const Text(
                          'تعذر تحميل الفواتير. إعادة المحاولة',
                        ),
                      ),
                    );
                  }
                  final invoices = snapshot.data ?? const <PurchaseInvoice>[];
                  if (invoices.isEmpty) {
                    return const Center(
                      child: Text('لا توجد فواتير شراء مطابقة'),
                    );
                  }
                  return ListView.separated(
                    itemCount: invoices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final invoice = invoices[index];
                      return ListTile(
                        leading: const Icon(Icons.local_shipping_outlined),
                        title: Text(invoice.invoiceNo),
                        subtitle: Text(
                          '${_dateTime(invoice.createdAt)} · إجمالي ${Money(invoice.totalMinor).format()}',
                        ),
                        trailing: TextButton(
                          onPressed: () => _selectPurchase(invoice),
                          child: const Text('اختيار'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loadingPreview ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }

  Widget _buildReturnForm(PurchaseReturnPreview preview) {
    final selected = _quantities.values.fold<int>(0, (sum, qty) => sum + qty);
    final credit = preview.lines.fold<int>(
      0,
      (sum, line) =>
          sum + line.creditForQuantity(_quantities[line.purchaseItemId] ?? 0),
    );
    final debt = preview.remainingDebtMinor ?? 0;
    final debtSettlement = _method == PaymentMethod.installment
        ? math.min(credit, debt)
        : 0;
    final overflow = _method == PaymentMethod.installment
        ? credit - debtSettlement
        : 0;
    final needsOverflowMethod = overflow > 0;
    return AlertDialog(
      title: Text('مرتجع شراء ${preview.invoice.invoiceNo}'),
      content: SizedBox(
        width: 720,
        height: 580,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ReceiptInfoBlock(
                    label: 'المورد',
                    value: preview.supplierName ?? 'بدون مورد',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ReceiptInfoBlock(
                    label: 'تاريخ الفاتورة',
                    value: _dateTime(preview.invoice.createdAt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _GlassPane(
                padding: const EdgeInsets.all(12),
                child: ListView.separated(
                  itemCount: preview.lines.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final line = preview.lines[index];
                    final qty = _quantities[line.purchaseItemId] ?? 0;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(line.productName),
                      subtitle: Text(
                        'شراء ${line.purchasedQty} · مرتجع سابق ${line.returnedQty} · متاح ${line.returnableQty} · بالمخزون ${line.availableStockQty}',
                      ),
                      trailing: _QtyStepper(
                        qty: qty,
                        minQty: 0,
                        maxQty: line.availableStockQty,
                        onChanged: (value) => setState(
                          () => _quantities = {
                            ..._quantities,
                            line.purchaseItemId: value,
                          },
                        ),
                        onRemove: () => setState(
                          () => _quantities = {
                            ..._quantities,
                            line.purchaseItemId: 0,
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(
                labelText: 'تسوية مرتجع المورد',
              ),
              items: [
                const DropdownMenuItem(
                  value: PaymentMethod.cash,
                  child: Text('استلام كاش'),
                ),
                const DropdownMenuItem(
                  value: PaymentMethod.wallet,
                  child: Text('استلام بالمحفظة'),
                ),
                if (preview.remainingDebtMinor != null)
                  const DropdownMenuItem(
                    value: PaymentMethod.installment,
                    child: Text('خصم من مديونية المورد'),
                  ),
              ],
              onChanged: (value) => setState(() {
                _method = value ?? _method;
                _overflowMethod = null;
              }),
            ),
            if (_method == PaymentMethod.installment)
              _AmountRow('خصم من مديونية المورد', debtSettlement),
            if (needsOverflowMethod) ...[
              _AmountRow('فائض مستحق من المورد', overflow),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: _overflowMethod,
                decoration: const InputDecoration(
                  labelText: 'استلام فائض المورد',
                ),
                items: const [
                  DropdownMenuItem(
                    value: PaymentMethod.cash,
                    child: Text('استلام الفائض كاش'),
                  ),
                  DropdownMenuItem(
                    value: PaymentMethod.wallet,
                    child: Text('استلام الفائض بالمحفظة'),
                  ),
                ],
                onChanged: (value) => setState(() => _overflowMethod = value),
              ),
            ],
            _InfoLine('عدد القطع المختارة', selected.toString()),
            _AmountRow('قيمة ائتمان المورد', credit, strong: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _saving
              ? null
              : () => setState(() {
                  _preview = null;
                  _quantities = const {};
                  _overflowMethod = null;
                }),
          child: const Text('تغيير الفاتورة'),
        ),
        FilledButton(
          onPressed:
              _saving ||
                  selected == 0 ||
                  (needsOverflowMethod && _overflowMethod == null)
              ? null
              : _submit,
          child: Text(_saving ? 'جاري الحفظ...' : 'تسجيل مرتجع الشراء'),
        ),
      ],
    );
  }
}
