part of '../v2_app.dart';

class _FinancialCorrectionDialog extends StatefulWidget {
  const _FinancialCorrectionDialog();

  @override
  State<_FinancialCorrectionDialog> createState() =>
      _FinancialCorrectionDialogState();
}

class _FinancialCorrectionDialogState
    extends State<_FinancialCorrectionDialog> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _note = TextEditingController();
  FinancialCorrectionTarget _target = FinancialCorrectionTarget.cash;
  var _increasesBalance = true;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تصحيح خزينة أو محفظة'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.tertiaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'استخدمه فقط عند عدّ فرق حقيقي في الخزينة أو المحفظة. لا يعدّل فاتورة بيع أو شراء أو مخزون أو مديونية طرف؛ لكل منها مستندها المتخصص.',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<FinancialCorrectionTarget>(
                initialValue: _target,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الحساب'),
                items: [
                  for (final target in FinancialCorrectionTarget.values)
                    DropdownMenuItem(value: target, child: Text(target.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _target = value);
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('زيادة فعلية')),
                  ButtonSegment(value: false, label: Text('عجز فعلي')),
                ],
                selected: {_increasesBalance},
                onSelectionChanged: (value) {
                  setState(() => _increasesBalance = value.single);
                },
              ),
              const SizedBox(height: 12),
              _moneyField(_amount, 'قيمة الفرق'),
              const SizedBox(height: 10),
              TextField(
                controller: _reason,
                maxLength: 240,
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'سبب التصحيح',
                  helperText: 'مثال: فرق بعد عدّ الدرج عند تغيير أمين الخزينة',
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _note,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'توضيح اختياري',
                  helperText: 'رقم المحضر أو اسم من راجع العد إن وجد',
                ),
              ),
              if (_target == FinancialCorrectionTarget.cash) ...[
                const SizedBox(height: 6),
                const Text(
                  'يلزم وجود وردية مفتوحة عند تصحيح الخزينة حتى يظهر الفرق في يومه الصحيح.',
                  style: TextStyle(color: _mutedInk),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('مراجعة التصحيح')),
      ],
    );
  }

  void _submit() {
    final amountMinor = _requireMoney(context, _amount, 'قيمة الفرق');
    if (amountMinor == null) return;
    if (amountMinor <= 0) {
      _showSnack(context, 'قيمة التصحيح يجب أن تكون أكبر من صفر');
      return;
    }
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      _showSnack(context, 'اكتب سبب التصحيح');
      return;
    }
    final note = _note.text.trim();
    Navigator.pop(
      context,
      _FinancialCorrectionFormData(
        target: _target,
        amountMinor: amountMinor,
        increasesBalance: _increasesBalance,
        reason: reason,
        note: note.isEmpty ? null : note,
      ),
    );
  }
}

class _FinancialCorrectionFormData {
  const _FinancialCorrectionFormData({
    required this.target,
    required this.amountMinor,
    required this.increasesBalance,
    required this.reason,
    required this.note,
  });

  final FinancialCorrectionTarget target;
  final int amountMinor;
  final bool increasesBalance;
  final String reason;
  final String? note;
}

class _FinancialCorrectionReversalDialog extends StatefulWidget {
  const _FinancialCorrectionReversalDialog({required this.corrections});

  final List<FinancialCorrection> corrections;

  @override
  State<_FinancialCorrectionReversalDialog> createState() =>
      _FinancialCorrectionReversalDialogState();
}

class _FinancialCorrectionReversalDialogState
    extends State<_FinancialCorrectionReversalDialog> {
  final _reason = TextEditingController();
  final _note = TextEditingController();
  late int _correctionId = widget.corrections.first.id;

  FinancialCorrection get _selected => widget.corrections.singleWhere(
    (correction) => correction.id == _correctionId,
  );

  @override
  void dispose() {
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final target = FinancialCorrectionTarget.values.byName(selected.target);
    return AlertDialog(
      title: const Text('عكس تصحيح مالي'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'سينشئ التطبيق مستند عكس مستقلًا وقيدًا معاكسًا. سيظل التصحيح الأصلي محفوظًا في السجل ولن يمكن عكسه مرة أخرى.',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _correctionId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'التصحيح الأصلي'),
                items: [
                  for (final correction in widget.corrections)
                    DropdownMenuItem(
                      value: correction.id,
                      child: Text(
                        '#${correction.id} — ${FinancialCorrectionTarget.values.byName(correction.target).label} — ${Money(correction.deltaMinor.abs()).format()}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _correctionId = value);
                },
              ),
              const SizedBox(height: 12),
              _InfoLine('الحساب', target.label),
              _InfoLine(
                'أثر التصحيح',
                selected.deltaMinor > 0 ? 'زيادة فعلية' : 'عجز فعلي',
              ),
              _InfoLine('القيمة', Money(selected.deltaMinor.abs()).format()),
              _InfoLine('السبب الأصلي', selected.reason),
              const SizedBox(height: 10),
              TextField(
                controller: _reason,
                maxLength: 240,
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'سبب العكس',
                  helperText: 'مثال: أُدخل الفرق على الحساب الخطأ',
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _note,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'توضيح اختياري'),
              ),
              if (target == FinancialCorrectionTarget.cash) ...[
                const SizedBox(height: 6),
                const Text(
                  'يلزم وجود وردية مفتوحة عند عكس تصحيح الخزينة.',
                  style: TextStyle(color: _mutedInk),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('مراجعة العكس')),
      ],
    );
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      _showSnack(context, 'اكتب سبب عكس التصحيح');
      return;
    }
    final note = _note.text.trim();
    Navigator.pop(
      context,
      _FinancialCorrectionReversalFormData(
        correction: _selected,
        reason: reason,
        note: note.isEmpty ? null : note,
      ),
    );
  }
}

class _FinancialCorrectionReversalFormData {
  const _FinancialCorrectionReversalFormData({
    required this.correction,
    required this.reason,
    required this.note,
  });

  final FinancialCorrection correction;
  final String reason;
  final String? note;
}
