part of '../v2_app.dart';

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
