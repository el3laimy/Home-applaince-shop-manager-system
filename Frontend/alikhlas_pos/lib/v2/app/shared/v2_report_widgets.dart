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

class _PeriodReportPanel extends StatelessWidget {
  const _PeriodReportPanel({required this.report});
  final PeriodReportSnapshot report;

  @override
  Widget build(BuildContext context) {
    return _GlassPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.query_stats,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تفاصيل الفترة',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${_date(report.start)} إلى ${_date(report.end.subtract(const Duration(days: 1)))}',
                style: const TextStyle(color: _mutedInk),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CountBadge(label: 'بيع', count: report.saleCount),
              _CountBadge(label: 'شراء', count: report.purchaseCount),
              _CountBadge(label: 'مرتجع', count: report.returnCount),
            ],
          ),
          const SizedBox(height: 14),
          _AmountRow('المبيعات', report.salesMinor),
          _AmountRow('تكلفة المبيعات', report.cogsMinor),
          _AmountRow('المصروفات', report.expensesMinor),
          if (report.interestMinor > 0)
            _AmountRow('فوائد تقسيط العملاء', report.interestMinor),
          const Divider(height: 22),
          _AmountRow('ربح الفترة', report.profitMinor, strong: true),
          const SizedBox(height: 10),
          _AmountRow('صافي حركة الكاش', report.cashNetMinor),
          _AmountRow('صافي حركة المحفظة', report.walletNetMinor),
          _AmountRow('مشتريات دخلت المخزون', report.purchaseMinor),
        ],
      ),
    );
  }
}

