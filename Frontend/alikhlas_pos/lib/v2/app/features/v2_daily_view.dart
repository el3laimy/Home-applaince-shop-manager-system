part of '../v2_app.dart';

class _DailyView extends ConsumerWidget {
  const _DailyView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = snapshot.dashboard;
    final summary = snapshot.dailySummary;
    return _Screen(
      title: 'يومية المحل',
      subtitle: dashboard.openShift == null
          ? 'ابدأ وردية جديدة قبل أي حركة كاش'
          : 'وردية مفتوحة منذ ${_time(dashboard.openShift!.openedAt)}',
      trailing: Wrap(
        spacing: 8,
        children: [
          FilledButton.icon(
            onPressed: dashboard.openShift == null
                ? () => _openShift(context, ref)
                : null,
            icon: const Icon(Icons.lock_open),
            label: const Text('فتح وردية'),
          ),
          OutlinedButton.icon(
            onPressed: dashboard.openShift == null
                ? null
                : () => _closeShift(context, ref, dashboard.cashMinor),
            icon: const Icon(Icons.lock),
            label: const Text('إغلاق وردية'),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _MetricsGrid(
              metrics: [
                ('الخزينة', dashboard.cashMinor, Icons.payments),
                (
                  'المحفظة',
                  dashboard.walletMinor,
                  Icons.account_balance_wallet,
                ),
                ('أرصدة العملاء', dashboard.receivablesMinor, Icons.people),
                (
                  'أرصدة الموردين',
                  -dashboard.payablesMinor,
                  Icons.local_shipping,
                ),
                ('قيمة المخزون', dashboard.inventoryMinor, Icons.inventory_2),
                ('صافي الربح', dashboard.grossProfitMinor, Icons.trending_up),
              ],
            ),
            const SizedBox(height: 14),
            _DailyAlertsPanel(snapshot: snapshot),
            const SizedBox(height: 14),
            _DailySummaryPanel(summary: summary),
            const SizedBox(height: 14),
            SizedBox(
              height: 320,
              child: Row(
                children: [
                  Expanded(
                    child: _GlassPane(
                      child: _RecentLedger(entries: snapshot.recentLedger),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _GlassPane(
                      child: _LowStockList(products: snapshot.products),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openShift(BuildContext context, WidgetRef ref) async {
    final amount = await _askMoney(context, title: 'رصيد افتتاحي');
    if (amount == null || !context.mounted) return;
    final result = await ref.read(useCasesProvider).openShift(amount);
    if (!context.mounted) return;
    _showResult(context, result, success: 'تم فتح الوردية');
    _refresh(ref);
  }

  Future<void> _closeShift(
    BuildContext context,
    WidgetRef ref,
    int expectedCash,
  ) async {
    final amount = await _askMoney(
      context,
      title: 'الكاش الفعلي في الدرج',
      initialMinor: expectedCash,
    );
    if (amount == null || !context.mounted) return;
    final result = await ref.read(useCasesProvider).closeShift(amount);
    if (!context.mounted) return;
    _showResult(context, result, success: 'تم إغلاق الوردية');
    _refresh(ref);
  }
}
