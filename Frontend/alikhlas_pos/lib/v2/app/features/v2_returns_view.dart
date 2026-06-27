part of '../v2_app.dart';

class _ReturnsView extends ConsumerWidget {
  const _ReturnsView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Screen(
      title: 'المرتجعات',
      subtitle: 'مرتجع مرتبط بفاتورة بيع ويعكس البيع والتكلفة',
      child: _GlassPane(
        child: ListView.separated(
          itemCount: snapshot.recentSales.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final sale = snapshot.recentSales[index];
            return ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(sale.invoiceNo),
              subtitle: Text(_dateTime(sale.createdAt)),
              trailing: FilledButton(
                onPressed: () => _returnSale(context, ref, sale),
                child: const Text('إنشاء مرتجع'),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _returnSale(
    BuildContext context,
    WidgetRef ref,
    SaleInvoice sale,
  ) async {
    final preview = await ref.read(useCasesProvider).saleReturnPreview(sale.id);
    if (!context.mounted || preview.lines.isEmpty) return;
    final result =
        await showDialog<({Map<int, int> quantities, PaymentMethod method})>(
          context: context,
          builder: (_) => _ReturnDialog(preview: preview),
        );
    if (result == null || !context.mounted) return;
    final appResult = await _runWithNegativeBalanceApproval(
      context,
      action: (allowNegativeBalance) => ref
          .read(useCasesProvider)
          .createSaleReturn(
            saleId: sale.id,
            saleItemQuantities: result.quantities,
            refundMethod: result.method,
            allowNegativeBalance: allowNegativeBalance,
          ),
    );
    if (!context.mounted) return;
    _showResult(context, appResult, success: 'تم تسجيل المرتجع');
    _refresh(ref);
  }
}