class _ExpensesPanel extends StatelessWidget {
  const _ExpensesPanel({required this.expenses});
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    return _GlassPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.money_off,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'مصروفات الفترة',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                Money(
                  expenses.fold<int>(
                    0,
                    (sum, expense) => sum + expense.amountMinor,
                  ),
                ).format(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: expenses.isEmpty
                ? const Center(child: Text('لا توجد مصروفات في هذه الفترة'))
                : ListView.separated(
                    itemCount: expenses.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      return ListTile(
                        dense: true,
                        title: Text(expense.description),
                        subtitle: Text(
                          '${_dateTime(expense.createdAt)} · ${_paymentMethodText(PaymentMethod.values.byName(expense.method))}',
                        ),
                        trailing: Text(Money(expense.amountMinor).format()),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseDialog extends ConsumerStatefulWidget {
  const _ExpenseDialog();

  @override
  ConsumerState<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends ConsumerState<_ExpenseDialog> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('مصروف جديد'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'وصف المصروف',
                prefixIcon: Icon(Icons.description),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            _moneyField(_amount, 'المبلغ'),
            const SizedBox(height: 10),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(
                labelText: 'طريقة الدفع',
                prefixIcon: Icon(Icons.payments),
              ),
              items: const [
                DropdownMenuItem(value: PaymentMethod.cash, child: Text('كاش')),
                DropdownMenuItem(
                  value: PaymentMethod.wallet,
                  child: Text('محفظة'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _method = value ?? _method),
            ),
            const SizedBox(height: 10),
            Text(
              _method == PaymentMethod.cash
                  ? 'المصروف النقدي يحتاج وردية مفتوحة.'
                  : 'مصروف المحفظة لا يحتاج وردية مفتوحة.',
              style: const TextStyle(color: _mutedInk, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('حفظ المصروف'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final description = _description.text.trim();
    if (description.isEmpty) {
      _showSnack(context, 'وصف المصروف مطلوب');
      return;
    }
    final amount = _requireMoney(context, _amount, 'المبلغ');
    if (amount == null) return;
    if (amount <= 0) {
      _showSnack(context, 'قيمة المصروف يجب أن تكون أكبر من صفر');
      return;
    }

    setState(() => _saving = true);
    final result = await _runWithNegativeBalanceApproval(
      context,
      action: (allowNegativeBalance) => ref
          .read(useCasesProvider)
          .recordExpense(
            description: description,
            amountMinor: amount,
            method: _method,
            allowNegativeBalance: allowNegativeBalance,
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case AppSuccess<int>():
        _showSnack(context, 'تم تسجيل المصروف');
        Navigator.pop(context, true);
      case AppFailure<int>(message: final message):
        _showSnack(context, message);
    }
  }
}

class _ReportRangeSelector extends StatelessWidget {
  const _ReportRangeSelector({required this.selected, required this.onChanged});

  final _ReportRange selected;
  final ValueChanged<_ReportRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_ReportRange>(
      selected: {selected},
      onSelectionChanged: (selection) => onChanged(selection.first),
      segments: const [
        ButtonSegment(
          value: _ReportRange.today,
          icon: Icon(Icons.today),
          label: Text('اليوم'),
        ),
        ButtonSegment(
          value: _ReportRange.week,
          icon: Icon(Icons.date_range),
          label: Text('7 أيام'),
        ),
        ButtonSegment(
          value: _ReportRange.month,
          icon: Icon(Icons.calendar_month),
          label: Text('الشهر'),
        ),
      ],
    );
  }
}

class _InventoryValuationPanel extends StatelessWidget {
  const _InventoryValuationPanel({
    required this.products,
    required this.ledgerInventoryMinor,
  });

  final List<Product> products;
  final int ledgerInventoryMinor;

  @override
  Widget build(BuildContext context) {
    final active = products.where((product) => product.isActive).toList();
    final units = active.fold<int>(0, (sum, product) => sum + product.stockQty);
    final calculatedValue = active.fold<int>(
      0,
      (sum, product) => sum + (product.stockQty * product.avgCostMinor),
    );
    final lowStock = active
        .where((product) => product.stockQty <= product.minStockQty)
        .length;

    return _GlassPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تقييم المخزون',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _CountBadge(label: 'أصناف', count: active.length),
            ],
          ),
          const SizedBox(height: 14),
          _AmountRow('القيمة من الدفتر', ledgerInventoryMinor, strong: true),
          _AmountRow('القيمة من رصيد الأصناف', calculatedValue),
          const Divider(height: 22),
          _InfoLine('إجمالي الوحدات', units.toString()),
          _InfoLine('أصناف تحت الحد', lowStock.toString()),
          const SizedBox(height: 4),
          Expanded(
            child: active.isEmpty
                ? const Center(child: Text('لا توجد منتجات نشطة'))
                : ListView.separated(
                    itemCount: active.take(5).length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final product = active[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(product.name),
                        subtitle: Text('الرصيد ${product.stockQty}'),
                        trailing: Text(
                          Money(
                            product.stockQty * product.avgCostMinor,
                          ).format(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecentInvoicesPanel extends StatelessWidget {
  const _RecentInvoicesPanel({
    required this.sales,
    required this.purchases,
    required this.onSaleOpen,
  });

  final List<SaleInvoice> sales;
  final List<PurchaseInvoice> purchases;
  final ValueChanged<SaleInvoice> onSaleOpen;

  @override
  Widget build(BuildContext context) {
    return _GlassPane(
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'آخر الفواتير',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const TabBar(
              tabs: [
                Tab(text: 'بيع'),
                Tab(text: 'شراء'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _SaleInvoiceList(sales: sales, onOpen: onSaleOpen),
                  _PurchaseInvoiceList(purchases: purchases),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleInvoiceList extends StatelessWidget {
  const _SaleInvoiceList({required this.sales, required this.onOpen});
  final List<SaleInvoice> sales;
  final ValueChanged<SaleInvoice> onOpen;

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) return const Center(child: Text('لا توجد فواتير بيع'));
    return ListView.separated(
      itemCount: sales.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final sale = sales[index];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(sale.invoiceNo),
          subtitle: Text(_dateTime(sale.createdAt)),
          trailing: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(Money(sale.totalMinor).format()),
              IconButton(
                tooltip: 'عرض الفاتورة',
                onPressed: () => onOpen(sale),
                icon: const Icon(Icons.print),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PurchaseInvoiceList extends StatelessWidget {
  const _PurchaseInvoiceList({required this.purchases});
  final List<PurchaseInvoice> purchases;

  @override
  Widget build(BuildContext context) {
    if (purchases.isEmpty) {
      return const Center(child: Text('لا توجد فواتير شراء'));
    }
    return ListView.separated(
      itemCount: purchases.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final purchase = purchases[index];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(purchase.invoiceNo),
          subtitle: Text(_dateTime(purchase.createdAt)),
          trailing: Text(Money(purchase.totalMinor).format()),
        );
      },
    );
  }
}

class _DueInstallmentsPanel extends StatelessWidget {
  const _DueInstallmentsPanel({required this.installments});
  final List<InstallmentDuePreview> installments;

  @override
  Widget build(BuildContext context) {
    return _GlassPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_available,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الأقساط القريبة',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _CountBadge(label: 'مستحق', count: installments.length),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: installments.isEmpty
                ? const Center(child: Text('لا توجد أقساط قريبة'))
                : ListView.separated(
                    itemCount: installments.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = installments[index];
                      final partyType = item.plan.partyType == 'customer'
                          ? 'عميل'
                          : 'مورد';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          item.isOverdue
                              ? Icons.warning_amber
                              : Icons.calendar_month,
                          color: item.isOverdue
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                        title: Text('$partyType: ${item.partyName}'),
                        subtitle: Text(
                          '${_date(item.payment.dueDate)} · متبقي ${Money(item.remainingMinor).format()}',
                        ),
                        trailing: Text(
                          Money(item.payment.amountMinor).format(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          '$label $count',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
