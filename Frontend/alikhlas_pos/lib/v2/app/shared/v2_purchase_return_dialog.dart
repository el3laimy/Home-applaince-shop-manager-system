part of '../v2_app.dart';

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
