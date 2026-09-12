part of '../v2_app.dart';

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
