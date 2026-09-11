part of '../v2_app.dart';

class _ReportsView extends ConsumerStatefulWidget {
  const _ReportsView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  ConsumerState<_ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends ConsumerState<_ReportsView> {
  _ReportRange _range = _ReportRange.today;

  @override
  Widget build(BuildContext context) {
    final bounds = _rangeBounds(_range);
    return _Screen(
      title: 'التقارير',
      subtitle: 'ملخص مشتق من الدفتر بدون شاشة محاسبية معقدة',
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ReportRangeSelector(
            selected: _range,
            onChanged: (range) => setState(() => _range = range),
          ),
          FilledButton.icon(
            onPressed: _addExpense,
            icon: const Icon(Icons.add_card),
            label: const Text('مصروف جديد'),
          ),
          FilledButton.icon(
            onPressed: () => _printCurrentReport(bounds),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('تصدير PDF'),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            FutureBuilder<
              ({PeriodReportSnapshot report, List<Expense> expenses})
            >(
              future: _loadReport(bounds),
              builder: (context, asyncReport) {
                final reportData = asyncReport.data;
                if (reportData == null) {
                  return const SizedBox(
                    height: 260,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final report = reportData.report;
                return Column(
                  children: [
                    _MetricsGrid(
                      metrics: [
                        ('مبيعات الفترة', report.salesMinor, Icons.sell),
                        ('تكلفة الفترة', report.cogsMinor, Icons.receipt),
                        (
                          'مصروفات الفترة',
                          report.expensesMinor,
                          Icons.money_off,
                        ),
                        ('ربح الفترة', report.profitMinor, Icons.trending_up),
                        ('صافي الكاش', report.cashNetMinor, Icons.payments),
                        (
                          'صافي المحفظة',
                          report.walletNetMinor,
                          Icons.account_balance_wallet,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 318,
                      child: _PeriodReportPanel(report: report),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 320,
                      child: _ExpensesPanel(expenses: reportData.expenses),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 960;
                final inventoryPanel = SizedBox(
                  height: 318,
                  child: _InventoryValuationPanel(
                    products: widget.snapshot.products,
                    ledgerInventoryMinor:
                        widget.snapshot.dashboard.inventoryMinor,
                  ),
                );
                final invoicePanel = SizedBox(
                  height: 360,
                  child: _RecentInvoicesPanel(
                    sales: widget.snapshot.recentSales,
                    purchases: widget.snapshot.recentPurchases,
                    onSaleOpen: (sale) =>
                        _openSaleReceipt(context, ref, sale.id),
                  ),
                );
                final installmentsPanel = SizedBox(
                  height: 360,
                  child: _DueInstallmentsPanel(
                    installments: widget.snapshot.dueInstallments,
                  ),
                );

                if (narrow) {
                  return Column(
                    children: [
                      inventoryPanel,
                      const SizedBox(height: 14),
                      invoicePanel,
                      const SizedBox(height: 14),
                      installmentsPanel,
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: inventoryPanel),
                        const SizedBox(width: 14),
                        Expanded(child: invoicePanel),
                      ],
                    ),
                    const SizedBox(height: 14),
                    installmentsPanel,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final lowStock = SizedBox(
                  height: 320,
                  child: _GlassPane(
                    child: _LowStockList(products: widget.snapshot.products),
                  ),
                );
                final ledger = SizedBox(
                  height: 320,
                  child: _GlassPane(
                    child: _RecentLedger(entries: widget.snapshot.recentLedger),
                  ),
                );
                if (constraints.maxWidth < 760) {
                  return Column(
                    children: [lowStock, const SizedBox(height: 14), ledger],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: lowStock),
                    const SizedBox(width: 14),
                    Expanded(child: ledger),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  (DateTime, DateTime) _rangeBounds(_ReportRange range) {
    final now = ref.read(appClockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    return switch (range) {
      _ReportRange.today => (today, today),
      _ReportRange.week => (today.subtract(const Duration(days: 6)), today),
      _ReportRange.month => (DateTime(today.year, today.month), today),
    };
  }

  Future<({PeriodReportSnapshot report, List<Expense> expenses})> _loadReport(
    (DateTime, DateTime) bounds,
  ) async {
    final useCases = ref.read(useCasesProvider);
    return (
      report: await useCases.periodReport(start: bounds.$1, end: bounds.$2),
      expenses: await useCases.expensesReport(start: bounds.$1, end: bounds.$2),
    );
  }

  Future<void> _addExpense() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => const _ExpenseDialog(),
    );
    if (saved == true && mounted) {
      _refresh(ref);
      setState(() {});
    }
  }

  Future<void> _printCurrentReport((DateTime, DateTime) bounds) async {
    final report = await ref
        .read(useCasesProvider)
        .periodReport(start: bounds.$1, end: bounds.$2);
    await ReportSummaryPdf.printReport(
      report: report,
      settings: widget.snapshot.shopSettings,
    );
  }
}
