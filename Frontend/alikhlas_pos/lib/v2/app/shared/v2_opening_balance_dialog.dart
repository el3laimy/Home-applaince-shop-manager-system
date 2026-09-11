part of '../v2_app.dart';

class _OpeningBalanceDialog extends StatefulWidget {
  const _OpeningBalanceDialog({
    required this.customers,
    required this.suppliers,
  });

  final List<Customer> customers;
  final List<Supplier> suppliers;

  @override
  State<_OpeningBalanceDialog> createState() => _OpeningBalanceDialogState();
}

class _OpeningBalanceDialogState extends State<_OpeningBalanceDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  OpeningBalanceType _type = OpeningBalanceType.customerReceivable;
  int? _partyId;
  DateTime _dueDate = DateUtils.dateOnly(DateTime.now());

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _requiresParty => _type.requiresParty;

  List<DropdownMenuItem<int>> get _partyItems => switch (_type) {
    OpeningBalanceType.customerReceivable => [
      for (final customer in widget.customers)
        DropdownMenuItem(value: customer.id, child: Text(customer.name)),
    ],
    OpeningBalanceType.supplierPayable => [
      for (final supplier in widget.suppliers)
        DropdownMenuItem(value: supplier.id, child: Text(supplier.name)),
    ],
    _ => const [],
  };

  String get _partyLabel =>
      _type == OpeningBalanceType.customerReceivable ? 'العميل' : 'المورد';

  String? get _selectedPartyName {
    if (_partyId == null) return null;
    return switch (_type) {
      OpeningBalanceType.customerReceivable =>
        widget.customers
            .where((customer) => customer.id == _partyId)
            .map((customer) => customer.name)
            .firstOrNull,
      OpeningBalanceType.supplierPayable =>
        widget.suppliers
            .where((supplier) => supplier.id == _partyId)
            .map((supplier) => supplier.name)
            .firstOrNull,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إدخال رصيد افتتاحي'),
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
                    'استخدم هذه الخطوة مرة واحدة فقط عند نقل محل قائم. أدخل الرصيد من دفاترك القديمة قبل بدء حركات جديدة على الحساب.',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<OpeningBalanceType>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'نوع الرصيد'),
                items: [
                  for (final type in OpeningBalanceType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) {
                  if (value == null || value == _type) return;
                  setState(() {
                    _type = value;
                    _partyId = null;
                  });
                },
              ),
              if (_requiresParty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  key: ValueKey(_type),
                  initialValue: _partyId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: _partyLabel),
                  hint: Text('اختر $_partyLabel'),
                  items: _partyItems,
                  onChanged: (value) => setState(() => _partyId = value),
                ),
                if (_partyItems.isEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'لا يوجد $_partyLabel مسجل. أضفه أولًا من شاشة العملاء والموردين.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 10),
              _moneyField(_amount, 'قيمة الرصيد'),
              if (_requiresParty) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickDueDate,
                  icon: const Icon(Icons.event),
                  label: Text('تاريخ الاستحقاق: ${_date(_dueDate)}'),
                ),
                const SizedBox(height: 6),
                const Text(
                  'سيظهر الرصيد كمديونية واحدة يمكن تحصيلها أو سدادها من شاشة الأقساط.',
                  style: TextStyle(color: _mutedInk),
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Text(
                  'هذا قيد رصيد فعلي مقابل رأس المال. عند فتح الوردية أدخل المبلغ الموجود فعليًا في الدرج؛ فتح الوردية لا ينشئ قيدًا ماليًا ثانيًا.',
                  style: TextStyle(color: _mutedInk),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                maxLength: 200,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'توضيح اختياري',
                  helperText: 'مثال: مطابق لدفتر يوم 2026-09-01',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('مراجعة الرصيد')),
      ],
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 10, 12, 31),
    );
    if (!mounted || picked == null) return;
    setState(() => _dueDate = DateUtils.dateOnly(picked));
  }

  void _submit() {
    final amountMinor = _requireMoney(context, _amount, 'قيمة الرصيد');
    if (amountMinor == null) return;
    if (amountMinor <= 0) {
      _showSnack(context, 'قيمة الرصيد يجب أن تكون أكبر من صفر');
      return;
    }
    if (_requiresParty && _partyId == null) {
      _showSnack(context, 'اختر $_partyLabel صاحب الرصيد');
      return;
    }
    final note = _note.text.trim();
    Navigator.pop(
      context,
      _OpeningBalanceFormData(
        type: _type,
        partyId: _requiresParty ? _partyId : null,
        partyName: _requiresParty ? _selectedPartyName : null,
        amountMinor: amountMinor,
        dueDate: _requiresParty ? _dueDate : null,
        note: note.isEmpty ? null : note,
      ),
    );
  }
}

class _OpeningBalanceFormData {
  const _OpeningBalanceFormData({
    required this.type,
    required this.partyId,
    required this.partyName,
    required this.amountMinor,
    required this.dueDate,
    required this.note,
  });

  final OpeningBalanceType type;
  final int? partyId;
  final String? partyName;
  final int amountMinor;
  final DateTime? dueDate;
  final String? note;
}
