import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/design_tokens.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../controllers/notifications_controller.dart';
import '../../screens/dashboard_screen.dart';
import '../../screens/pos_screen.dart';
import '../../screens/inventory_screen.dart';
import '../../screens/purchasing_screen.dart';
import '../../screens/finance_screen.dart';
import '../../screens/bridal_screen.dart';
import '../../screens/customers_screen.dart';
import '../../screens/suppliers_screen.dart';

import '../../screens/returns_screen.dart';
import '../../screens/reports_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/users_screen.dart';
import '../../screens/installments_screen.dart';
import '../../screens/stock_adjustments_screen.dart';
import '../../screens/expenses_screen.dart';
import '../../screens/audit_trail_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const PosScreen(),
    const InventoryScreen(),
    const StockAdjustmentsScreen(), // index 3
    const CustomersScreen(),
    const SuppliersScreen(), // index 5
    const PurchasingScreen(), // index 6
    ReturnsScreen(), // 7
    const FinanceScreen(), // 8
    ExpensesScreen(), // 9
    const BridalOrdersScreen(), // 10
    const ReportsScreen(), // 11
    const SettingsScreen(), // 12
    const UsersScreen(), // 13 — Admin only
    const InstallmentsScreen(), // 14 — Admin or Manager only
    const AuditTrailScreen(), // 15 — Admin only
  ];

  final List<_NavItem> _coreNavItems = [
    _NavItem(0, 'لوحة القيادة', Icons.dashboard_rounded, Color(0xFF6C63FF)),
    _NavItem(1, 'نقطة البيع (POS)', Icons.point_of_sale_rounded, Color(0xFF00E5FF)),
    _NavItem(2, 'إدارة المخزون', Icons.inventory_2_rounded, Color(0xFF43E97B)),
    _NavItem(3, 'تسوية المخزون', Icons.inventory_rounded, Color(0xFFFBBC05)),
    _NavItem(4, 'العملاء', Icons.people_alt_rounded, Color(0xFF4FACFE)),
    _NavItem(5, 'الموردين والديون', Icons.domain, Color(0xFFFA709A)),
    _NavItem(6, 'فواتير المشتريات', Icons.local_shipping_rounded, Color(0xFF00B4D8)),
    _NavItem(7, 'إدارة المرتجعات', Icons.assignment_return_rounded, Color(0xFFFF5E5E)),
    _NavItem(10, 'طلبيات العرائس', Icons.auto_awesome_rounded, Color(0xFFF093FB)),
  ];

  static const _financeNavItem = _NavItem(8, 'الخزينة والمحاسبة', Icons.account_balance_wallet_rounded, Color(0xFFFFB800));
  static const _expensesNavItem = _NavItem(9, 'إدارة المصروفات', Icons.receipt_long, Colors.deepOrangeAccent);
  static const _reportsNavItem = _NavItem(11, 'التقارير التحليلية', Icons.insights_rounded, Color(0xFF6C63FF));
  static const _settingsNavItem = _NavItem(12, 'إعدادات النظام', Icons.settings_rounded, Color(0xFF9E9E9E));

  static const _adminNavItem = _NavItem(13, 'المستخدمون', Icons.manage_accounts_rounded, Colors.purple);
  static const _installmentsNavItem = _NavItem(14, 'الأقساط', Icons.payments_rounded, Colors.deepOrange);
  static const _auditTrailNavItem = _NavItem(15, 'سجل المراجعة', Icons.history_rounded, Color(0xFFFF9800));

  @override
  Widget build(BuildContext context) {
    final authCtrl = Get.find<AuthController>();
    final themeCtrl = Get.put(ThemeController());
    final notifCtrl = Get.put(NotificationsController());

    final isAdmin = authCtrl.currentUser.value?.role == 'Admin';
    final isManager = authCtrl.currentUser.value?.role == 'Manager';
    final navItems = [
      ..._coreNavItems,
      if (isAdmin || isManager) _financeNavItem,
      if (isAdmin || isManager) _expensesNavItem,
      if (isAdmin || isManager) _reportsNavItem,
      if (isAdmin) _settingsNavItem,
      if (isAdmin) _adminNavItem,
      if (isAdmin || isManager) _installmentsNavItem,
      if (isAdmin) _auditTrailNavItem,
    ];

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Auto-collapse sidebar on narrow windows
          final isWindowNarrow = constraints.maxWidth < 900;
          final effectiveExpanded = isWindowNarrow ? false : _sidebarExpanded;
          final sidebarWidth = effectiveExpanded ? 260.0 : 72.0;

          return Row(
        children: [
          // ── Neo-Glass Sidebar ─────────────────────────────────────────────
          RepaintBoundary(
            child: AnimatedContainer(
              duration: DesignTokens.kAnimDuration,
              curve: Curves.easeInOut,
              width: sidebarWidth,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(DesignTokens.kNeoPanelRadius),
                  bottomLeft: Radius.circular(DesignTokens.kNeoPanelRadius),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    decoration: BoxDecoration(
                      color: DesignTokens.glassBg,
                      border: Border(
                        left: BorderSide(color: DesignTokens.glassBorder),
                        top: BorderSide(color: DesignTokens.glassBorder),
                        bottom: BorderSide(color: DesignTokens.glassBorder),
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(DesignTokens.kNeoPanelRadius),
                        bottomLeft: Radius.circular(DesignTokens.kNeoPanelRadius),
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x4D000000), blurRadius: 20, offset: Offset(10, 10)),
                        BoxShadow(color: Color(0x0DFFFFFF), blurRadius: 5, spreadRadius: -2),
                      ],
                    ),
                    child: Column(
                      children: [
                        // ── Logo Header ─────────────────────────────────
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: effectiveExpanded ? 20 : 12,
                            vertical: 20,
                          ),
                          child: Row(
                            children: [
                              // Gradient Rocket Icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF06B6D4), Color(0xFF9333EA)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF06B6D4).withAlpha(50),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 22),
                              ),
                              if (effectiveExpanded) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DesignTokens.holographicText(
                                    text: 'إخلاص ERP',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                              ],
                              // Notifications Bell
                              if (effectiveExpanded)
                                Obx(() {
                                  final count = notifCtrl.unreadCount.value;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          count > 0 ? Icons.notifications_active_rounded : Icons.notifications_rounded,
                                          size: 20,
                                          color: count > 0 ? Colors.orange : Colors.grey[500],
                                        ),
                                        onPressed: () => _showNotificationsDialog(context, notifCtrl),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      if (count > 0)
                                        Positioned(
                                          top: -2,
                                          left: -2,
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: DesignTokens.neonPinkAlt,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: DesignTokens.neonPinkAlt.withAlpha(180),
                                                  blurRadius: 10,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                }),
                              // Theme toggle
                              if (effectiveExpanded)
                                Obx(() => IconButton(
                                  icon: Icon(themeCtrl.icon, size: 18, color: Colors.grey[500]),
                                  onPressed: themeCtrl.cycle,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )),
                              if (!isWindowNarrow)
                                IconButton(
                                  icon: Icon(
                                    _sidebarExpanded ? Icons.chevron_right : Icons.chevron_left,
                                    color: Colors.grey[500],
                                    size: 18,
                                  ),
                                  onPressed: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        ).animate().fade(),

                        // Divider
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: Colors.white.withAlpha(10),
                        ),

                        // ── Navigation Items ───────────────────────────
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            itemCount: navItems.length,
                            itemBuilder: (ctx, i) {
                              final item = navItems[i];
                              final isSelected = _selectedIndex == item.index;

                              return Tooltip(
                                message: effectiveExpanded ? '' : item.label,
                                preferBelow: false,
                                child: AnimatedContainer(
                                  duration: DesignTokens.kAnimDuration,
                                  margin: const EdgeInsets.only(bottom: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: isSelected
                                        ? Colors.white.withAlpha(25)
                                        : Colors.transparent,
                                    boxShadow: isSelected
                                        ? [BoxShadow(color: DesignTokens.neonCyan.withAlpha(50), blurRadius: 15)]
                                        : null,
                                    border: isSelected
                                        ? Border(right: BorderSide(color: DesignTokens.neonCyan, width: 4))
                                        : null,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      splashColor: item.color.withAlpha(30),
                                      hoverColor: Colors.white.withAlpha(13),
                                      onTap: () => setState(() => _selectedIndex = item.index),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: effectiveExpanded ? 16 : 0,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: effectiveExpanded
                                              ? MainAxisAlignment.start
                                              : MainAxisAlignment.center,
                                          children: [
                                            Icon(item.icon,
                                                color: isSelected
                                                    ? DesignTokens.neonCyan
                                                    : Colors.grey[500],
                                                size: 21),
                                            if (effectiveExpanded) ...[
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Text(
                                                  item.label,
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? Colors.white
                                                        : Colors.grey[400],
                                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                    fontSize: 13,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ).animate().fadeIn(delay: Duration(milliseconds: 30 * i)).slideX(begin: -0.03);
                            },
                          ),
                        ),

                        // Divider
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: Colors.white.withAlpha(10),
                        ),

                        // ── User Profile (Neo-Glass) ──────────────────
                        Obx(() {
                          final user = authCtrl.currentUser.value;
                          return Padding(
                            padding: EdgeInsets.all(effectiveExpanded ? 16 : 8),
                            child: Container(
                              padding: EdgeInsets.all(effectiveExpanded ? 14 : 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(13),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withAlpha(13)),
                              ),
                              child: Row(
                                mainAxisAlignment: effectiveExpanded
                                    ? MainAxisAlignment.start
                                    : MainAxisAlignment.center,
                                children: [
                                  // Avatar with cyan border
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: DesignTokens.neonCyan.withAlpha(80),
                                        width: 2,
                                      ),
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF6C63FF), Color(0xFF9333EA)],
                                      ),
                                    ),
                                    child: const Icon(Icons.person, color: Colors.white, size: 18),
                                  ),
                                  if (effectiveExpanded) ...[
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user?.fullName ?? 'مستخدم',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            _roleLabel(user?.role),
                                            style: TextStyle(color: Colors.grey[400], fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.settings, size: 16, color: Colors.grey[500]),
                                      tooltip: 'الإعدادات',
                                      onPressed: () => setState(() => _selectedIndex = 12),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
                                      tooltip: 'تسجيل الخروج',
                                      onPressed: () => _confirmLogout(context, authCtrl),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Main Content Area ──────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_selectedIndex),
                        child: _screens[_selectedIndex],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
          );
        },
      ),
    );
  }

  String _roleLabel(String? role) => switch (role) {
        'Admin' => 'مدير',
        'Manager' => 'مشرف',
        'Cashier' => 'كاشير',
        _ => 'متصل',
      };

  void _showNotificationsDialog(BuildContext ctx, NotificationsController notifCtrl) {
    notifCtrl.markAllRead();
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 420,
          child: Obx(() {
            final notifs = notifCtrl.notifications;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.notifications_rounded, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('الإشعارات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ]),
                ),
                const Divider(height: 1),
                // Notifications list
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: notifs.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                            SizedBox(height: 12),
                            Text('لا توجد إشعارات جديدة', style: TextStyle(color: Colors.grey)),
                          ]),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                          itemCount: notifs.length,
                          itemBuilder: (ctx, i) {
                            final n = notifs[i];
                            final isInstallment = n.type == 'installment';
                            final color = n.isWarning ? Colors.red : (isInstallment ? Colors.orange : Colors.amber);
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withAlpha(30),
                                child: Icon(isInstallment ? Icons.payments_rounded : Icons.inventory_2_rounded, color: color, size: 20),
                              ),
                              title: Text(n.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: Text(n.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              trailing: n.isWarning ? const Icon(Icons.warning_rounded, color: Colors.red, size: 18) : null,
                            );
                          },
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton.icon(
                    onPressed: () { Navigator.pop(ctx); notifCtrl.fetchNotifications(); },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('تحديث'),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext ctx, AuthController authCtrl) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من النظام؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              authCtrl.logout();
            },
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final int index;
  final String label;
  final IconData icon;
  final Color color;
  const _NavItem(this.index, this.label, this.icon, this.color);
}
