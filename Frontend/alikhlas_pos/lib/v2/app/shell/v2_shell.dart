part of '../v2_app.dart';

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

enum _InstallmentTab { customers, suppliers }

enum _PartyFilter { all, customers, suppliers }

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
      background: workbench.asData?.value.uiBackground,
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
      enableBlur: true,
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
