part of '../v2_app.dart';

class _InstallmentsView extends ConsumerStatefulWidget {
  const _InstallmentsView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  ConsumerState<_InstallmentsView> createState() => _InstallmentsViewState();
}

class _InstallmentsViewState extends ConsumerState<_InstallmentsView> {
  final _search = TextEditingController();
  _InstallmentTab _tab = _InstallmentTab.customers;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaries = widget.snapshot.installmentSummaries;
    final customerPlans = summaries
        .where((item) => item.plan.partyType == 'customer')
        .toList();
    final supplierPlans = summaries
        .where((item) => item.plan.partyType == 'supplier')
        .toList();
    final query = _search.text.trim();
    final customerRows = _customerScheduleRows(customerPlans).where((row) {
      return query.isEmpty || row.plan.partyName.contains(query);
    }).toList();
    final filteredSupplierPlans =
        supplierPlans.where((plan) {
          return query.isEmpty || plan.partyName.contains(query);
        }).toList()..sort((a, b) {
          final byRemaining = b.remainingMinor.compareTo(a.remainingMinor);
          if (byRemaining != 0) return byRemaining;
          return a.plan.createdAt.compareTo(b.plan.createdAt);
        });
    final customerRemaining = summaries
        .where((item) => item.plan.partyType == 'customer')
        .fold<int>(0, (sum, item) => sum + item.remainingMinor);
    final supplierRemaining = summaries
        .where((item) => item.plan.partyType == 'supplier')
        .fold<int>(0, (sum, item) => sum + item.remainingMinor);
    final overdue = customerRows.fold<int>(
      0,
      (sum, row) =>
          sum +
          (row.installment.isOverdue ? row.installment.remainingMinor : 0),
    );
    final dueSoon = customerRows.fold<int>(
      0,
      (sum, row) =>
          sum +
          (row.installment.isDueSoon ? row.installment.remainingMinor : 0),
    );

