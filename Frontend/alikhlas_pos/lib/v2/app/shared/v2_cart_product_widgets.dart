part of '../v2_app.dart';

class _CartLine {
  _CartLine(this.product);
  final Product product;
  int qty = 1;
}

class _ProductAvatar extends StatelessWidget {
  const _ProductAvatar({required this.product, this.warning = false});

  final Product product;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final imagePath = product.imagePath;
    final file = imagePath == null ? null : File(imagePath);
    final hasImage = file != null && file.existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 42,
        height: 42,
        color: Colors.white.withValues(alpha: 0.58),
        child: hasImage
            ? Image.file(file, fit: BoxFit.cover)
            : Icon(
                product.isActive ? Icons.inventory_2 : Icons.block,
                color: warning ? Theme.of(context).colorScheme.error : null,
              ),
      ),
    );
  }
}

class _PurchaseCartLine {
  _PurchaseCartLine(this.product) {
    costMinor = product.avgCostMinor;
    costInput = product.avgCostMinor == 0
        ? ''
        : _minorToInputText(product.avgCostMinor);
  }

  final Product product;
  int qty = 1;
  late int costMinor;
  late String costInput;
}

class _BarcodePrintPromptDialog extends StatefulWidget {
  const _BarcodePrintPromptDialog({required this.items});

  final List<BarcodeLabelItem> items;

  @override
  State<_BarcodePrintPromptDialog> createState() =>
      _BarcodePrintPromptDialogState();
}

class _BarcodePrintPromptDialogState extends State<_BarcodePrintPromptDialog> {
  late final List<TextEditingController> _quantities;

  @override
  void initState() {
    super.initState();
    _quantities = [
      for (final item in widget.items)
        TextEditingController(
          text: item.canPrint ? item.quantity.toString() : '0',
        ),
    ];
  }

  @override
  void dispose() {
    for (final controller in _quantities) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = _labels();
    final skippedCount = widget.items.where((item) => !item.canPrint).length;
    final totalLabels = BarcodeLabelsPdf.printableCount(labels);

    return AlertDialog(
      title: const Text('طباعة باركود الوارد؟'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('إجمالي الملصقات: $totalLabels'),
            if (skippedCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'بعض الأصناف لا تحتوي على باركود',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) => _labelTile(index),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('تخطي'),
        ),
        FilledButton.icon(
          onPressed: totalLabels == 0
              ? null
              : () => Navigator.pop(
                  context,
                  BarcodeLabelsPdf.printableItems(labels),
                ),
          icon: const Icon(Icons.print),
          label: const Text('طباعة الباركود'),
        ),
      ],
    );
  }

  Widget _labelTile(int index) {
    final item = widget.items[index];
    final hasBarcode = item.barcode?.trim().isNotEmpty == true;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.productName),
      subtitle: Text(hasBarcode ? item.barcode!.trim() : 'بدون باركود'),
      trailing: SizedBox(
        width: 96,
        child: TextField(
          controller: _quantities[index],
          enabled: hasBarcode,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'العدد'),
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
  }

  List<BarcodeLabelItem> _labels() {
    return [
      for (var index = 0; index < widget.items.length; index++)
        BarcodeLabelItem(
          productName: widget.items[index].productName,
          barcode: widget.items[index].barcode,
          quantity: int.tryParse(_quantities[index].text) ?? 0,
        ),
    ];
  }
}

class _CartList extends StatelessWidget {
  const _CartList({required this.cart, required this.onChanged});
  final List<_CartLine> cart;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) return const Center(child: Text('السلة فارغة'));
    return ListView.builder(
      itemCount: cart.length,
      itemBuilder: (context, index) {
        final line = cart[index];
        return ListTile(
          dense: true,
          title: Text(line.product.name),
          subtitle: Text(Money(line.product.salePriceMinor).format()),
          trailing: _QtyStepper(
            qty: line.qty,
            maxQty: line.product.stockQty,
            onChanged: (qty) {
              line.qty = qty;
              onChanged();
            },
            onRemove: () {
              cart.removeAt(index);
              onChanged();
            },
          ),
        );
      },
    );
  }
}

class _PurchaseCart extends StatelessWidget {
  const _PurchaseCart({required this.cart, required this.onChanged});
  final List<_PurchaseCartLine> cart;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) return const Center(child: Text('فاتورة الشراء فارغة'));
    return ListView.builder(
      itemCount: cart.length,
      itemBuilder: (context, index) {
        final line = cart[index];
        return ListTile(
          dense: true,
          title: Text(line.product.name),
          subtitle: SizedBox(
            width: 150,
            child: TextFormField(
              initialValue: line.costInput,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'تكلفة الوحدة',
                errorText: _purchaseCostInputError(line),
              ),
              onChanged: (value) {
                line.costInput = value;
                final parsed = parseMoneyInput(value);
                if (parsed.isValid) line.costMinor = parsed.minorUnits;
                onChanged();
              },
            ),
          ),
          trailing: _QtyStepper(
            qty: line.qty,
            maxQty: 9999,
            onChanged: (qty) {
              line.qty = qty;
              onChanged();
            },
            onRemove: () {
              cart.removeAt(index);
              onChanged();
            },
          ),
        );
      },
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.qty,
    required this.maxQty,
    required this.onChanged,
    required this.onRemove,
    this.minQty = 1,
  });

  final int qty;
  final int minQty;
  final int maxQty;
  final ValueChanged<int> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: 'إنقاص',
          onPressed: qty > minQty ? () => onChanged(qty - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(width: 32, child: Center(child: Text('$qty'))),
        IconButton(
          tooltip: 'زيادة',
          onPressed: qty < maxQty ? () => onChanged(qty + 1) : null,
          icon: const Icon(Icons.add),
        ),
        IconButton(
          tooltip: 'حذف',
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}
