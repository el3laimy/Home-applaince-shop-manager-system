part of '../v2_app.dart';

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
