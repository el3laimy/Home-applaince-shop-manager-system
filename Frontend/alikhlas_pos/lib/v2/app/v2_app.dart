import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../application/v2_use_cases.dart';
import '../core/money.dart';
import '../core/result.dart';
import '../data/app_database.dart';
import '../printing/report_summary_pdf.dart';
import '../printing/sale_receipt_pdf.dart';
import 'app_theme.dart';
import 'design_tokens.dart';
import 'v2_providers.dart';

class ALIkhlasV2App extends ConsumerWidget {
  const ALIkhlasV2App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(bootstrapProvider);
    final owner = ref.watch(currentOwnerProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ALIkhlasPOS v2',
      locale: const Locale('ar', 'EG'),
      theme: buildV2Theme(),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: bootstrap.when(
        loading: () => const _BootScreen(),
        error: (error, stackTrace) => _FatalScreen(message: error.toString()),
        data: (_) => owner == null
            ? const _LoginScreen()
            : owner.mustChangePassword
            ? const _ChangePasswordScreen()
            : const _WorkbenchShell(),
      ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _FatalScreen extends StatelessWidget {
  const _FatalScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'تعذر تشغيل قاعدة البيانات\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _LoginScreen extends ConsumerStatefulWidget {
  const _LoginScreen();

  @override
  ConsumerState<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<_LoginScreen> {
  final _username = TextEditingController(text: 'owner');
  final _password = TextEditingController(text: 'owner123');
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassStage(
      child: Center(
        child: _GlassPane(
          width: 440,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'إخلاص POS',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text('نسخة أوفلاين واحدة للمالك'),
              const SizedBox(height: 24),
              TextField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'اسم المستخدم'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _login,
                child: Text(_loading ? 'جاري الدخول...' : 'دخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(useCasesProvider)
        .login(_username.text, _password.text);
    if (!mounted) return;
    switch (result) {
      case AppSuccess<User>(value: final owner):
        ref.read(currentOwnerProvider.notifier).setOwner(owner);
      case AppFailure<User>(message: final message):
        setState(() => _error = message);
    }
    if (mounted) setState(() => _loading = false);
  }
}

class _ChangePasswordScreen extends ConsumerStatefulWidget {
  const _ChangePasswordScreen();

  @override
  ConsumerState<_ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<_ChangePasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassStage(
      child: Center(
        child: _GlassPane(
          width: 460,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تغيير كلمة المرور',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('لا يمكن استخدام التطبيق بكلمة المرور الافتراضية.'),
              const SizedBox(height: 20),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                ),
                onSubmitted: (_) => _changePassword(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _changePassword,
                child: Text(_loading ? 'جاري الحفظ...' : 'حفظ ومتابعة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = 'تأكيد كلمة المرور غير مطابق');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final owner = ref.read(currentOwnerProvider)!;
    final result = await ref
        .read(useCasesProvider)
        .changePassword(owner.id, _password.text);
    if (!mounted) return;
    switch (result) {
      case AppSuccess<User>(value: final updatedOwner):
        ref.read(currentOwnerProvider.notifier).setOwner(updatedOwner);
      case AppFailure<User>(message: final message):
        setState(() => _error = message);
    }
    if (mounted) setState(() => _loading = false);
  }
}

enum _Section {
  daily,
  pos,
  inventory,
  parties,
  purchases,
  installments,
  returns,
  reports,
  backup,
  settings,
}

enum _ReportRange { today, week, month }

enum _InstallmentFilter { all, overdue, dueSoon, customers, suppliers }

enum _InventoryFilter { all, lowStock, active, inactive }

enum _InventorySort { name, lowStockFirst, price, updated }

class _WorkbenchShell extends ConsumerStatefulWidget {
  const _WorkbenchShell();

  @override
  ConsumerState<_WorkbenchShell> createState() => _WorkbenchShellState();
}

class _WorkbenchShellState extends ConsumerState<_WorkbenchShell> {
  _Section _section = _Section.daily;

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(currentOwnerProvider)!;
    final workbench = ref.watch(workbenchProvider);

    return _GlassStage(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              _SideNav(
                selected: _section,
                onSelect: (section) => setState(() => _section = section),
                owner: owner,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: workbench.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) =>
                      _GlassPane(child: Center(child: Text('$error'))),
                  data: (snapshot) =>
                      _WorkbenchContent(section: _section, snapshot: snapshot),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideNav extends ConsumerWidget {
  const _SideNav({
    required this.selected,
    required this.onSelect,
    required this.owner,
  });

  final _Section selected;
  final ValueChanged<_Section> onSelect;
  final User owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      (_Section.daily, Icons.space_dashboard, 'اليومية'),
      (_Section.pos, Icons.point_of_sale, 'البيع'),
      (_Section.inventory, Icons.inventory_2, 'المخزون'),
      (_Section.parties, Icons.people_alt, 'الأطراف'),
      (_Section.purchases, Icons.local_shipping, 'الشراء'),
      (_Section.installments, Icons.payments, 'الأقساط'),
      (_Section.returns, Icons.keyboard_return, 'المرتجعات'),
      (_Section.reports, Icons.query_stats, 'التقارير'),
      (_Section.backup, Icons.backup, 'النسخ'),
      (_Section.settings, Icons.settings, 'الإعدادات'),
    ];

    return _GlassPane(
      width: 210,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('إخلاص POS', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(owner.fullName, style: const TextStyle(color: _mutedInk)),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              children: [
                for (final item in items)
                  _NavButton(
                    selected: selected == item.$1,
                    icon: item.$2,
                    label: item.$3,
                    onTap: () => onSelect(item.$1),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(currentOwnerProvider.notifier).setOwner(null),
            icon: const Icon(Icons.logout),
            label: const Text('خروج'),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: selected
          ? Colors.white.withValues(alpha: 0.68)
          : Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(V2DesignTokens.radiusMd),
      border: Border.all(
        color: Colors.white.withValues(alpha: selected ? 0.8 : 0.08),
      ),
      boxShadow: selected ? [V2DesignTokens.softControlShadow] : null,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: V2DesignTokens.space8),
      child: DecoratedBox(
        decoration: decoration,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(V2DesignTokens.radiusMd),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(V2DesignTokens.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : V2DesignTokens.inkMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? V2DesignTokens.ink
                          : V2DesignTokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkbenchContent extends StatelessWidget {
  const _WorkbenchContent({required this.section, required this.snapshot});

  final _Section section;
  final WorkbenchSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      _Section.daily => _DailyView(snapshot: snapshot),
      _Section.pos => _PosView(snapshot: snapshot),
      _Section.inventory => _InventoryView(snapshot: snapshot),
      _Section.parties => _PartiesView(snapshot: snapshot),
      _Section.purchases => _PurchaseView(snapshot: snapshot),
      _Section.installments => _InstallmentsView(snapshot: snapshot),
      _Section.returns => _ReturnsView(snapshot: snapshot),
      _Section.reports => _ReportsView(snapshot: snapshot),
      _Section.backup => _BackupView(snapshot: snapshot),
      _Section.settings => _SettingsView(snapshot: snapshot),
    };
  }
}

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

class _PosView extends ConsumerStatefulWidget {
  const _PosView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  ConsumerState<_PosView> createState() => _PosViewState();
}

class _PosViewState extends ConsumerState<_PosView> {
  final _search = TextEditingController();
  final _cash = TextEditingController();
  final _wallet = TextEditingController();
  final _discount = TextEditingController();
  final _installmentCount = TextEditingController(text: '3');
  final _interest = TextEditingController();
  final _cart = <_CartLine>[];
  int? _customerId;

  @override
  void dispose() {
    _search.dispose();
    _cash.dispose();
    _wallet.dispose();
    _discount.dispose();
    _installmentCount.dispose();
    _interest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.snapshot.products
        .where((product) => product.isActive)
        .where((product) {
          final q = _search.text.trim();
          return q.isEmpty ||
              product.name.contains(q) ||
              (product.barcode?.contains(q) ?? false);
        })
        .toList();
    final total = _cart.fold<int>(
      0,
      (sum, line) => sum + line.qty * line.product.salePriceMinor,
    );
    final discount = _parseMoney(_discount.text);
    final cash = _parseMoney(_cash.text);
    final wallet = _parseMoney(_wallet.text);
    final paid = cash + wallet;
    final netTotal = (total - discount).clamp(0, total);
    final remaining = netTotal - paid;

    return _Screen(
      title: 'البيع',
      subtitle: 'سلة بيع كاملة مع دفع كاش/محفظة/تقسيط',
      child: Row(
        children: [
          Expanded(
            child: _GlassPane(
              child: Column(
                children: [
                  TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'بحث أو باركود',
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _addBarcodeMatch(products),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ListTile(
                          leading: const Icon(Icons.inventory_2),
                          title: Text(product.name),
                          subtitle: Text('الرصيد ${product.stockQty}'),
                          trailing: Text(
                            Money(product.salePriceMinor).format(),
                          ),
                          onTap: product.stockQty > 0
                              ? () => setState(() => _addToCart(product))
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 430,
            child: _GlassPane(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'سلة البيع',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _CartList(
                      cart: _cart,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const Divider(),
                  DropdownButtonFormField<int?>(
                    initialValue: _customerId,
                    decoration: const InputDecoration(
                      labelText: 'العميل للتقسيط',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('بدون عميل'),
                      ),
                      for (final customer in widget.snapshot.customers)
                        DropdownMenuItem<int?>(
                          value: customer.id,
                          child: Text(customer.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _customerId = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _moneyField(
                          _cash,
                          'كاش',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _moneyField(
                          _wallet,
                          'محفظة',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _moneyField(
                    _discount,
                    'خصم الفاتورة',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _installmentCount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'عدد الأقساط',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _moneyField(_interest, 'فائدة اختيارية')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AmountRow('الإجمالي قبل الخصم', total),
                  _AmountRow('الخصم', discount),
                  _AmountRow('المطلوب', netTotal, strong: true),
                  _AmountRow('المدفوع', paid),
                  _AmountRow('المتبقي', remaining < 0 ? 0 : remaining),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _cart.isEmpty ? null : () => _submitSale(total),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('تسجيل البيع'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart(Product product) {
    _CartLine? existing;
    for (final line in _cart) {
      if (line.product.id == product.id) {
        existing = line;
        break;
      }
    }
    if (existing == null) {
      _cart.add(_CartLine(product));
    } else if (existing.qty < product.stockQty) {
      existing.qty++;
    }
  }

  void _addBarcodeMatch(List<Product> products) {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    Product? match;
    for (final product in products) {
      if (product.barcode == query) {
        match = product;
        break;
      }
    }
    if (match == null) return;
    setState(() {
      _addToCart(match!);
      _search.clear();
    });
  }

  Future<void> _submitSale(int total) async {
    final cash = _parseMoney(_cash.text);
    final wallet = _parseMoney(_wallet.text);
    final discount = _parseMoney(_discount.text);
    final paid = cash + wallet;
    if (discount < 0) {
      _showSnack(context, 'الخصم لا يمكن أن يكون سالبًا');
      return;
    }
    if (discount >= total) {
      _showSnack(context, 'الخصم يجب أن يكون أقل من إجمالي الفاتورة');
      return;
    }
    final netTotal = total - discount;
    if (paid > netTotal) {
      _showSnack(context, 'المدفوع أكبر من إجمالي الفاتورة بعد الخصم');
      return;
    }
    if (cash > 0 && widget.snapshot.dashboard.openShift == null) {
      _showSnack(context, 'افتح وردية قبل البيع النقدي');
      return;
    }
    final remaining = netTotal - paid;
    if (remaining > 0 && _customerId == null) {
      _showSnack(context, 'اختر عميلًا للبيع بالتقسيط');
      return;
    }
    final terms = remaining > 0 && _customerId != null
        ? InstallmentTerms(
            partyId: _customerId!,
            count: int.tryParse(_installmentCount.text) ?? 1,
            firstDueDate: DateTime.now().add(const Duration(days: 30)),
            interestMinor: _parseMoney(_interest.text),
          )
        : null;
    final result = await ref
        .read(useCasesProvider)
        .createSale(
          customerId: _customerId,
          items: [
            for (final line in _cart)
              SaleLineInput(
                productId: line.product.id,
                qty: line.qty,
                unitPriceMinor: line.product.salePriceMinor,
              ),
          ],
          payments: [
            PaymentInput(PaymentMethod.cash, cash),
            PaymentInput(PaymentMethod.wallet, wallet),
          ],
          installmentTerms: terms,
          discountMinor: discount,
        );
    if (!mounted) return;
    _showResult(context, result, success: 'تم تسجيل البيع');
    if (result is AppSuccess<int>) {
      final receipt = await ref
          .read(useCasesProvider)
          .saleReceipt(result.value);
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _cash.clear();
        _wallet.clear();
        _discount.clear();
        _interest.clear();
      });
      _refresh(ref);
      await showDialog<void>(
        context: context,
        builder: (_) => _SaleReceiptDialog(receipt: receipt),
      );
    }
  }
}

class _InventoryView extends ConsumerStatefulWidget {
  const _InventoryView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  ConsumerState<_InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends ConsumerState<_InventoryView> {
  final _search = TextEditingController();
  _InventoryFilter _filter = _InventoryFilter.all;
  _InventorySort _sort = _InventorySort.name;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts();
    final active = widget.snapshot.products.where((p) => p.isActive).toList();
    final lowStock = active.where((p) => p.stockQty <= p.minStockQty).length;
    final inactive = widget.snapshot.products.where((p) => !p.isActive).length;
    final inventoryValue = active.fold<int>(
      0,
      (sum, product) => sum + product.stockQty * product.avgCostMinor,
    );

    return _Screen(
      title: 'المخزون',
      subtitle: 'منتجات وأسعار ورصيد وحد نقص',
      trailing: FilledButton.icon(
        onPressed: () => _openProductDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('منتج جديد'),
      ),
      child: Column(
        children: [
          _TextMetricsGrid(
            metrics: [
              (
                'الأصناف',
                widget.snapshot.products.length.toString(),
                Icons.category,
              ),
              ('ناقص', lowStock.toString(), Icons.warning_amber),
              ('معطل', inactive.toString(), Icons.block),
              (
                'قيمة المخزون',
                Money(inventoryValue).format(),
                Icons.inventory_2,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _GlassPane(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'بحث بالاسم أو الباركود أو التصنيف',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<_InventoryFilter>(
                    initialValue: _filter,
                    decoration: const InputDecoration(labelText: 'فلتر'),
                    items: const [
                      DropdownMenuItem(
                        value: _InventoryFilter.all,
                        child: Text('الكل'),
                      ),
                      DropdownMenuItem(
                        value: _InventoryFilter.lowStock,
                        child: Text('ناقص'),
                      ),
                      DropdownMenuItem(
                        value: _InventoryFilter.active,
                        child: Text('نشط'),
                      ),
                      DropdownMenuItem(
                        value: _InventoryFilter.inactive,
                        child: Text('معطل'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _filter = value ?? _filter),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<_InventorySort>(
                    initialValue: _sort,
                    decoration: const InputDecoration(labelText: 'ترتيب'),
                    items: const [
                      DropdownMenuItem(
                        value: _InventorySort.name,
                        child: Text('الاسم'),
                      ),
                      DropdownMenuItem(
                        value: _InventorySort.lowStockFirst,
                        child: Text('الأقل رصيد'),
                      ),
                      DropdownMenuItem(
                        value: _InventorySort.price,
                        child: Text('السعر'),
                      ),
                      DropdownMenuItem(
                        value: _InventorySort.updated,
                        child: Text('آخر تحديث'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _sort = value ?? _sort),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _GlassPane(
              child: products.isEmpty
                  ? const Center(child: Text('لا توجد منتجات مطابقة'))
                  : ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ListTile(
                          leading: Icon(
                            product.isActive ? Icons.inventory_2 : Icons.block,
                            color:
                                product.stockQty <= product.minStockQty &&
                                    product.isActive
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                          title: Text(product.name),
                          subtitle: Text(
                            'باركود ${product.barcode ?? '-'} · رصيد ${product.stockQty} · حد ${product.minStockQty} · تكلفة ${Money(product.avgCostMinor).format()}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(Money(product.salePriceMinor).format()),
                              IconButton(
                                tooltip: 'تعديل',
                                onPressed: () => _openProductDialog(
                                  context,
                                  ref,
                                  product: product,
                                ),
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                tooltip: 'تعطيل',
                                onPressed: product.isActive
                                    ? () async {
                                        final result = await ref
                                            .read(useCasesProvider)
                                            .deactivateProduct(product.id);
                                        if (!context.mounted) return;
                                        _showResult(
                                          context,
                                          result,
                                          success: 'تم تعطيل المنتج',
                                        );
                                        _refresh(ref);
                                      }
                                    : null,
                                icon: const Icon(Icons.power_settings_new),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<Product> _filteredProducts() {
    final query = _search.text.trim();
    final products = widget.snapshot.products.where((product) {
      final matchesQuery =
          query.isEmpty ||
          product.name.contains(query) ||
          (product.barcode?.contains(query) ?? false) ||
          (product.category?.contains(query) ?? false);
      final matchesFilter = switch (_filter) {
        _InventoryFilter.all => true,
        _InventoryFilter.lowStock =>
          product.isActive && product.stockQty <= product.minStockQty,
        _InventoryFilter.active => product.isActive,
        _InventoryFilter.inactive => !product.isActive,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    products.sort((a, b) {
      return switch (_sort) {
        _InventorySort.name => a.name.compareTo(b.name),
        _InventorySort.lowStockFirst => a.stockQty.compareTo(b.stockQty),
        _InventorySort.price => a.salePriceMinor.compareTo(b.salePriceMinor),
        _InventorySort.updated => (b.updatedAt ?? b.createdAt).compareTo(
          a.updatedAt ?? a.createdAt,
        ),
      };
    });
    return products;
  }

  Future<void> _openProductDialog(
    BuildContext context,
    WidgetRef ref, {
    Product? product,
  }) async {
    final data = await showDialog<_ProductFormData>(
      context: context,
      builder: (_) => _ProductDialog(product: product),
    );
    if (data == null || !context.mounted) return;
    final result = product == null
        ? await ref
              .read(useCasesProvider)
              .createProduct(
                name: data.name,
                barcode: data.barcode,
                category: data.category,
                salePriceMinor: data.salePriceMinor,
                openingQty: data.openingQty,
                openingCostMinor: data.openingCostMinor,
                minStockQty: data.minStockQty,
              )
        : await ref
              .read(useCasesProvider)
              .updateProduct(
                id: product.id,
                name: data.name,
                barcode: data.barcode,
                category: data.category,
                salePriceMinor: data.salePriceMinor,
                minStockQty: data.minStockQty,
              );
    if (!context.mounted) return;
    _showResult(
      context,
      result,
      success: product == null ? 'تمت إضافة المنتج' : 'تم تحديث المنتج',
    );
    _refresh(ref);
  }
}

class _PartiesView extends ConsumerWidget {
  const _PartiesView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Screen(
      title: 'العملاء والموردون',
      subtitle: 'الأرصدة هنا مشتقة من الدفتر',
      trailing: Wrap(
        spacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => _openPartyDialog(context, ref, isCustomer: true),
            icon: const Icon(Icons.person_add),
            label: const Text('عميل'),
          ),
          OutlinedButton.icon(
            onPressed: () => _openPartyDialog(context, ref, isCustomer: false),
            icon: const Icon(Icons.add_business),
            label: const Text('مورد'),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _PartyList(
              title: 'العملاء',
              balances: snapshot.customerBalances,
              onStatement: (party) => _openStatement(context, ref, party),
              onQuickPayment: (party) => _openQuickPayment(context, ref, party),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _PartyList(
              title: 'الموردون',
              balances: snapshot.supplierBalances,
              onStatement: (party) => _openStatement(context, ref, party),
              onQuickPayment: (party) => _openQuickPayment(context, ref, party),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPartyDialog(
    BuildContext context,
    WidgetRef ref, {
    required bool isCustomer,
  }) async {
    final data = await showDialog<_PartyFormData>(
      context: context,
      builder: (_) =>
          _PartyDialog(title: isCustomer ? 'عميل جديد' : 'مورد جديد'),
    );
    if (data == null || !context.mounted) return;
    final result = isCustomer
        ? await ref
              .read(useCasesProvider)
              .createCustomer(name: data.name, phone: data.phone)
        : await ref
              .read(useCasesProvider)
              .createSupplier(name: data.name, phone: data.phone);
    if (!context.mounted) return;
    _showResult(
      context,
      result,
      success: isCustomer ? 'تمت إضافة العميل' : 'تمت إضافة المورد',
    );
    _refresh(ref);
  }

  Future<void> _openStatement(
    BuildContext context,
    WidgetRef ref,
    PartyBalance party,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => _PartyStatementDialog(
        party: party,
        statementFuture: ref
            .read(useCasesProvider)
            .partyStatement(partyType: party.type, partyId: party.id),
      ),
    );
  }

  Future<void> _openQuickPayment(
    BuildContext context,
    WidgetRef ref,
    PartyBalance party,
  ) async {
    final plans = snapshot.installmentSummaries
        .where(
          (item) =>
              item.plan.partyType == party.type &&
              item.plan.partyId == party.id,
        )
        .toList();
    if (plans.isEmpty) {
      _showSnack(context, 'لا توجد خطط أقساط مفتوحة لهذا الحساب');
      return;
    }
    final payment =
        await showDialog<
          ({InstallmentPlanPreview plan, int amount, PaymentMethod method})
        >(
          context: context,
          builder: (_) => _QuickInstallmentDialog(party: party, plans: plans),
        );
    if (payment == null || !context.mounted) return;
    final result = party.type == 'customer'
        ? await ref
              .read(useCasesProvider)
              .collectInstallment(
                planId: payment.plan.plan.id,
                amountMinor: payment.amount,
                method: payment.method,
              )
        : await ref
              .read(useCasesProvider)
              .paySupplierInstallment(
                planId: payment.plan.plan.id,
                amountMinor: payment.amount,
                method: payment.method,
              );
    if (!context.mounted) return;
    _showResult(context, result, success: 'تم تسجيل الحركة');
    _refresh(ref);
  }
}

class _PurchaseView extends ConsumerStatefulWidget {
  const _PurchaseView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  ConsumerState<_PurchaseView> createState() => _PurchaseViewState();
}

class _PurchaseViewState extends ConsumerState<_PurchaseView> {
  final _search = TextEditingController();
  final _cash = TextEditingController();
  final _wallet = TextEditingController();
  final _cart = <_PurchaseCartLine>[];
  int? _supplierId;

  @override
  void dispose() {
    _search.dispose();
    _cash.dispose();
    _wallet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final products = widget.snapshot.products.where((product) {
      return query.isEmpty ||
          product.name.contains(query) ||
          (product.barcode?.contains(query) ?? false) ||
          (product.category?.contains(query) ?? false);
    }).toList();
    final total = _cart.fold<int>(
      0,
      (sum, line) => sum + line.qty * line.costMinor,
    );
    final cash = _parseMoney(_cash.text);
    final wallet = _parseMoney(_wallet.text);
    final paid = cash + wallet;
    final remaining = total - paid;
    return _Screen(
      title: 'الشراء',
      subtitle: 'فاتورة مشتريات مع تحديث WAC ودفع كاش/محفظة/آجل',
      child: Row(
        children: [
          Expanded(
            child: _GlassPane(
              child: Column(
                children: [
                  TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'بحث منتج أو باركود',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: products.isEmpty
                        ? const Center(child: Text('لا توجد منتجات مطابقة'))
                        : ListView.separated(
                            itemCount: products.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final product = products[index];
                              return ListTile(
                                leading: const Icon(Icons.inventory_2),
                                title: Text(product.name),
                                subtitle: Text(
                                  'رصيد ${product.stockQty} · تكلفة ${Money(product.avgCostMinor).format()}',
                                ),
                                trailing: IconButton(
                                  tooltip: 'إضافة للفاتورة',
                                  icon: const Icon(Icons.add),
                                  onPressed: () =>
                                      setState(() => _addToCart(product)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 430,
            child: _GlassPane(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: _supplierId,
                    decoration: const InputDecoration(
                      labelText: 'المورد عند الآجل',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('بدون مورد'),
                      ),
                      for (final supplier in widget.snapshot.suppliers)
                        DropdownMenuItem<int?>(
                          value: supplier.id,
                          child: Text(supplier.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _supplierId = value),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _PurchaseCart(
                      cart: _cart,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: _moneyField(
                          _cash,
                          'كاش',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _moneyField(
                          _wallet,
                          'محفظة',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AmountRow('الإجمالي', total, strong: true),
                  _AmountRow('المدفوع', paid),
                  _AmountRow('الآجل', remaining < 0 ? 0 : remaining),
                  if (remaining > 0 && _supplierId == null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'اختر موردًا لتسجيل الجزء الآجل',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _cart.isEmpty
                        ? null
                        : () => _submitPurchase(total),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('تسجيل الشراء'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addToCart(Product product) {
    _PurchaseCartLine? existing;
    for (final line in _cart) {
      if (line.product.id == product.id) {
        existing = line;
        break;
      }
    }
    if (existing == null) {
      _cart.add(_PurchaseCartLine(product));
    } else {
      existing.qty++;
    }
  }

  Future<void> _submitPurchase(int total) async {
    final result = await ref
        .read(useCasesProvider)
        .createPurchase(
          supplierId: _supplierId,
          items: [
            for (final line in _cart)
              PurchaseLineInput(
                productId: line.product.id,
                qty: line.qty,
                unitCostMinor: line.costMinor,
              ),
          ],
          payments: [
            PaymentInput(PaymentMethod.cash, _parseMoney(_cash.text)),
            PaymentInput(PaymentMethod.wallet, _parseMoney(_wallet.text)),
          ],
        );
    if (!mounted) return;
    _showResult(context, result, success: 'تم تسجيل الشراء');
    if (result is AppSuccess<int>) {
      setState(() {
        _cart.clear();
        _cash.clear();
        _wallet.clear();
      });
      _refresh(ref);
    }
  }
}

class _InstallmentsView extends ConsumerStatefulWidget {
  const _InstallmentsView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  ConsumerState<_InstallmentsView> createState() => _InstallmentsViewState();
}

class _InstallmentsViewState extends ConsumerState<_InstallmentsView> {
  _InstallmentFilter _filter = _InstallmentFilter.all;

  @override
  Widget build(BuildContext context) {
    final summaries = widget.snapshot.installmentSummaries;
    final filtered = summaries.where(_matchesFilter).toList();
    final customerRemaining = summaries
        .where((item) => item.plan.partyType == 'customer')
        .fold<int>(0, (sum, item) => sum + item.remainingMinor);
    final supplierRemaining = summaries
        .where((item) => item.plan.partyType == 'supplier')
        .fold<int>(0, (sum, item) => sum + item.remainingMinor);
    final overdue = summaries.fold<int>(
      0,
      (sum, item) => sum + item.overdueMinor,
    );
    final dueSoon = summaries.fold<int>(
      0,
      (sum, item) => sum + item.dueSoonMinor,
    );

    return _Screen(
      title: 'الأقساط',
      subtitle: 'تحصيل العملاء وسداد الموردين',
      trailing: _InstallmentFilterSelector(
        selected: _filter,
        onChanged: (filter) => setState(() => _filter = filter),
      ),
      child: Column(
        children: [
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
              child: filtered.isEmpty
                  ? const Center(child: Text('لا توجد خطط أقساط في هذا العرض'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final preview = filtered[index];
                        return _InstallmentPlanTile(
                          preview: preview,
                          onPay: () => _payInstallment(
                            context,
                            ref,
                            preview.plan,
                            preview.remainingMinor,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesFilter(InstallmentPlanPreview preview) {
    return switch (_filter) {
      _InstallmentFilter.all => true,
      _InstallmentFilter.overdue => preview.isOverdue,
      _InstallmentFilter.dueSoon => preview.isDueSoon,
      _InstallmentFilter.customers => preview.plan.partyType == 'customer',
      _InstallmentFilter.suppliers => preview.plan.partyType == 'supplier',
    };
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
    final result = plan.partyType == 'customer'
        ? await ref
              .read(useCasesProvider)
              .collectInstallment(
                planId: plan.id,
                amountMinor: payment.amount,
                method: payment.method,
              )
        : await ref
              .read(useCasesProvider)
              .paySupplierInstallment(
                planId: plan.id,
                amountMinor: payment.amount,
                method: payment.method,
              );
    if (!context.mounted) return;
    _showResult(context, result, success: 'تم تسجيل الحركة');
    _refresh(ref);
  }
}

class _InstallmentPlanTile extends StatelessWidget {
  const _InstallmentPlanTile({required this.preview, required this.onPay});

  final InstallmentPlanPreview preview;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final plan = preview.plan;
    final isCustomer = plan.partyType == 'customer';
    final nextDue = preview.nextDueDate == null
        ? 'لا يوجد قسط قادم'
        : '${_date(preview.nextDueDate!)} · ${Money(preview.nextDueMinor).format()}';
    return ListTile(
      leading: Icon(
        preview.isOverdue
            ? Icons.warning_amber
            : isCustomer
            ? Icons.person
            : Icons.local_shipping,
        color: preview.isOverdue
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        isCustomer
            ? 'عميل: ${preview.partyName}'
            : 'مورد: ${preview.partyName}',
      ),
      subtitle: Wrap(
        spacing: 10,
        runSpacing: 4,
        children: [
          Text('${plan.installmentCount} قسط'),
          Text('مدفوع ${Money(plan.paidMinor).format()}'),
          Text('التالي $nextDue'),
          if (preview.overdueMinor > 0)
            Text(
              'متأخر ${Money(preview.overdueMinor).format()}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (preview.dueSoonMinor > 0)
            Text('قريب ${Money(preview.dueSoonMinor).format()}'),
        ],
      ),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            Money(preview.remainingMinor).format(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          FilledButton(
            onPressed: onPay,
            child: Text(isCustomer ? 'تحصيل' : 'سداد'),
          ),
        ],
      ),
    );
  }
}

class _InstallmentFilterSelector extends StatelessWidget {
  const _InstallmentFilterSelector({
    required this.selected,
    required this.onChanged,
  });

  final _InstallmentFilter selected;
  final ValueChanged<_InstallmentFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_InstallmentFilter>(
      selected: {selected},
      onSelectionChanged: (selection) => onChanged(selection.first),
      segments: const [
        ButtonSegment(
          value: _InstallmentFilter.all,
          icon: Icon(Icons.list_alt),
          label: Text('الكل'),
        ),
        ButtonSegment(
          value: _InstallmentFilter.overdue,
          icon: Icon(Icons.warning_amber),
          label: Text('متأخر'),
        ),
        ButtonSegment(
          value: _InstallmentFilter.dueSoon,
          icon: Icon(Icons.event_available),
          label: Text('قريب'),
        ),
        ButtonSegment(
          value: _InstallmentFilter.customers,
          icon: Icon(Icons.people),
          label: Text('عملاء'),
        ),
        ButtonSegment(
          value: _InstallmentFilter.suppliers,
          icon: Icon(Icons.local_shipping),
          label: Text('موردين'),
        ),
      ],
    );
  }
}

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
    final appResult = await ref
        .read(useCasesProvider)
        .createSaleReturn(
          saleId: sale.id,
          saleItemQuantities: result.quantities,
          refundMethod: result.method,
        );
    if (!context.mounted) return;
    _showResult(context, appResult, success: 'تم تسجيل المرتجع');
    _refresh(ref);
  }
}

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
    final now = DateTime.now();
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

class _BackupView extends ConsumerWidget {
  const _BackupView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupStatus = snapshot.backupStatus;
    return _Screen(
      title: 'النسخ الاحتياطي',
      subtitle: 'نسخة يدوية ويومية تلقائية عند اختيار مجلد',
      child: _GlassPane(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoLine('مجلد النسخ', backupStatus.directory ?? 'لم يتم اختياره'),
            _InfoLine('آخر نسخة يومية', backupStatus.lastDate ?? 'لا يوجد'),
            _InfoLine(
              'آخر ملف',
              backupStatus.latestBackupPath == null
                  ? 'لا يوجد'
                  : _fileName(backupStatus.latestBackupPath!),
            ),
            _InfoLine(
              'الاحتفاظ',
              '${backupStatus.backupCount}/${backupStatus.retentionCopies} نسخة',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => _manualBackup(context, ref),
                  icon: const Icon(Icons.backup),
                  label: const Text('نسخ الآن'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _chooseBackupDirectory(context, ref),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('اختيار المجلد'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _restoreBackup(context, ref),
                  icon: const Icon(Icons.restore),
                  label: const Text('استرجاع نسخة'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseBackupDirectory(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'اختر مجلد النسخ الاحتياطي',
    );
    if (!context.mounted || directoryPath == null) return;
    await ref.read(useCasesProvider).setBackupDirectory(directoryPath);
    if (!context.mounted) return;
    _showSnack(context, 'تم اختيار مجلد النسخ الاحتياطي');
    _refresh(ref);
  }

  Future<void> _manualBackup(BuildContext context, WidgetRef ref) async {
    var directoryPath = snapshot.backupStatus.directory;
    if (directoryPath == null || directoryPath.trim().isEmpty) {
      directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مجلد النسخ الاحتياطي',
      );
      if (!context.mounted || directoryPath == null) return;
      await ref.read(useCasesProvider).setBackupDirectory(directoryPath);
    }
    try {
      final useCases = ref.read(useCasesProvider);
      final backup = await useCases.backupToDirectory(Directory(directoryPath));
      if (!context.mounted) return;
      _showSnack(context, 'تم إنشاء النسخة: ${_fileName(backup.path)}');
      _refresh(ref);
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'تعذر إنشاء النسخة: $error');
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'اختر ملف النسخة الاحتياطية',
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (!context.mounted ||
        picked == null ||
        picked.files.single.path == null) {
      return;
    }
    final backupPath = picked.files.single.path!;
    final confirmed = await _confirm(
      context,
      title: 'استرجاع نسخة احتياطية',
      message:
          'سيتم استبدال قاعدة البيانات الحالية بالملف ${_fileName(backupPath)}. تأكد أن لديك نسخة حديثة قبل المتابعة، ثم أعد تشغيل التطبيق بعد الاسترجاع.',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(useCasesProvider).restoreFromBackup(File(backupPath));
      if (!context.mounted) return;
      _showSnack(
        context,
        'تم الاسترجاع. أعد تشغيل التطبيق لفتح الملف المسترجع.',
      );
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'تعذر الاسترجاع: $error');
    }
  }
}

class _SettingsView extends ConsumerStatefulWidget {
  const _SettingsView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  ConsumerState<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<_SettingsView> {
  late final _shopName = TextEditingController(
    text: widget.snapshot.shopSettings.shopName,
  );
  late final _phone = TextEditingController(
    text: widget.snapshot.shopSettings.phone ?? '',
  );
  late final _address = TextEditingController(
    text: widget.snapshot.shopSettings.address ?? '',
  );
  late final _footer = TextEditingController(
    text: widget.snapshot.shopSettings.receiptFooter ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _shopName.dispose();
    _phone.dispose();
    _address.dispose();
    _footer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Screen(
      title: 'الإعدادات',
      subtitle: 'بيانات المحل والفاتورة والنسخ الاحتياطي',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final form = _GlassPane(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'بيانات المحل',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _shopName,
                    decoration: const InputDecoration(labelText: 'اسم المحل'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'الهاتف'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _footer,
                    decoration: const InputDecoration(
                      labelText: 'تذييل الفاتورة',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save),
                      label: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
                    ),
                  ),
                ],
              ),
            ),
          );
          final summary = _GlassPane(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ملخص التشغيل',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _InfoLine('اسم المحل', widget.snapshot.shopSettings.shopName),
                _InfoLine(
                  'الهاتف',
                  widget.snapshot.shopSettings.phone ?? 'غير مسجل',
                ),
                _InfoLine(
                  'العنوان',
                  widget.snapshot.shopSettings.address ?? 'غير مسجل',
                ),
                const Divider(height: 24),
                _InfoLine(
                  'مجلد النسخ',
                  widget.snapshot.backupStatus.directory ?? 'لم يتم اختياره',
                ),
                _InfoLine(
                  'آخر نسخة يومية',
                  widget.snapshot.backupStatus.lastDate ?? 'لا يوجد',
                ),
                _InfoLine(
                  'آخر ملف',
                  widget.snapshot.backupStatus.latestBackupPath == null
                      ? 'لا يوجد'
                      : _fileName(
                          widget.snapshot.backupStatus.latestBackupPath!,
                        ),
                ),
                _InfoLine(
                  'الاحتفاظ',
                  '${widget.snapshot.backupStatus.backupCount}/${widget.snapshot.backupStatus.retentionCopies} نسخة',
                ),
              ],
            ),
          );

          if (constraints.maxWidth < 860) {
            return SingleChildScrollView(
              child: Column(
                children: [form, const SizedBox(height: 14), summary],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: form),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: summary),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await ref
        .read(useCasesProvider)
        .updateShopSettings(
          shopName: _shopName.text,
          phone: _phone.text,
          address: _address.text,
          receiptFooter: _footer.text,
        );
    if (!mounted) return;
    _showResult(context, result, success: 'تم حفظ الإعدادات');
    setState(() => _saving = false);
    _refresh(ref);
  }
}

class _Screen extends StatelessWidget {
  const _Screen({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineLarge),
                  Text(subtitle, style: const TextStyle(color: _mutedInk)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: child),
      ],
    );
  }
}

class _GlassStage extends StatelessWidget {
  const _GlassStage({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: V2DesignTokens.stageGradient),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _LiquidBackdropPainter()),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _GlassPane extends StatelessWidget {
  const _GlassPane({
    required this.child,
    this.width,
    this.padding,
    this.enableBlur = true,
  });

  final Widget child;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final radius = V2DesignTokens.radiusXlBorder;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: V2DesignTokens.glassWhite,
        borderRadius: radius,
        border: Border.all(color: V2DesignTokens.glassStroke),
        boxShadow: [V2DesignTokens.softPaneShadow],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: V2DesignTokens.paneHighlight,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(V2DesignTokens.space16),
            child: child,
          ),
        ),
      ),
    );
    final pane = ClipRRect(
      borderRadius: radius,
      child: enableBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: surface,
            )
          : surface,
    );
    return width == null ? pane : SizedBox(width: width, child: pane);
  }
}

class _LiquidBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mintGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              V2DesignTokens.mint.withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.18, size.height * 0.22),
              radius: size.shortestSide * 0.45,
            ),
          );
    final copperGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              V2DesignTokens.copper.withValues(alpha: 0.12),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.82, size.height * 0.78),
              radius: size.shortestSide * 0.5,
            ),
          );
    canvas
      ..drawRect(Offset.zero & size, mintGlow)
      ..drawRect(Offset.zero & size, copperGlow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});
  final List<(String, int, IconData)> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 112,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final item = metrics[index];
        return _GlassPane(
          enableBlur: false,
          child: Row(
            children: [
              Icon(item.$3, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _mutedInk),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        Money(item.$2).format(),
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TextMetricsGrid extends StatelessWidget {
  const _TextMetricsGrid({required this.metrics});
  final List<(String, String, IconData)> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 112,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final item = metrics[index];
        return _GlassPane(
          enableBlur: false,
          child: Row(
            children: [
              Icon(item.$3, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _mutedInk),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        item.$2,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CartLine {
  _CartLine(this.product);
  final Product product;
  int qty = 1;
}

class _PurchaseCartLine {
  _PurchaseCartLine(this.product)
    : costMinor = product.avgCostMinor == 0
          ? product.salePriceMinor
          : product.avgCostMinor;
  final Product product;
  int qty = 1;
  int costMinor;
}

class _CartList extends StatelessWidget {
  const _CartList({required this.cart, required this.onChanged});
  final List<_CartLine> cart;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) return const Center(child: Text('السلة فارغة'));
    return ListView.builder(
      itemCount: cart.length,
      itemBuilder: (context, index) {
        final line = cart[index];
        return ListTile(
          dense: true,
          title: Text(line.product.name),
          subtitle: Text(Money(line.product.salePriceMinor).format()),
          trailing: _QtyStepper(
            qty: line.qty,
            maxQty: line.product.stockQty,
            onChanged: (qty) {
              line.qty = qty;
              onChanged();
            },
            onRemove: () {
              cart.removeAt(index);
              onChanged();
            },
          ),
        );
      },
    );
  }
}

class _PurchaseCart extends StatelessWidget {
  const _PurchaseCart({required this.cart, required this.onChanged});
  final List<_PurchaseCartLine> cart;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) return const Center(child: Text('فاتورة الشراء فارغة'));
    return ListView.builder(
      itemCount: cart.length,
      itemBuilder: (context, index) {
        final line = cart[index];
        return ListTile(
          dense: true,
          title: Text(line.product.name),
          subtitle: SizedBox(
            width: 150,
            child: TextFormField(
              initialValue: _minorToInputText(line.costMinor),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'تكلفة الوحدة'),
              onChanged: (value) {
                line.costMinor = _parseMoney(value);
                onChanged();
              },
            ),
          ),
          trailing: _QtyStepper(
            qty: line.qty,
            maxQty: 9999,
            onChanged: (qty) {
              line.qty = qty;
              onChanged();
            },
            onRemove: () {
              cart.removeAt(index);
              onChanged();
            },
          ),
        );
      },
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.qty,
    required this.maxQty,
    required this.onChanged,
    required this.onRemove,
    this.minQty = 1,
  });

  final int qty;
  final int minQty;
  final int maxQty;
  final ValueChanged<int> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: 'إنقاص',
          onPressed: qty > minQty ? () => onChanged(qty - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(width: 32, child: Center(child: Text('$qty'))),
        IconButton(
          tooltip: 'زيادة',
          onPressed: qty < maxQty ? () => onChanged(qty + 1) : null,
          icon: const Icon(Icons.add),
        ),
        IconButton(
          tooltip: 'حذف',
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

class _PartyList extends StatelessWidget {
  const _PartyList({
    required this.title,
    required this.balances,
    required this.onStatement,
    required this.onQuickPayment,
  });
  final String title;
  final List<PartyBalance> balances;
  final ValueChanged<PartyBalance> onStatement;
  final ValueChanged<PartyBalance> onQuickPayment;

  @override
  Widget build(BuildContext context) {
    return _GlassPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: balances.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final party = balances[index];
                return ListTile(
                  title: Text(party.name),
                  subtitle: Text(party.phone ?? 'بدون هاتف'),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(Money(party.balanceMinor).format()),
                      IconButton(
                        tooltip: 'كشف حساب',
                        onPressed: () => onStatement(party),
                        icon: const Icon(Icons.manage_search),
                      ),
                      IconButton(
                        tooltip: party.type == 'customer' ? 'تحصيل' : 'سداد',
                        onPressed: () => onQuickPayment(party),
                        icon: const Icon(Icons.payments),
                      ),
                    ],
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

class _PartyStatementDialog extends StatelessWidget {
  const _PartyStatementDialog({
    required this.party,
    required this.statementFuture,
  });

  final PartyBalance party;
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TextMetricsGrid(
                  metrics: [
                    ('مدين', Money(debit).format(), Icons.arrow_downward),
                    ('دائن', Money(credit).format(), Icons.arrow_upward),
                    (
                      'الرصيد',
                      Money(party.balanceMinor).format(),
                      Icons.account_balance,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: lines.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(line.entry.description),
                        subtitle: Text(_dateTime(line.entry.createdAt)),
                        trailing: SizedBox(
                          width: 310,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _StatementAmount(
                                label: 'مدين',
                                amountMinor: line.debitMinor,
                              ),
                              const SizedBox(width: 12),
                              _StatementAmount(
                                label: 'دائن',
                                amountMinor: line.creditMinor,
                              ),
                              const SizedBox(width: 12),
                              _StatementAmount(
                                label: 'الرصيد',
                                amountMinor: line.balanceMinor,
                                strong: true,
                              ),
                            ],
                          ),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
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

class _QuickInstallmentDialog extends StatefulWidget {
  const _QuickInstallmentDialog({required this.party, required this.plans});

  final PartyBalance party;
  final List<InstallmentPlanPreview> plans;

  @override
  State<_QuickInstallmentDialog> createState() =>
      _QuickInstallmentDialogState();
}

class _QuickInstallmentDialogState extends State<_QuickInstallmentDialog> {
  late InstallmentPlanPreview _plan = widget.plans.first;
  late final _amount = TextEditingController(
    text: _minorToInputText(_plan.remainingMinor),
  );
  PaymentMethod _method = PaymentMethod.cash;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.party.type == 'customer' ? 'تحصيل سريع' : 'سداد سريع'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<InstallmentPlanPreview>(
              initialValue: _plan,
              decoration: const InputDecoration(labelText: 'خطة الأقساط'),
              items: [
                for (final plan in widget.plans)
                  DropdownMenuItem(
                    value: plan,
                    child: Text(
                      '${_date(plan.nextDueDate ?? plan.plan.createdAt)} · متبقي ${Money(plan.remainingMinor).format()}',
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _plan = value;
                  _amount.text = _minorToInputText(value.remainingMinor);
                });
              },
            ),
            const SizedBox(height: 10),
            _moneyField(_amount, 'القيمة'),
            const SizedBox(height: 10),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'طريقة الدفع'),
              items: const [
                DropdownMenuItem(value: PaymentMethod.cash, child: Text('كاش')),
                DropdownMenuItem(
                  value: PaymentMethod.wallet,
                  child: Text('محفظة'),
                ),
              ],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            plan: _plan,
            amount: _parseMoney(_amount.text),
            method: _method,
          )),
          child: Text(widget.party.type == 'customer' ? 'تحصيل' : 'سداد'),
        ),
      ],
    );
  }
}

class _SaleReceiptDialog extends StatefulWidget {
  const _SaleReceiptDialog({required this.receipt});
  final SaleReceiptSnapshot receipt;

  @override
  State<_SaleReceiptDialog> createState() => _SaleReceiptDialogState();
}

class _SaleReceiptDialogState extends State<_SaleReceiptDialog> {
  bool _printing = false;

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    return AlertDialog(
      title: Text(
        '${receipt.shopSettings.shopName} · ${receipt.invoice.invoiceNo}',
      ),
      content: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (receipt.shopSettings.phone != null ||
                receipt.shopSettings.address != null) ...[
              _GlassPane(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (receipt.shopSettings.phone != null)
                      _InfoLine('هاتف المحل', receipt.shopSettings.phone!),
                    if (receipt.shopSettings.address != null)
                      _InfoLine('العنوان', receipt.shopSettings.address!),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: _ReceiptInfoBlock(
                    label: 'العميل',
                    value: receipt.customerName ?? 'نقدي',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ReceiptInfoBlock(
                    label: 'التاريخ',
                    value: _dateTime(receipt.invoice.createdAt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _GlassPane(
                padding: const EdgeInsets.all(12),
                child: receipt.lines.isEmpty
                    ? const Center(child: Text('لا توجد سطور في الفاتورة'))
                    : ListView.separated(
                        itemCount: receipt.lines.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final line = receipt.lines[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(line.productName),
                            subtitle: Text(
                              '${line.qty} × ${Money(line.unitPriceMinor).format()}',
                            ),
                            trailing: Text(Money(line.lineTotalMinor).format()),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (final payment in receipt.payments)
                        _InfoLine(
                          _paymentMethodText(payment.method),
                          Money(payment.amountMinor).format(),
                        ),
                      if (receipt.payments.isEmpty)
                        const _InfoLine('الدفع', 'بدون دفعة فورية'),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      _AmountRow('الإجمالي', receipt.invoice.subtotalMinor),
                      if (receipt.invoice.discountMinor > 0)
                        _AmountRow('الخصم', receipt.invoice.discountMinor),
                      if (receipt.invoice.interestMinor > 0)
                        _AmountRow('الفائدة', receipt.invoice.interestMinor),
                      _AmountRow('المطلوب', receipt.invoice.totalMinor),
                      _AmountRow('المدفوع', receipt.invoice.paidMinor),
                      _AmountRow(
                        'المتبقي',
                        receipt.invoice.remainingMinor,
                        strong: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (receipt.shopSettings.receiptFooter != null) ...[
              const SizedBox(height: 8),
              Text(
                receipt.shopSettings.receiptFooter!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _mutedInk),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _printing ? null : () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
        FilledButton.icon(
          onPressed: _printing ? null : _print,
          icon: const Icon(Icons.print),
          label: Text(_printing ? 'جاري الطباعة...' : 'طباعة'),
        ),
      ],
    );
  }

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      await SaleReceiptPdf.printReceipt(widget.receipt);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
}

class _ReceiptInfoBlock extends StatelessWidget {
  const _ReceiptInfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _mutedInk)),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.product});
  final Product? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _barcode = TextEditingController(
    text: widget.product?.barcode ?? '',
  );
  late final _category = TextEditingController(
    text: widget.product?.category ?? '',
  );
  late final _price = TextEditingController(
    text: widget.product == null
        ? ''
        : _minorToInputText(widget.product!.salePriceMinor),
  );
  late final _qty = TextEditingController(
    text: widget.product?.stockQty.toString() ?? '0',
  );
  late final _cost = TextEditingController(
    text: widget.product == null
        ? ''
        : _minorToInputText(widget.product!.avgCostMinor),
  );
  late final _min = TextEditingController(
    text: widget.product?.minStockQty.toString() ?? '1',
  );

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _category.dispose();
    _price.dispose();
    _qty.dispose();
    _cost.dispose();
    _min.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'منتج جديد' : 'تعديل منتج'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم المنتج'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcode,
                    decoration: const InputDecoration(labelText: 'باركود'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _category,
                    decoration: const InputDecoration(labelText: 'تصنيف'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _moneyField(_price, 'سعر البيع')),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'حد النقص'),
                  ),
                ),
              ],
            ),
            if (widget.product == null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'رصيد افتتاحي',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _moneyField(_cost, 'تكلفة افتتاحية')),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ProductFormData(
              name: _name.text,
              barcode: _barcode.text,
              category: _category.text,
              salePriceMinor: _parseMoney(_price.text),
              openingQty: int.tryParse(_qty.text) ?? 0,
              openingCostMinor: _parseMoney(_cost.text),
              minStockQty: int.tryParse(_min.text) ?? 1,
            ),
          ),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _ProductFormData {
  const _ProductFormData({
    required this.name,
    required this.barcode,
    required this.category,
    required this.salePriceMinor,
    required this.openingQty,
    required this.openingCostMinor,
    required this.minStockQty,
  });

  final String name;
  final String barcode;
  final String category;
  final int salePriceMinor;
  final int openingQty;
  final int openingCostMinor;
  final int minStockQty;
}

class _PartyDialog extends StatefulWidget {
  const _PartyDialog({required this.title});
  final String title;

  @override
  State<_PartyDialog> createState() => _PartyDialogState();
}

class _PartyDialogState extends State<_PartyDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'الاسم'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'الهاتف'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _PartyFormData(_name.text, _phone.text)),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _PartyFormData {
  const _PartyFormData(this.name, this.phone);
  final String name;
  final String phone;
}

class _InstallmentPaymentDialog extends StatefulWidget {
  const _InstallmentPaymentDialog({
    required this.title,
    required this.initialMinor,
  });

  final String title;
  final int initialMinor;

  @override
  State<_InstallmentPaymentDialog> createState() =>
      _InstallmentPaymentDialogState();
}

class _InstallmentPaymentDialogState extends State<_InstallmentPaymentDialog> {
  late final _amount = TextEditingController(
    text: _minorToInputText(widget.initialMinor),
  );
  PaymentMethod _method = PaymentMethod.cash;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _moneyField(_amount, 'القيمة'),
            const SizedBox(height: 8),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'طريقة الدفع'),
              items: [
                const DropdownMenuItem(
                  value: PaymentMethod.cash,
                  child: Text('كاش'),
                ),
                DropdownMenuItem(
                  value: PaymentMethod.wallet,
                  child: Text('محفظة'),
                ),
              ],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            amount: _parseMoney(_amount.text),
            method: _method,
          )),
          child: const Text('تسجيل'),
        ),
      ],
    );
  }
}

class _ReturnDialog extends StatefulWidget {
  const _ReturnDialog({required this.preview});
  final SaleReturnPreview preview;

  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  late final Map<int, int> _quantities = {
    for (final line in widget.preview.lines) line.saleItemId: 0,
  };
  PaymentMethod _method = PaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    final selected = _quantities.entries
        .where((entry) => entry.value > 0)
        .fold<int>(0, (sum, entry) => sum + entry.value);
    final refund = widget.preview.lines.fold<int>(
      0,
      (sum, line) =>
          sum + ((_quantities[line.saleItemId] ?? 0) * line.unitPriceMinor),
    );
    return AlertDialog(
      title: const Text('إنشاء مرتجع'),
      content: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ReceiptInfoBlock(
                    label: 'الفاتورة',
                    value: widget.preview.receipt.invoice.invoiceNo,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ReceiptInfoBlock(
                    label: 'العميل',
                    value: widget.preview.receipt.customerName ?? 'نقدي',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _GlassPane(
                padding: const EdgeInsets.all(12),
                child: ListView.separated(
                  itemCount: widget.preview.lines.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final line = widget.preview.lines[index];
                    final qty = _quantities[line.saleItemId] ?? 0;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(line.productName),
                      subtitle: Text(
                        'مباع ${line.soldQty} · مرتجع سابق ${line.returnedQty} · متاح ${line.returnableQty}',
                      ),
                      trailing: _QtyStepper(
                        qty: qty,
                        minQty: 0,
                        maxQty: line.returnableQty,
                        onChanged: (value) => setState(
                          () => _quantities[line.saleItemId] = value,
                        ),
                        onRemove: () =>
                            setState(() => _quantities[line.saleItemId] = 0),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'طريقة الرد'),
              items: [
                const DropdownMenuItem(
                  value: PaymentMethod.cash,
                  child: Text('كاش'),
                ),
                const DropdownMenuItem(
                  value: PaymentMethod.wallet,
                  child: Text('محفظة'),
                ),
                if (widget.preview.receipt.invoice.customerId != null)
                  const DropdownMenuItem(
                    value: PaymentMethod.installment,
                    child: Text('خصم من العميل'),
                  ),
              ],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
            const SizedBox(height: 12),
            _InfoLine('عدد القطع المختارة', selected.toString()),
            _AmountRow('قيمة المرتجع', refund, strong: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: selected == 0
              ? null
              : () => Navigator.pop(context, (
                  quantities: Map<int, int>.fromEntries(
                    _quantities.entries.where((entry) => entry.value > 0),
                  ),
                  method: _method,
                )),
          child: const Text('تسجيل'),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.amountMinor, {this.strong = false});
  final String label;
  final int amountMinor;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(Money(amountMinor).format(), style: style),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(color: _mutedInk)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

const _mutedInk = V2DesignTokens.inkMuted;

TextField _moneyField(
  TextEditingController controller,
  String label, {
  ValueChanged<String>? onChanged,
}) {
  return TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    onChanged: onChanged,
  );
}

int _parseMoney(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return 0;
  final negative = normalized.startsWith('-');
  final unsigned = negative ? normalized.substring(1) : normalized;
  final parts = unsigned.split('.');
  final pounds =
      int.tryParse(parts.first.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  final fraction = parts.length > 1
      ? parts[1].replaceAll(RegExp(r'[^0-9]'), '')
      : '';
  final centsText = fraction.padRight(2, '0').substring(0, 2);
  final cents = int.tryParse(centsText) ?? 0;
  final minor = (pounds * 100) + cents;
  return negative ? -minor : minor;
}

String _minorToInputText(int minorUnits) {
  final negative = minorUnits < 0;
  final absolute = minorUnits.abs();
  final pounds = absolute ~/ 100;
  final cents = (absolute % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$pounds.$cents';
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _dateTime(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${_time(value)}';

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _fileName(String path) => File(path).uri.pathSegments.last;

Future<void> _openSaleReceipt(
  BuildContext context,
  WidgetRef ref,
  int saleId,
) async {
  final receipt = await ref.read(useCasesProvider).saleReceipt(saleId);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _SaleReceiptDialog(receipt: receipt),
  );
}

String _paymentMethodText(PaymentMethod method) {
  return switch (method) {
    PaymentMethod.cash => 'كاش',
    PaymentMethod.wallet => 'محفظة',
    PaymentMethod.installment => 'تقسيط',
  };
}

void _refresh(WidgetRef ref) {
  ref.invalidate(workbenchProvider);
  ref.invalidate(dashboardProvider);
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void _showResult<T>(
  BuildContext context,
  AppResult<T> result, {
  required String success,
}) {
  switch (result) {
    case AppSuccess<T>():
      _showSnack(context, success);
    case AppFailure<T>(message: final message):
      _showSnack(context, message);
  }
}

Future<int?> _askMoney(
  BuildContext context, {
  required String title,
  int? initialMinor,
}) {
  final controller = TextEditingController(
    text: initialMinor == null ? '' : _minorToInputText(initialMinor),
  );
  return showDialog<int>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: _moneyField(controller, 'القيمة'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _parseMoney(controller.text)),
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> ensureArabicFormatting() =>
    initializeDateFormatting('ar_EG', null);
