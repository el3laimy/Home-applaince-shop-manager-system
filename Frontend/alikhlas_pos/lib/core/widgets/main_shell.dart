import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
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
import '../../screens/purchasing_screen.dart';
import '../../screens/returns_screen.dart';
import '../../screens/reports_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/users_screen.dart';
import '../../screens/installments_screen.dart';
import '../../screens/stock_adjustments_screen.dart';
import '../../screens/expenses_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final authCtrl = Get.find<AuthController>();
    final themeCtrl = Get.put(ThemeController());
    final notifCtrl = Get.put(NotificationsController());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarWidth = _sidebarExpanded ? 260.0 : 72.0;

    final isAdmin = authCtrl.currentUser.value?.role == 'Admin';
    final isManager = authCtrl.currentUser.value?.role == 'Manager';
    final navItems = [
      ..._coreNavItems,
      if (isAdmin || isManager) _financeNavItem,
      if (isAdmin || isManager) _expensesNavItem,
      if (isAdmin || isManager) _reportsNavItem,
      if (isAdmin) _settingsNavItem,
      if (isAdmin) _adminNavItem,
      if (isAdmin || isManager) _installmentsNavItem
    ];

    return Scaffold(
      body: Row(
        children: [
          // ── Animated Sidebar ───────────────────────────────────────────────
          AnimatedContainer(
            duration: DesignTokens.kAnimDuration,
            curve: Curves.easeInOut,
            width: sidebarWidth,
            decoration: BoxDecoration(
              color: isDark ? DesignTokens.surfaceDark : Colors.white,
              border: Border(left: BorderSide(
                color: isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(30),
              )),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 60 : 15),
                  blurRadius: 24,
                  offset: const Offset(4, 0),
                )
              ],
            ),
            child: Column(
              children: [
                // ── Header ────────────────────────────────────────
                SizedBox(
                  height: 72,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Icon(Icons.diamond_rounded, color: AppTheme.primaryColor, size: 28),
                      if (_sidebarExpanded) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'إخلاص ERP',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    // Notifications Bell — only visible when expanded
                    if (_sidebarExpanded)
                      Obx(() {
                        final count = notifCtrl.unreadCount.value;
                        return Tooltip(
                          message: count > 0 ? '$count إشعار جديد' : 'لا توجد إشعارات',
                          child: Stack(
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
                              ),
                              if (count > 0)
                                Positioned(
                                  top: 4,
                                  left: 4,
                                  child: Container(
                                    width: 16, height: 16,
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    alignment: Alignment.center,
                                    child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    // Theme toggle — only visible when expanded
                    if (_sidebarExpanded)
                      Obx(() => Tooltip(
                        message: 'الوضع: ${themeCtrl.label}',
                        child: IconButton(
                          icon: Icon(themeCtrl.icon, size: 20, color: Colors.grey[500]),
                          onPressed: themeCtrl.cycle,
                          padding: EdgeInsets.zero,
                        ),
                      )),
                      IconButton(
                        icon: Icon(
                          _sidebarExpanded ? Icons.chevron_right : Icons.chevron_left,
                          color: Colors.grey[500],
                        ),
                        onPressed: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
                      ),
                    ],
                  ),
                ).animate().fade(),

                const Divider(height: 1),

                // ── Navigation Items ───────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    itemCount: navItems.length,
                    itemBuilder: (ctx, i) {
                      final item = navItems[i];
                      final isSelected = _selectedIndex == item.index;

                      return Tooltip(
                        message: _sidebarExpanded ? '' : item.label,
                        preferBelow: false,
                        child: AnimatedContainer(
                          duration: DesignTokens.kAnimDuration,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(DesignTokens.kChipRadius),
                            color: isSelected
                                ? item.color.withAlpha(isDark ? 20 : 15)
                                : Colors.transparent,
                            border: isSelected
                                ? Border(right: BorderSide(color: item.color, width: 3))
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(DesignTokens.kChipRadius),
                              splashColor: item.color.withAlpha(30),
                              hoverColor: item.color.withAlpha(10),
                              onTap: () => setState(() => _selectedIndex = item.index),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 11,
                                  horizontal: _sidebarExpanded ? 14 : 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: _sidebarExpanded
                                      ? MainAxisAlignment.start
                                      : MainAxisAlignment.center,
                                  children: [
                                    Icon(item.icon,
                                        color: isSelected
                                            ? item.color
                                            : (isDark ? Colors.grey[500] : Colors.grey[600]),
                                        size: 21),
                                    if (_sidebarExpanded) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style: TextStyle(
                                            color: isSelected
                                                ? (isDark ? Colors.white : Colors.black87)
                                                : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
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
                      ).animate().fadeIn(delay: Duration(milliseconds: 40 * i)).slideX(begin: -0.05);
                    },
                  ),
                ),

                const Divider(height: 1),

                // ── User Profile + Logout ─────────────────────────
                Obx(() {
                  final user = authCtrl.currentUser.value;
                  return Padding(
                    padding: EdgeInsets.all(_sidebarExpanded ? 16 : 8),
                    child: AnimatedContainer(
                      duration: 200.ms,
                      padding: EdgeInsets.all(_sidebarExpanded ? 12 : 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: _sidebarExpanded
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(0xFF6C63FF),
                            child: Icon(Icons.person, color: Colors.white, size: 18),
                          ),
                          if (_sidebarExpanded) ...[
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
                                  Row(children: [
                                    Container(
                                      width: 8, height: 8,
                                      margin: const EdgeInsets.only(left: 4),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Text(
                                      _roleLabel(user?.role),
                                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
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
