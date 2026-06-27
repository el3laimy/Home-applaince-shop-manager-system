part of '../v2_app.dart';

class _PartyStatementDialog extends StatelessWidget {
  const _PartyStatementDialog({
    required this.party,
    required this.settings,
    required this.statementFuture,
  });

  final PartyBalance party;
  final ShopSettingsSnapshot settings;
  final Future<List<PartyStatementLine>> statementFuture;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('كشف حساب ${party.name}'),
      content: SizedBox(
        width: 760,
        height: 520,
        child: FutureBuilder<List<PartyStatementLine>>(
          future: statementFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final lines = snapshot.data!;
            if (lines.isEmpty) {
              return const Center(child: Text('لا توجد حركات لهذا الحساب'));
            }
            final debit = lines.fold<int>(
              0,
              (sum, line) => sum + line.debitMinor,
            );
            final credit = lines.fold<int>(
              0,
              (sum, line) => sum + line.creditMinor,
            );
            final balanceLabel = party.type == 'supplier'
                ? 'رصيد المورد'
                : 'رصيد العميل';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TextMetricsGrid(
                  metrics: [
                    ('الحركات', lines.length.toString(), Icons.receipt_long),
                    ('مدين', Money(debit).format(), Icons.arrow_downward),
                    ('دائن', Money(credit).format(), Icons.arrow_upward),
                    (
                      balanceLabel,
                      Money(party.balanceMinor).format(),
                      Icons.account_balance,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: lines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      return _StatementMovementTile(
                        line: line,
                        onOpenDetails: line.invoiceDetails == null
                            ? null
                            : () => _openStatementInvoiceDetails(
                                context,
                                line.invoiceDetails!,
                              ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        FutureBuilder<List<PartyStatementLine>>(
          future: statementFuture,
          builder: (context, snapshot) {
            final lines = snapshot.data;
            return FilledButton.icon(
              onPressed: lines == null
                  ? null
                  : () => PartyStatementPdf.printStatement(
                      party: party,
                      statement: lines,
                      settings: settings,
                    ),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('تصدير PDF'),
            );
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

class _StatementMovementTile extends StatefulWidget {
  const _StatementMovementTile({required this.line, this.onOpenDetails});

  final PartyStatementLine line;
  final VoidCallback? onOpenDetails;

  @override
  State<_StatementMovementTile> createState() => _StatementMovementTileState();
}

class _StatementMovementTileState extends State<_StatementMovementTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final details = widget.line.invoiceDetails;
    final isInteractive = details != null && widget.onOpenDetails != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isInteractive ? widget.onOpenDetails : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _hovered ? 0.58 : 0.46),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      _statementIcon(widget.line.entry.referenceType),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _StatementMovementText(line: widget.line)),
                    if (isInteractive) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: widget.onOpenDetails,
                        icon: const Icon(Icons.visibility),
                        label: const Text('تفاصيل'),
                      ),
                    ],
                    const SizedBox(width: 10),
                    _StatementAmount(
                      label: 'مدين',
                      amountMinor: widget.line.debitMinor,
                    ),
                    const SizedBox(width: 12),
                    _StatementAmount(
                      label: 'دائن',
                      amountMinor: widget.line.creditMinor,
                    ),
                    const SizedBox(width: 12),
                    _StatementAmount(
                      label: 'الرصيد',
                      amountMinor: widget.line.balanceMinor,
                      strong: true,
                    ),
                  ],
                ),
                if (_hovered && details != null) ...[
                  const SizedBox(height: 10),
                  _StatementInvoicePreview(details: details),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatementMovementText extends StatelessWidget {
  const _StatementMovementText({required this.line});

  final PartyStatementLine line;

  @override
  Widget build(BuildContext context) {
    final details = line.invoiceDetails;
    final title = details == null
        ? _statementReferenceLabel(line.entry.referenceType)
        : '${_statementReferenceLabel(line.entry.referenceType)} ${details.invoiceNo}';
    final subtitle = details == null
        ? line.entry.description
        : _statementInvoiceSummaryText(details);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(subtitle),
        Text(
          _dateTime(line.entry.createdAt),
          style: const TextStyle(color: _mutedInk),
        ),
      ],
    );
  }
}

class _StatementInvoicePreview extends StatelessWidget {
  const _StatementInvoicePreview({required this.details});

  final StatementInvoiceDetails details;

  @override
  Widget build(BuildContext context) {
    final items = details.items.take(3).toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.54)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _MiniInfo(
                  details.discountMinor > 0 ? 'قبل الخصم' : 'الإجمالي',
                  Money(_statementInvoiceSubtotal(details)).format(),
                ),
                if (details.discountMinor > 0)
                  _MiniInfo('الخصم', Money(details.discountMinor).format()),
                if (details.interestMinor > 0)
                  _MiniInfo('الفائدة', Money(details.interestMinor).format()),
                if (details.discountMinor > 0 || details.interestMinor > 0)
                  _MiniInfo('الصافي', Money(details.totalMinor).format()),
                _MiniInfo('المدفوع', Money(details.paidMinor).format()),
                _MiniInfo('المتبقي', Money(details.remainingMinor).format()),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Text(
                '${item.productName} · ${item.qty} × ${Money(item.unitMinor).format()} = ${Money(item.lineTotalMinor).format()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (details.items.length > items.length)
              Text(
                'و${details.items.length - items.length} أصناف أخرى...',
                style: const TextStyle(color: _mutedInk),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text('$label: $value', style: Theme.of(context).textTheme.bodySmall);
  }
}

String _statementInvoiceSummaryText(StatementInvoiceDetails details) {
  final parts = <String>[
    'إجمالي الأصناف ${Money(_statementInvoiceSubtotal(details)).format()}',
    if (details.discountMinor > 0)
      'خصم ${Money(details.discountMinor).format()}',
    if (details.interestMinor > 0)
      'فائدة ${Money(details.interestMinor).format()}',
    'الصافي ${Money(details.totalMinor).format()}',
    'المدفوع ${Money(details.paidMinor).format()}',
    'المتبقي ${Money(details.remainingMinor).format()}',
  ];
  return parts.join(' · ');
}

int _statementInvoiceSubtotal(StatementInvoiceDetails details) {
  return details.subtotalMinor ??
      details.items.fold<int>(0, (sum, item) => sum + item.lineTotalMinor);
}

List<(String, String, IconData)> _statementInvoiceDetailMetrics(
  StatementInvoiceDetails details,
) {
  final metrics = <(String, String, IconData)>[
    (
      details.discountMinor > 0 ? 'إجمالي الأصناف' : 'الإجمالي',
      Money(_statementInvoiceSubtotal(details)).format(),
      Icons.receipt_long,
    ),
    if (details.discountMinor > 0)
      ('خصم الفاتورة', Money(details.discountMinor).format(), Icons.sell),
    if (details.interestMinor > 0)
      ('فائدة التقسيط', Money(details.interestMinor).format(), Icons.percent),
    if (details.discountMinor > 0 || details.interestMinor > 0)
      ('صافي الفاتورة', Money(details.totalMinor).format(), Icons.calculate),
    ('المدفوع', Money(details.paidMinor).format(), Icons.payments),
    ('المتبقي', Money(details.remainingMinor).format(), Icons.account_balance),
    ('التاريخ', _dateTime(details.createdAt), Icons.event),
  ];
  return metrics;
}

Future<void> _openStatementInvoiceDetails(
  BuildContext context,
  StatementInvoiceDetails details,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _StatementInvoiceDetailsDialog(details: details),
  );
}

class _StatementInvoiceDetailsDialog extends StatelessWidget {
  const _StatementInvoiceDetailsDialog({required this.details});

  final StatementInvoiceDetails details;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${details.type == 'purchase' ? 'تفاصيل فاتورة شراء' : 'تفاصيل فاتورة بيع'} ${details.invoiceNo}',
      ),
      content: SizedBox(
        width: 760,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TextMetricsGrid(metrics: _statementInvoiceDetailMetrics(details)),
            const SizedBox(height: 12),
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'الأصناف'),
                        Tab(text: 'المدفوعات'),
                        Tab(text: 'الأقساط'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _StatementInvoiceItems(details: details),
                          _StatementInvoicePayments(details: details),
                          _StatementInvoiceInstallments(details: details),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

class _StatementInvoiceItems extends StatelessWidget {
  const _StatementInvoiceItems({required this.details});

  final StatementInvoiceDetails details;

  @override
  Widget build(BuildContext context) {
    if (details.items.isEmpty) {
      return const Center(child: Text('لا توجد أصناف'));
    }
    return ListView.separated(
      itemCount: details.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = details.items[index];
        return ListTile(
          dense: true,
          title: Text(item.productName),
          subtitle: Text('${item.qty} × ${Money(item.unitMinor).format()}'),
          trailing: Text(Money(item.lineTotalMinor).format()),
        );
      },
    );
  }
}

class _StatementInvoicePayments extends StatelessWidget {
  const _StatementInvoicePayments({required this.details});

  final StatementInvoiceDetails details;

  @override
  Widget build(BuildContext context) {
    if (details.payments.isEmpty) {
      return const Center(child: Text('لا توجد دفعات فورية'));
    }
    return ListView.separated(
      itemCount: details.payments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final payment = details.payments[index];
        return ListTile(
          dense: true,
          leading: Icon(
            payment.method == PaymentMethod.cash
                ? Icons.payments
                : Icons.account_balance_wallet,
          ),
          title: Text(_paymentMethodText(payment.method)),
          subtitle: Text(_dateTime(payment.createdAt)),
          trailing: Text(Money(payment.amountMinor).format()),
        );
      },
    );
  }
}

class _StatementInvoiceInstallments extends StatelessWidget {
  const _StatementInvoiceInstallments({required this.details});

  final StatementInvoiceDetails details;

  @override
  Widget build(BuildContext context) {
    if (details.installments.isEmpty) {
      return const Center(child: Text('لا توجد خطة أقساط'));
    }
    return ListView.separated(
      itemCount: details.installments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final installment = details.installments[index];
        final paidLabel = installment.paidAt == null
            ? 'غير مدفوع'
            : 'مدفوع ${_date(installment.paidAt!)}';
        return ListTile(
          dense: true,
          leading: Icon(
            installment.status == 'paid' ? Icons.check_circle : Icons.schedule,
          ),
          title: Text(Money(installment.amountMinor).format()),
          subtitle: Text('استحقاق ${_date(installment.dueDate)} · $paidLabel'),
        );
      },
    );
  }
}

String _statementReferenceLabel(String referenceType) {
  return switch (referenceType) {
    'sale' => 'فاتورة بيع',
    'purchase' => 'فاتورة شراء',
    'installment_collection' => 'تحصيل قسط',
    'supplier_installment_payment' => 'سداد مورد',
    'sale_return' => 'مرتجع بيع',
    'expense' => 'مصروف',
    _ => 'حركة دفتر',
  };
}

IconData _statementIcon(String referenceType) {
  return switch (referenceType) {
    'sale' => Icons.point_of_sale,
    'purchase' => Icons.local_shipping,
    'installment_collection' => Icons.payments,
    'supplier_installment_payment' => Icons.payments,
    'sale_return' => Icons.keyboard_return,
    'expense' => Icons.money_off,
    _ => Icons.receipt_long,
  };
}

class _StatementAmount extends StatelessWidget {
  const _StatementAmount({
    required this.label,
    required this.amountMinor,
    this.strong = false,
  });

  final String label;
  final int amountMinor;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: strong ? Theme.of(context).colorScheme.primary : _mutedInk,
      fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
      fontSize: 12,
    );
    return SizedBox(
      width: 86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: style),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(Money(amountMinor).format(), style: style),
          ),
        ],
      ),
    );
  }
}
