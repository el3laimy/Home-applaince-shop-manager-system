part of '../v2_app.dart';

class _ProductCsvPreviewDialog extends StatelessWidget {
  const _ProductCsvPreviewDialog({
    required this.fileName,
    required this.preview,
  });

  final String fileName;
  final ProductCsvPreview preview;

  @override
  Widget build(BuildContext context) {
    final visibleRows = preview.rows.take(100).toList();
    return AlertDialog(
      title: const Text('معاينة استيراد المنتجات'),
      content: SizedBox(
        width: 760,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(fileName, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Text('الصفوف السليمة: ${preview.rows.length}'),
                Text(
                  'الأخطاء: ${preview.issues.length}',
                  style: TextStyle(
                    color: preview.issues.isEmpty
                        ? V2DesignTokens.mint
                        : V2DesignTokens.rose,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (preview.issues.isNotEmpty) ...[
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
                    'لن يُحفظ أي منتج حتى تصلح جميع الصفوف ثم تختار الملف مرة أخرى.',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: preview.issues.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final issue = preview.issues[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.error_outline,
                        color: V2DesignTokens.rose,
                      ),
                      title: Text('الصف ${issue.sourceRow}'),
                      subtitle: Text(issue.message),
                    );
                  },
                ),
              ),
            ] else ...[
              const Text(
                'راجع البيانات التالية. الاعتماد سيضيف كل المنتجات والأرصدة في عملية واحدة.',
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: visibleRows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final row = visibleRows[index];
                    return ListTile(
                      dense: true,
                      title: Text('${row.sourceRow}. ${row.name}'),
                      subtitle: Text(
                        '${row.barcode ?? 'باركود تلقائي'} · رصيد ${row.openingQty} · تكلفة ${Money(row.openingCostMinor).format()} · حد ${row.minStockQty}',
                      ),
                      trailing: Text(Money(row.salePriceMinor).format()),
                    );
                  },
                ),
              ),
              if (preview.rows.length > visibleRows.length)
                Text(
                  'تظهر أول ${visibleRows.length} صفوف من ${preview.rows.length}.',
                  style: const TextStyle(color: _mutedInk),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(preview.canImport ? 'إلغاء' : 'إغلاق وتصحيح الملف'),
        ),
        if (preview.canImport)
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.file_upload_outlined),
            label: Text('اعتماد ${preview.rows.length} منتج'),
          ),
      ],
    );
  }
}
