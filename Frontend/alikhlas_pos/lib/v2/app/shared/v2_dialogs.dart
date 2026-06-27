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

class _SaleReceiptDialog extends StatefulWidget {
  const _SaleReceiptDialog({required this.receipt});
  final SaleReceiptSnapshot receipt;

  @override
  State<_SaleReceiptDialog> createState() => _SaleReceiptDialogState();
}

class _SaleReceiptDialogState extends State<_SaleReceiptDialog> {
  bool _printing = false;

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
        FilledButton.icon(
          onPressed: _printing ? null : _print,
          icon: const Icon(Icons.print),
          label: Text(_printing ? 'جاري الطباعة...' : 'طباعة'),
        ),
      ],
    );
  }

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      await SaleReceiptPdf.printReceipt(widget.receipt);
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

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.product, this.quickPurchase = false});
  final Product? product;
  final bool quickPurchase;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _barcode = TextEditingController(
    text: widget.product?.barcode ?? '',
  );
  late final _category = TextEditingController(
    text: widget.product?.category ?? '',
  );
  late final _price = TextEditingController(
    text: widget.product == null
        ? ''
        : _minorToInputText(widget.product!.salePriceMinor),
  );
  late final _qty = TextEditingController(
    text: widget.product?.stockQty.toString() ?? '0',
  );
  late final _cost = TextEditingController(
    text: widget.quickPurchase
        ? '0'
        : widget.product == null
        ? ''
        : _minorToInputText(widget.product!.avgCostMinor),
  );
  late final _min = TextEditingController(
    text: widget.product?.minStockQty.toString() ?? '1',
  );
  late String? _imagePath = widget.product?.imagePath;

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _category.dispose();
    _price.dispose();
    _qty.dispose();
    _cost.dispose();
    _min.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.quickPurchase
            ? 'منتج جديد للشراء'
            : widget.product == null
            ? 'منتج جديد'
            : 'تعديل منتج',
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم المنتج'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcode,
                    decoration: const InputDecoration(
                      labelText: 'باركود',
                      helperText: 'اتركه فارغًا للتوليد التلقائي',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _category,
                    decoration: const InputDecoration(labelText: 'تصنيف'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _moneyField(_price, 'سعر البيع')),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'حد النقص'),
                  ),
                ),
              ],
            ),
            if (widget.product == null && !widget.quickPurchase) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'رصيد افتتاحي',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _moneyField(_cost, 'تكلفة افتتاحية')),
                ],
              ),
            ],
            const SizedBox(height: 10),
            _ProductImagePicker(
              imagePath: _imagePath,
              onPick: () async {
                final picked = await FilePicker.platform.pickFiles(
                  dialogTitle: 'اختر صورة المنتج',
                  type: FileType.image,
                );
                if (!mounted ||
                    picked == null ||
                    picked.files.single.path == null) {
                  return;
                }
                try {
                  final localPath = await LocalImageStore.copyProductImage(
                    picked.files.single.path!,
                  );
                  if (!mounted) return;
                  setState(() => _imagePath = localPath);
                } on FileSystemException {
                  if (!context.mounted) return;
                  _showSnack(
                    context,
                    'تعذر حفظ صورة المنتج. اختر ملف صورة PNG أو JPG أو WEBP',
                  );
                } on ArgumentError {
                  if (!context.mounted) return;
                  _showSnack(
                    context,
                    'تعذر حفظ صورة المنتج. اختر ملف صورة PNG أو JPG أو WEBP',
                  );
                }
              },
              onClear: () => setState(() => _imagePath = null),
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
            final name = _name.text.trim();
            if (name.isEmpty) {
              _showSnack(context, 'اسم المنتج مطلوب');
              return;
            }
            final price = _requireMoney(context, _price, 'سعر البيع');
            if (price == null) return;
            if (price <= 0) {
              _showSnack(context, 'سعر البيع يجب أن يكون أكبر من صفر');
              return;
            }
            final minStockQty = int.tryParse(_min.text.trim());
            if (minStockQty == null || minStockQty < 0) {
              _showSnack(context, 'حد النقص يجب أن يكون رقمًا غير سالب');
              return;
            }
            var openingQty = 0;
            var openingCostMinor = 0;
            if (widget.product == null && !widget.quickPurchase) {
              final qtyText = _qty.text.trim();
              openingQty = qtyText.isEmpty ? 0 : int.tryParse(qtyText) ?? -1;
              if (openingQty < 0) {
                _showSnack(
                  context,
                  'الرصيد الافتتاحي يجب أن يكون رقمًا غير سالب',
                );
                return;
              }
              final cost = _requireMoney(context, _cost, 'تكلفة افتتاحية');
              if (cost == null) return;
              if (openingQty > 0 && cost <= 0) {
                _showSnack(
                  context,
                  'تكلفة افتتاحية مطلوبة عند إدخال رصيد افتتاحي',
                );
                return;
              }
              openingCostMinor = openingQty > 0 ? cost : 0;
            }
            Navigator.pop(
              context,
              _ProductFormData(
                name: name,
                barcode: _barcode.text,
                category: _category.text,
                imagePath: _imagePath,
                salePriceMinor: price,
                openingQty: openingQty,
                openingCostMinor: openingCostMinor,
                minStockQty: minStockQty,
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _ProductFormData {
  const _ProductFormData({
    required this.name,
    required this.barcode,
    required this.category,
    required this.imagePath,
    required this.salePriceMinor,
    required this.openingQty,
    required this.openingCostMinor,
    required this.minStockQty,
  });

  final String name;
  final String barcode;
  final String category;
  final String? imagePath;
  final int salePriceMinor;
  final int openingQty;
  final int openingCostMinor;
  final int minStockQty;
}

class _ProductImagePicker extends StatelessWidget {
  const _ProductImagePicker({
    required this.imagePath,
    required this.onPick,
    required this.onClear,
  });

  final String? imagePath;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final file = imagePath == null ? null : File(imagePath!);
    final hasImage = file != null && file.existsSync();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(V2DesignTokens.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: hasImage
                    ? Image.file(file, fit: BoxFit.cover)
                    : const ColoredBox(
                        color: Color(0xEAF7FAF8),
                        child: Icon(Icons.image_outlined),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                imagePath == null
                    ? 'لا توجد صورة للمنتج'
                    : _fileName(imagePath!),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.photo_library),
              label: const Text('اختيار'),
            ),
            if (imagePath != null)
              IconButton(
                tooltip: 'إزالة الصورة',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundImagePicker extends StatelessWidget {
  const _BackgroundImagePicker({
    required this.imagePath,
    required this.onPick,
    required this.onClear,
  });

  final String? imagePath;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(V2DesignTokens.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Icon(Icons.wallpaper),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                imagePath == null
                    ? 'استخدم النمط المختار بدون صورة'
                    : _fileName(imagePath!),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.photo_library),
              label: const Text('صورة'),
            ),
            if (imagePath != null)
              IconButton(
                tooltip: 'إزالة الصورة',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}

String _backgroundLabel(String preset) {
  return switch (preset) {
    'sky' => 'سماء هادئة',
    'blush' => 'وردي ناعم',
    'graphite' => 'رمادي احترافي',
    _ => 'Aurora زجاجي',
  };
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

  @override
  Widget build(BuildContext context) {
    final selected = _quantities.entries
        .where((entry) => entry.value > 0)
        .fold<int>(0, (sum, entry) => sum + entry.value);
    final refund = widget.preview.lines.fold<int>(
      0,
      (sum, line) =>
          sum + ((_quantities[line.saleItemId] ?? 0) * line.unitPriceMinor),
    );
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
                if (widget.preview.receipt.invoice.customerId != null)
                  const DropdownMenuItem(
                    value: PaymentMethod.installment,
                    child: Text('خصم من العميل'),
                  ),
              ],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
            const SizedBox(height: 12),
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
          onPressed: selected == 0
              ? null
              : () => Navigator.pop(context, (
                  quantities: Map<int, int>.fromEntries(
                    _quantities.entries.where((entry) => entry.value > 0),
                  ),
                  method: _method,
                )),
          child: const Text('تسجيل'),
        ),
      ],
    );
  }
}
