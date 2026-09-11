part of '../v2_app.dart';

class _InventoryAdjustmentDialog extends StatefulWidget {
  const _InventoryAdjustmentDialog({required this.product});

  final Product product;

  @override
  State<_InventoryAdjustmentDialog> createState() =>
      _InventoryAdjustmentDialogState();
}

class _InventoryAdjustmentDialogState
    extends State<_InventoryAdjustmentDialog> {
  late final _counted = TextEditingController(
    text: widget.product.stockQty.toString(),
  );
  final _note = TextEditingController();
  final _unitCost = TextEditingController();
  InventoryAdjustmentReason _reason = InventoryAdjustmentReason.physicalCount;

  @override
  void dispose() {
    _counted.dispose();
    _note.dispose();
    _unitCost.dispose();
    super.dispose();
  }

  int? get _parsedCount =>
      int.tryParse(normalizeArabicDigits(_counted.text.trim()));

  int get _previewUnitCost {
    if (widget.product.avgCostMinor > 0) return widget.product.avgCostMinor;
    final parsed = parseMoneyInput(_unitCost.text);
    return parsed.isValid ? parsed.minorUnits : 0;
  }

  @override
  Widget build(BuildContext context) {
    final count = _parsedCount;
    final difference = count == null ? null : count - widget.product.stockQty;
    final valueDifference = difference == null
        ? null
        : difference * _previewUnitCost;
    return AlertDialog(
      title: const Text('جرد وتسوية الرصيد'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.product.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text('الرصيد المسجل حاليًا: ${widget.product.stockQty}'),
              const SizedBox(height: 12),
              TextField(
                controller: _counted,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الكمية الفعلية بعد العد',
                  helperText: 'اكتب إجمالي الموجود فعليًا، وليس مقدار الفرق.',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<InventoryAdjustmentReason>(
                initialValue: _reason,
                decoration: const InputDecoration(labelText: 'سبب الفرق'),
                items: [
                  for (final reason in InventoryAdjustmentReason.values)
                    DropdownMenuItem(value: reason, child: Text(reason.label)),
                ],
                onChanged: (value) => setState(() {
                  _reason = value ?? _reason;
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'توضيح اختياري',
                  helperText:
                      _reason == InventoryAdjustmentReason.dataCorrection
                      ? 'التوضيح مطلوب عند تصحيح إدخال.'
                      : 'مثال: كسر أثناء النقل أو نتيجة عد الرف.',
                ),
              ),
              if (widget.product.avgCostMinor <= 0) ...[
                const SizedBox(height: 4),
                _moneyField(
                  _unitCost,
                  'تكلفة الوحدة للتسوية',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 4),
                const Text(
                  'لا توجد تكلفة محفوظة لهذا الصنف؛ تُستخدم هذه القيمة لحساب قيد الجرد.',
                  style: TextStyle(color: _mutedInk),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'تُحسب التسوية بمتوسط التكلفة المحفوظ: ${Money(widget.product.avgCostMinor).format()}',
                  style: const TextStyle(color: _mutedInk),
                ),
              ],
              if (difference != null && difference != 0) ...[
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'الفرق ${difference > 0 ? '+' : ''}$difference · تغير قيمة المخزون ${Money(valueDifference ?? 0).format()}',
                    ),
                  ),
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
        FilledButton(onPressed: _submit, child: const Text('مراجعة التسوية')),
      ],
    );
  }

  void _submit() {
    final countedQty = _parsedCount;
    if (countedQty == null || countedQty < 0 || countedQty > 1000000) {
      _showSnack(
        context,
        'الكمية الفعلية يجب أن تكون رقمًا من صفر إلى 1000000',
      );
      return;
    }
    if (countedQty == widget.product.stockQty) {
      _showSnack(context, 'لا يوجد فرق بين العد والرصيد المسجل');
      return;
    }
    final note = _note.text.trim();
    if (_reason == InventoryAdjustmentReason.dataCorrection && note.isEmpty) {
      _showSnack(context, 'اكتب توضيحًا عند اختيار تصحيح إدخال');
      return;
    }
    final unitCostMinor = widget.product.avgCostMinor > 0
        ? widget.product.avgCostMinor
        : _requireMoney(context, _unitCost, 'تكلفة الوحدة');
    if (unitCostMinor == null) return;
    if (unitCostMinor <= 0) {
      _showSnack(context, 'تكلفة الوحدة يجب أن تكون أكبر من صفر');
      return;
    }
    Navigator.pop(
      context,
      _InventoryAdjustmentFormData(
        countedQty: countedQty,
        reason: _reason,
        note: note.isEmpty ? null : note,
        unitCostMinor: unitCostMinor,
      ),
    );
  }
}

class _InventoryAdjustmentFormData {
  const _InventoryAdjustmentFormData({
    required this.countedQty,
    required this.reason,
    required this.note,
    required this.unitCostMinor,
  });

  final int countedQty;
  final InventoryAdjustmentReason reason;
  final String? note;
  final int unitCostMinor;
}
