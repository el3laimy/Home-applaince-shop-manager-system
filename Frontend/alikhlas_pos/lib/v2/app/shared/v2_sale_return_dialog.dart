part of '../v2_app.dart';

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