    return _Screen(
      title: 'الأقساط',
      subtitle: 'الأولوية حسب تاريخ السداد: المتأخر أولًا ثم الأقرب',
      trailing: SegmentedButton<_InstallmentTab>(
        selected: {_tab},
        onSelectionChanged: (selection) =>
            setState(() => _tab = selection.first),
        segments: const [
          ButtonSegment(
            value: _InstallmentTab.customers,
            icon: Icon(Icons.people),
            label: Text('عملاء'),
          ),
          ButtonSegment(
            value: _InstallmentTab.suppliers,
            icon: Icon(Icons.local_shipping),
            label: Text('موردين'),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: _tab == _InstallmentTab.customers
                  ? 'بحث باسم العميل'
                  : 'بحث باسم المورد',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _MetricsGrid(
            metrics: [
              ('متأخر', overdue, Icons.warning_amber),
              ('خلال 7 أيام', dueSoon, Icons.event_available),
              ('على العملاء', customerRemaining, Icons.people),
              ('على الموردين', supplierRemaining, Icons.local_shipping),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _GlassPane(
              child: _tab == _InstallmentTab.customers
                  ? _CustomerInstallmentsList(
                      rows: customerRows,
                      onPay: (row) => _payInstallment(
                        context,
                        ref,
                        row.plan.plan,
                        row.installment.remainingMinor,
                      ),
                    )
                  : _SupplierInstallmentsList(
                      plans: filteredSupplierPlans,
                      onPay: (preview) => _payInstallment(
                        context,
                        ref,
                        preview.plan,
                        preview.remainingMinor,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _payInstallment(
    BuildContext context,
    WidgetRef ref,
    InstallmentPlan plan,
    int remaining,
  ) async {
    final payment = await showDialog<({int amount, PaymentMethod method})>(
      context: context,
      builder: (_) => _InstallmentPaymentDialog(
        title: plan.partyType == 'customer' ? 'تحصيل قسط' : 'سداد قسط',
        initialMinor: remaining,
      ),
    );
    if (payment == null || !context.mounted) return;
    final result = await _runWithNegativeBalanceApproval(
      context,
      action: (allowNegativeBalance) => plan.partyType == 'customer'
          ? ref
                .read(useCasesProvider)
                .collectInstallment(
                  planId: plan.id,
                  amountMinor: payment.amount,
                  method: payment.method,
                )
          : ref
                .read(useCasesProvider)
                .paySupplierInstallment(
                  planId: plan.id,
                  amountMinor: payment.amount,
                  method: payment.method,
                  allowNegativeBalance: allowNegativeBalance,
                ),
    );
    if (!context.mounted) return;
    _showResult(context, result, success: 'تم تسجيل الحركة');
    _refresh(ref);
  }
}

class _CustomerInstallmentRow {
  const _CustomerInstallmentRow({
    required this.plan,
    required this.installment,
  });

  final InstallmentPlanPreview plan;
  final InstallmentSchedulePreview installment;
}

class _CustomerInstallmentsList extends StatelessWidget {
  const _CustomerInstallmentsList({required this.rows, required this.onPay});

  final List<_CustomerInstallmentRow> rows;
  final ValueChanged<_CustomerInstallmentRow> onPay;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('لا توجد أقساط عملاء مطابقة'));
    }
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = rows[index];
        return _InstallmentScheduleRow(
          preview: row.plan,
          installment: row.installment,
          onPay: () => onPay(row),
        );
      },
    );
  }
}

class _SupplierInstallmentsList extends StatelessWidget {
  const _SupplierInstallmentsList({required this.plans, required this.onPay});

  final List<InstallmentPlanPreview> plans;
  final ValueChanged<InstallmentPlanPreview> onPay;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return const Center(child: Text('لا توجد أرصدة موردين مطابقة'));
    }
    return ListView.separated(
      itemCount: plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final preview = plans[index];
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.54),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.local_shipping,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(
                    preview.partyName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Expanded(
                  child: _StackedAmount(
                    label: 'مدفوع',
                    amountMinor: preview.plan.paidMinor,
                  ),
                ),
                Expanded(
                  child: _StackedAmount(
                    label: 'المتبقي',
                    amountMinor: preview.remainingMinor,
                    strong: true,
                  ),
                ),
                FilledButton(
                  onPressed: () => onPay(preview),
                  child: const Text('سداد'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InstallmentScheduleRow extends StatelessWidget {
  const _InstallmentScheduleRow({
    required this.preview,
    required this.installment,
    this.onPay,
    this.compact = false,
  });

  final InstallmentPlanPreview preview;
  final InstallmentSchedulePreview installment;
  final VoidCallback? onPay;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = _installmentStatusLabel(installment);
    final statusColor = _installmentStatusColor(context, installment);
    final content = Row(
      children: [
        Icon(Icons.event_available, color: statusColor),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.partyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                'خطة ${preview.plan.installmentCount} أقساط · ${_date(installment.payment.dueDate)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (!compact) ...[
          Expanded(
            child: _StackedAmount(
              label: 'القسط',
              amountMinor: installment.payment.amountMinor,
            ),
          ),
          Expanded(
            child: _StackedAmount(
              label: 'مدفوع',
              amountMinor: installment.paidMinor,
            ),
          ),
        ],
        Expanded(
          child: _StackedAmount(
            label: 'المتبقي',
            amountMinor: installment.remainingMinor,
            strong: true,
          ),
        ),
        _StatusPill(label: status, color: statusColor),
        if (onPay != null) ...[
          const SizedBox(width: 10),
          FilledButton(onPressed: onPay, child: const Text('تحصيل')),
        ],
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: statusColor.withValues(
          alpha: installment.isOverdue ? 0.14 : 0.08,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.26)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 14,
          vertical: compact ? 8 : 12,
        ),
        child: content,
      ),
    );
  }
}

class _StackedAmount extends StatelessWidget {
  const _StackedAmount({
    required this.label,
    required this.amountMinor,
    this.strong = false,
  });

  final String label;
  final int amountMinor;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(
          Money(amountMinor).format(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: strong
              ? Theme.of(context).textTheme.titleSmall
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

List<_CustomerInstallmentRow> _customerScheduleRows(
  List<InstallmentPlanPreview> plans,
) {
  final rows = <_CustomerInstallmentRow>[];
  for (final plan in plans) {
    for (final installment in plan.schedule) {
      if (installment.remainingMinor <= 0) continue;
      rows.add(_CustomerInstallmentRow(plan: plan, installment: installment));
    }
  }
  rows.sort((a, b) {
    if (a.installment.isOverdue != b.installment.isOverdue) {
      return a.installment.isOverdue ? -1 : 1;
    }
    final byDate = a.installment.payment.dueDate.compareTo(
      b.installment.payment.dueDate,
    );
    if (byDate != 0) return byDate;
    return a.plan.partyName.compareTo(b.plan.partyName);
  });
  return rows;
}

String _installmentStatusLabel(InstallmentSchedulePreview installment) {
  if (installment.isOverdue) return 'متأخر';
  final due = installment.payment.dueDate;
  final now = DateTime.now();
  if (due.year == now.year && due.month == now.month && due.day == now.day) {
    return 'اليوم';
  }
  if (installment.isDueSoon) return 'قريب';
  return 'منتظر';
}

Color _installmentStatusColor(
  BuildContext context,
  InstallmentSchedulePreview installment,
) {
  if (installment.isOverdue) return Theme.of(context).colorScheme.error;
  final label = _installmentStatusLabel(installment);
  if (label == 'اليوم' || label == 'قريب') return const Color(0xFF9A6700);
  return Theme.of(context).colorScheme.primary;
}
