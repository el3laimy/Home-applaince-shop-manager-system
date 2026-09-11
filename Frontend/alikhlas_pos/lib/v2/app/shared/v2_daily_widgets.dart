part of '../v2_app.dart';

class _LowStockList extends StatelessWidget {
  const _LowStockList({required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final low = products
        .where((p) => p.isActive && p.stockQty <= p.minStockQty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'تنبيه نقص المخزون',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: low.isEmpty
              ? const Center(child: Text('لا توجد أصناف ناقصة'))
              : ListView.separated(
                  itemCount: low.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = low[index];
                    return ListTile(
                      title: Text(product.name),
                      trailing: Text(
                        '${product.stockQty}/${product.minStockQty}',
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RecentLedger extends StatelessWidget {
  const _RecentLedger({required this.entries});
  final List<LedgerEntryPreview> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('آخر القيود', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Expanded(
          child: entries.isEmpty
              ? const Center(child: Text('لا توجد قيود بعد'))
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final preview = entries[index];
                    return ListTile(
                      dense: true,
                      title: Text(preview.entry.description),
                      subtitle: Text(_dateTime(preview.entry.createdAt)),
                      trailing: Text(Money(preview.debitMinor).format()),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DailySummaryPanel extends StatelessWidget {
  const _DailySummaryPanel({required this.summary});
  final DailySummarySnapshot summary;

  @override
  Widget build(BuildContext context) {
    return _GlassPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.today, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ملخص اليوم',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CountBadge(label: 'بيع', count: summary.saleCount),
              _CountBadge(label: 'شراء', count: summary.purchaseCount),
              _CountBadge(label: 'مرتجع', count: summary.returnCount),
            ],
          ),
          const SizedBox(height: 14),
          _AmountRow('المبيعات', summary.salesMinor),
          _AmountRow('تكلفة المبيعات', summary.cogsMinor),
          _AmountRow('المصروفات', summary.expensesMinor),
          if (summary.inventoryVarianceMinor != 0)
            _AmountRow('فروق الجرد', summary.inventoryVarianceMinor),
          if (summary.interestMinor > 0)
            _AmountRow('فوائد تقسيط العملاء', summary.interestMinor),
          const Divider(height: 22),
          _AmountRow('ربح اليوم', summary.profitMinor, strong: true),
          const SizedBox(height: 10),
          _AmountRow('صافي حركة الكاش', summary.cashNetMinor),
          _AmountRow('صافي حركة المحفظة', summary.walletNetMinor),
          _AmountRow('مشتريات دخلت المخزون', summary.purchaseMinor),
        ],
      ),
    );
  }
}

class _DailyAlertsPanel extends StatelessWidget {
  const _DailyAlertsPanel({required this.snapshot});

  final WorkbenchSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final overdue = snapshot.dueInstallments.where((item) {
      return item.payment.dueDate.isBefore(todayStart);
    }).length;
    final dueToday = snapshot.dueInstallments.where((item) {
      final due = item.payment.dueDate;
      return due.year == todayStart.year &&
          due.month == todayStart.month &&
          due.day == todayStart.day;
    }).length;
    final lowStock = snapshot.products
        .where(
          (product) =>
              product.isActive && product.stockQty <= product.minStockQty,
        )
        .length;
    final latestBackup = snapshot.backupStatus.latestBackupPath == null
        ? 'لا توجد نسخة بعد'
        : _fileName(snapshot.backupStatus.latestBackupPath!);

    return _GlassPane(
      child: Row(
        children: [
          Expanded(
            child: _AlertChip(
              icon: Icons.warning_amber,
              label: 'أقساط متأخرة',
              value: overdue.toString(),
              urgent: overdue > 0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AlertChip(
              icon: Icons.event_available,
              label: 'مستحق اليوم',
              value: dueToday.toString(),
              urgent: dueToday > 0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AlertChip(
              icon: Icons.inventory_2,
              label: 'أصناف ناقصة',
              value: lowStock.toString(),
              urgent: lowStock > 0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AlertChip(
              icon: Icons.backup,
              label: 'آخر نسخة',
              value: latestBackup,
              urgent: snapshot.backupStatus.latestBackupPath == null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.urgent,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final color = urgent
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(V2DesignTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: _mutedInk)),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
