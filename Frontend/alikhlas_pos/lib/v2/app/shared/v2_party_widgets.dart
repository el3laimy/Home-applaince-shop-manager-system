part of '../v2_app.dart';

class _PartyDirectoryTile extends StatelessWidget {
  const _PartyDirectoryTile({
    required this.party,
    required this.selected,
    required this.onTap,
  });

  final PartyBalance party;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.42)
                : Colors.white.withValues(alpha: 0.58),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                party.type == 'customer' ? Icons.person : Icons.local_shipping,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_partyTypeLabel(party.type)} · ${party.phone ?? 'بدون هاتف'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('الرصيد', style: Theme.of(context).textTheme.labelSmall),
                  Text(
                    Money(party.balanceMinor).format(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartyDetailPanel extends StatelessWidget {
  const _PartyDetailPanel({
    required this.party,
    required this.plans,
    required this.statementFuture,
    required this.onStatement,
    required this.onQuickPayment,
  });

  final PartyBalance party;
  final List<InstallmentPlanPreview> plans;
  final Future<List<PartyStatementLine>> statementFuture;
  final VoidCallback onStatement;
  final VoidCallback onQuickPayment;

  @override
  Widget build(BuildContext context) {
    final remaining = plans.fold<int>(
      0,
      (sum, item) => sum + item.remainingMinor,
    );
    return _GlassPane(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                party.type == 'customer' ? Icons.person : Icons.local_shipping,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '${_partyTypeLabel(party.type)} · ${party.phone ?? 'بدون هاتف'}',
                      style: const TextStyle(color: _mutedInk),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onStatement,
                icon: const Icon(Icons.manage_search),
                label: const Text('كشف الحساب'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: plans.isEmpty ? null : onQuickPayment,
                icon: const Icon(Icons.payments),
                label: Text(party.type == 'customer' ? 'تحصيل' : 'سداد'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<PartyStatementLine>>(
            future: statementFuture,
            builder: (context, snapshot) {
              final lines = snapshot.data ?? const <PartyStatementLine>[];
              final invoices = _uniqueInvoiceDetails(lines);
              final debit = lines.fold<int>(
                0,
                (sum, line) => sum + line.debitMinor,
              );
              final credit = lines.fold<int>(
                0,
                (sum, line) => sum + line.creditMinor,
              );
              return _TextMetricsGrid(
                metrics: [
                  ('الرصيد', Money(party.balanceMinor).format(), Icons.balance),
                  ('الفواتير', invoices.length.toString(), Icons.receipt_long),
                  ('مدين', Money(debit).format(), Icons.south_west),
                  ('دائن', Money(credit).format(), Icons.north_east),
                  ('خطط مفتوحة', plans.length.toString(), Icons.payments),
                  ('متبقي أقساط', Money(remaining).format(), Icons.schedule),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _PartyInstallmentSummary(
                    partyType: party.type,
                    plans: plans,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FutureBuilder<List<PartyStatementLine>>(
                    future: statementFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final invoices = _uniqueInvoiceDetails(snapshot.data!);
                      return _PartyInvoiceSummary(invoices: invoices);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyInstallmentSummary extends StatelessWidget {
  const _PartyInstallmentSummary({
    required this.partyType,
    required this.plans,
  });

  final String partyType;
  final List<InstallmentPlanPreview> plans;

  @override
  Widget build(BuildContext context) {
    final rows = partyType == 'customer'
        ? _customerScheduleRows(plans).take(8).toList()
        : const <_CustomerInstallmentRow>[];
    return _GlassPane(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('الأقساط', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: plans.isEmpty
                ? const Center(child: Text('لا توجد خطط أقساط مفتوحة'))
                : partyType == 'customer'
                ? ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return _InstallmentScheduleRow(
                        preview: row.plan,
                        installment: row.installment,
                        compact: true,
                        onPay: null,
                      );
                    },
                  )
                : ListView.separated(
                    itemCount: plans.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('رصيد مورد مفتوح'),
                        subtitle: Text(
                          'مدفوع ${Money(plan.plan.paidMinor).format()}',
                        ),
                        trailing: Text(Money(plan.remainingMinor).format()),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PartyInvoiceSummary extends StatelessWidget {
  const _PartyInvoiceSummary({required this.invoices});

  final List<StatementInvoiceDetails> invoices;

  @override
  Widget build(BuildContext context) {
    return _GlassPane(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('آخر الفواتير', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: invoices.isEmpty
                ? const Center(child: Text('لا توجد فواتير مرتبطة'))
                : ListView.separated(
                    itemCount: invoices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final invoice = invoices[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(invoice.invoiceNo),
                        subtitle: Text(_dateTime(invoice.createdAt)),
                        trailing: Text(Money(invoice.remainingMinor).format()),
                        onTap: () =>
                            _openStatementInvoiceDetails(context, invoice),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

List<StatementInvoiceDetails> _uniqueInvoiceDetails(
  List<PartyStatementLine> lines,
) {
  final seen = <String>{};
  final invoices = <StatementInvoiceDetails>[];
  for (final line in lines.reversed) {
    final details = line.invoiceDetails;
    if (details == null) continue;
    final key = '${details.type}:${details.invoiceNo}';
    if (seen.add(key)) invoices.add(details);
  }
  return invoices;
}

String _partyTypeLabel(String type) => type == 'customer' ? 'عميل' : 'مورد';
