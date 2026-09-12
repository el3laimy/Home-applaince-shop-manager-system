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
