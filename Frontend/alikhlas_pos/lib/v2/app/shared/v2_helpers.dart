part of '../v2_app.dart';

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.amountMinor, {this.strong = false});
  final String label;
  final int amountMinor;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(Money(amountMinor).format(), style: style),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(color: _mutedInk)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

const _mutedInk = V2DesignTokens.inkMuted;

TextField _moneyField(
  TextEditingController controller,
  String label, {
  ValueChanged<String>? onChanged,
}) {
  return TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    onChanged: onChanged,
  );
}

int _parseMoney(String value) {
  return parseMoneyInput(value).minorUnits;
}

int? _requireMoney(
  BuildContext context,
  TextEditingController controller,
  String label, {
  bool allowNegative = false,
}) {
  final parsed = parseMoneyInput(controller.text, allowNegative: allowNegative);
  if (parsed.isValid) return parsed.minorUnits;
  _showSnack(context, '$label: ${parsed.errorMessage}');
  return null;
}

String? _moneyInputError(String label, String value) {
  final parsed = parseMoneyInput(value);
  if (parsed.isValid) return null;
  return '$label: ${parsed.errorMessage}';
}

String? _firstMoneyInputError(Map<String, TextEditingController> inputs) {
  for (final entry in inputs.entries) {
    final error = _moneyInputError(entry.key, entry.value.text);
    if (error != null) return error;
  }
  return null;
}

String? _firstPurchaseCostError(List<_PurchaseCartLine> cart) {
  for (final line in cart) {
    final error = _purchaseCostInputError(line);
    if (error != null) return error;
  }
  return null;
}

String? _purchaseCostInputError(_PurchaseCartLine line) {
  final parsed = parseMoneyInput(line.costInput);
  if (!parsed.isValid) {
    return 'تكلفة ${line.product.name}: ${parsed.errorMessage}';
  }
  if (parsed.minorUnits <= 0) return 'أدخل سعر شراء صحيح للصنف';
  return null;
}

String _minorToInputText(int minorUnits) {
  final negative = minorUnits < 0;
  final absolute = minorUnits.abs();
  final pounds = absolute ~/ 100;
  final cents = (absolute % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$pounds.$cents';
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _dateTime(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${_time(value)}';

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _fileName(String path) => File(path).uri.pathSegments.last;

Future<void> _openSaleReceipt(
  BuildContext context,
  WidgetRef ref,
  int saleId,
) async {
  final receipt = await ref.read(useCasesProvider).saleReceipt(saleId);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _SaleReceiptDialog(receipt: receipt),
  );
}

String _paymentMethodText(PaymentMethod method) {
  return switch (method) {
    PaymentMethod.cash => 'كاش',
    PaymentMethod.wallet => 'محفظة',
    PaymentMethod.installment => 'تقسيط',
  };
}

void _refresh(WidgetRef ref) {
  ref.invalidate(workbenchProvider);
  ref.invalidate(dashboardProvider);
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void _showResult<T>(
  BuildContext context,
  AppResult<T> result, {
  required String success,
}) {
  switch (result) {
    case AppSuccess<T>():
      _showSnack(context, success);
    case AppFailure<T>(message: final message):
      _showSnack(context, message);
  }
}

Future<AppResult<int>> _runWithNegativeBalanceApproval(
  BuildContext context, {
  required Future<AppResult<int>> Function(bool allowNegativeBalance) action,
}) async {
  final firstResult = await action(false);
  if (!context.mounted) return firstResult;
  if (firstResult case AppConfirmationRequired<int>(
    code: 'negative_liquid_balance',
    payload: final NegativeBalanceConfirmation confirmation,
  )) {
    final confirmed = await _confirmNegativeBalance(context, confirmation);
    if (!confirmed || !context.mounted) return firstResult;
    return action(true);
  }
  return firstResult;
}

Future<bool> _confirmNegativeBalance(
  BuildContext context,
  NegativeBalanceConfirmation confirmation,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('الرصيد سيصبح سالبًا'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'هذه العملية ستجعل رصيد الخزينة أو المحفظة أقل من صفر. راجع الأرقام قبل الموافقة.',
                ),
                const SizedBox(height: 12),
                for (final impact in confirmation.impacts)
                  _NegativeBalanceImpactTile(impact: impact),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.warning_amber),
              label: const Text('أوافق على الرصيد السالب'),
            ),
          ],
        ),
      ) ??
      false;
}

class _NegativeBalanceImpactTile extends StatelessWidget {
  const _NegativeBalanceImpactTile({required this.impact});

  final NegativeBalanceImpact impact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(V2DesignTokens.radiusMd),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(impact.label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            _InfoLine('الرصيد الحالي', Money(impact.currentMinor).format()),
            _InfoLine('قيمة الحركة', Money(impact.deltaMinor).format()),
            _InfoLine('الرصيد بعد العملية', Money(impact.newMinor).format()),
          ],
        ),
      ),
    );
  }
}

Future<int?> _askMoney(
  BuildContext context, {
  required String title,
  int? initialMinor,
}) {
  final controller = TextEditingController(
    text: initialMinor == null ? '' : _minorToInputText(initialMinor),
  );
  return showDialog<int>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: _moneyField(controller, 'القيمة'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            final amount = _requireMoney(context, controller, 'القيمة');
            if (amount == null) return;
            Navigator.pop(context, amount);
          },
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> ensureArabicFormatting() =>
    initializeDateFormatting('ar_EG', null);
