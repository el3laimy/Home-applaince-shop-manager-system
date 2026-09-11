part of '../v2_app.dart';

class _ReturnsView extends ConsumerStatefulWidget {
  const _ReturnsView({required this.snapshot});
  final WorkbenchSnapshot snapshot;
  @override
  ConsumerState<_ReturnsView> createState() => _ReturnsViewState();
}

class _ReturnsViewState extends ConsumerState<_ReturnsView> {
  final _search = TextEditingController();
  late Future<List<SaleInvoice>> _invoices;
  int _page = 0;
  String _query = '';
  DateTimeRange? _dates;
  bool _returning = false;

  @override
  void initState() {
    super.initState();
    _invoices = _fetch();
  }

  Future<List<SaleInvoice>> _fetch() => ref
      .read(useCasesProvider)
      .saleInvoiceHistory(
        query: _query,
        offset: _page * 20,
        limit: 21,
        createdFrom: _dates?.start,
        createdBefore: _dates == null
            ? null
            : DateTime(
                _dates!.end.year,
                _dates!.end.month,
                _dates!.end.day + 1,
              ),
      );
  void _load() {
    final next = _fetch();
    setState(() {
      _invoices = next;
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Screen(
    title: 'المرتجعات',
    subtitle: 'ابحث عن الفاتورة لعرض تفاصيلها أو طباعتها أو إنشاء مرتجع',
    child: _GlassPane(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    labelText: 'رقم الفاتورة أو اسم العميل أو هاتفه',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) {
                    _query = _search.text;
                    _page = 0;
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  _query = _search.text;
                  _page = 0;
                  _load();
                },
                child: const Text('بحث'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickDates,
                icon: const Icon(Icons.date_range),
                label: Text(
                  _dates == null
                      ? 'كل التواريخ'
                      : '${_date(_dates!.start)} — ${_date(_dates!.end)}',
                ),
              ),
              if (_dates != null)
                TextButton(
                  onPressed: () {
                    _dates = null;
                    _page = 0;
                    _load();
                  },
                  child: const Text('مسح التاريخ'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<SaleInvoice>>(
              future: _invoices,
              builder: (context, state) {
                if (state.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: _load,
                      child: const Text('تعذر تحميل الفواتير. إعادة المحاولة'),
                    ),
                  );
                }
                final rows = state.data!;
                return Column(
                  children: [
                    Expanded(
                      child: rows.isEmpty
                          ? const Center(child: Text('لا توجد فواتير مطابقة'))
                          : ListView.separated(
                              itemCount: rows.length > 20 ? 20 : rows.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final sale = rows[index];
                                return ListTile(
                                  leading: const Icon(Icons.receipt_long),
                                  title: Text(sale.invoiceNo),
                                  subtitle: Text(_dateTime(sale.createdAt)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: _returning
                                            ? null
                                            : () => _openDetails(sale),
                                        child: const Text('تفاصيل وطباعة'),
                                      ),
                                      FilledButton(
                                        onPressed: _returning
                                            ? null
                                            : () async {
                                                if (_returning) return;
                                                setState(
                                                  () => _returning = true,
                                                );
                                                try {
                                                  await _returnSale(
                                                    context,
                                                    ref,
                                                    sale,
                                                  );
                                                } catch (_) {
                                                  if (context.mounted) {
                                                    _showSnack(
                                                      context,
                                                      'تعذر إكمال المرتجع. راجع الفاتورة قبل إعادة المحاولة.',
                                                    );
                                                  }
                                                } finally {
                                                  if (mounted) {
                                                    setState(
                                                      () => _returning = false,
                                                    );
                                                  }
                                                }
                                              },
                                        child: const Text('إنشاء مرتجع'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _page == 0
                              ? null
                              : () {
                                  _page--;
                                  _load();
                                },
                          child: const Text('السابق'),
                        ),
                        Text('صفحة ${_page + 1}'),
                        TextButton(
                          onPressed: rows.length <= 20
                              ? null
                              : () {
                                  _page++;
                                  _load();
                                },
                          child: const Text('التالي'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickDates() async {
    final now = ref.read(appClockProvider)();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 10, 12, 31),
      initialDateRange: _dates,
      helpText: 'تاريخ الفواتير',
      saveText: 'تطبيق',
      confirmText: 'تطبيق',
      builder: (context, child) => Localizations.override(
        context: context,
        locale: const Locale('ar', 'EG'),
        delegates: GlobalMaterialLocalizations.delegates,
        child: child!,
      ),
    );
    if (!mounted || selected == null) return;
    _dates = selected;
    _page = 0;
    _load();
  }

  Future<void> _openDetails(SaleInvoice sale) async {
    if (_returning) return;
    setState(() => _returning = true);
    try {
      final preview = await ref
          .read(useCasesProvider)
          .saleReturnPreview(sale.id);
      if (!mounted) return;
      final createReturn = await showDialog<bool>(
        context: context,
        builder: (_) => _SaleReceiptDialog(
          receipt: preview.receipt,
          currentStatus: preview,
        ),
      );
      if (mounted && createReturn == true) {
        await _returnSale(context, ref, sale);
      }
    } catch (_) {
      if (mounted) {
        _showSnack(context, 'تعذر تحميل تفاصيل الفاتورة. أعد المحاولة.');
      }
    } finally {
      if (mounted) setState(() => _returning = false);
    }
  }

  Future<void> _returnSale(
    BuildContext context,
    WidgetRef ref,
    SaleInvoice sale,
  ) async {
    final preview = await ref.read(useCasesProvider).saleReturnPreview(sale.id);
    if (!context.mounted) return;
    if (!preview.lines.any((line) => line.returnableQty > 0)) {
      _showSnack(context, 'لا توجد قطع متاحة للمرتجع في هذه الفاتورة');
      return;
    }
    final result =
        await showDialog<
          ({
            Map<int, int> quantities,
            PaymentMethod method,
            PaymentMethod? overflowMethod,
          })
        >(
          context: context,
          builder: (_) => _ReturnDialog(preview: preview),
        );
    if (result == null || !context.mounted) return;
    final useCases = ref.read(useCasesProvider);
    final request = PendingFinancialOperation.saleReturn(
      operationKey: useCases.newSaleReturnOperationKey(),
      saleId: sale.id,
      saleItemQuantities: result.quantities,
      refundMethod: result.method,
      overflowRefundMethod: result.overflowMethod,
    );
    final appResult = await _runWithNegativeBalanceApproval(
      context,
      action: (allowNegativeBalance) => _submitPendingFinancialOperation(
        useCases,
        request,
        allowNegativeBalance: allowNegativeBalance,
      ),
      onConfirmationDeclined: () => useCases
          .discardUncommittedPendingFinancialOperation(request.operationKey),
    );
    if (!context.mounted) return;
    _showResult(context, appResult, success: 'تم تسجيل المرتجع');
    _refresh(ref);
    if (mounted) _load();
  }
}
