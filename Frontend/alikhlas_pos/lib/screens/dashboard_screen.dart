import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/auth_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/formatters.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(DashboardController());
    final authCtrl = Get.find<AuthController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: DesignTokens.pageBackground(isDark: isDark),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.kPagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, authCtrl, isDark),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Main Column ──
                    Expanded(
                      flex: 7,
                      child: Column(
                        children: [
                          _buildStatCards(context, ctrl, isDark),
                          const SizedBox(height: 20),
                          Expanded(child: _buildSalesChart(context, ctrl, isDark)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // ── Side Column ──
                    Expanded(
                      flex: 3,
                      child: _buildSidePanels(context, ctrl, isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, AuthController authCtrl, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Obx(() {
          final name = authCtrl.currentUser.value?.fullName ?? 'المستخدم';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('أهلاً بك، $name 👋',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  )),
              const SizedBox(height: 4),
              Text('إليك نظرة سريعة على أداء المتجر اليوم.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ],
          );
        }).animate().fade().slideX(begin: 0.05),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8),
                borderRadius: BorderRadius.circular(DesignTokens.kChipRadius),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 15, color: DesignTokens.neonPurple),
                  const SizedBox(width: 8),
                  Text(DateTime.now().toString().split(' ')[0],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ],
        ).animate().fade().slideX(begin: -0.05),
      ],
    );
  }

  // ─── 4 Stat Cards with Neon Glow ─────────────────────────────────────────
  Widget _buildStatCards(BuildContext context, DashboardController ctrl, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Obx(() => _glowStat(
            'إجمالي المبيعات',
            AppFormatters.currency(ctrl.todaySales.value),
            Icons.trending_up_rounded,
            DesignTokens.neonCyan,
            isDark,
            badge: '%${ctrl.dailySalesGrowth.value.abs().toStringAsFixed(0)}${ctrl.dailySalesGrowth.value >= 0 ? "+" : "-"}',
            badgeColor: ctrl.dailySalesGrowth.value >= 0 ? DesignTokens.neonGreen : DesignTokens.neonRed,
          )),
        ),
        const SizedBox(width: DesignTokens.kCardGap),
        Expanded(
          child: Obx(() => _glowStat(
            'أقساط نشطة',
            '${ctrl.dailyInvoicesCount.value} عقد',
            Icons.receipt_long_rounded,
            DesignTokens.neonPurple,
            isDark,
            badge: 'ثابت',
            badgeColor: DesignTokens.neonPurple,
          )),
        ),
        const SizedBox(width: DesignTokens.kCardGap),
        Expanded(
          child: Obx(() => _glowStat(
            'طلبات جديدة',
            '${ctrl.totalCustomers.value} طلب',
            Icons.local_shipping_rounded,
            DesignTokens.neonPink,
            isDark,
            badge: '%50-',
            badgeColor: DesignTokens.neonRed,
          )),
        ),
        const SizedBox(width: DesignTokens.kCardGap),
        Expanded(
          child: Obx(() => _glowStat(
            'نقص المخزون',
            '${ctrl.lowStockProducts.value} أصناف',
            Icons.inventory_2_rounded,
            DesignTokens.neonOrange,
            isDark,
            badge: 'تنبيه',
            badgeColor: DesignTokens.neonOrange,
          )),
        ),
      ],
    );
  }

  Widget _glowStat(String title, String value, IconData icon, Color color, bool isDark, {String? badge, Color? badgeColor}) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.kPanelPadding),
      decoration: DesignTokens.glowCardDecoration(glowColor: color, isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withAlpha(40), blurRadius: 10)],
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? color).withAlpha(25),
                    borderRadius: BorderRadius.circular(DesignTokens.kChipRadius),
                  ),
                  child: Text(badge, style: TextStyle(
                    color: badgeColor ?? color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  )),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  // ─── Sales Chart ─────────────────────────────────────────────────────────
  Widget _buildSalesChart(BuildContext context, DashboardController ctrl, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.kPanelPadding),
      decoration: DesignTokens.panelDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('تحليل نمو المبيعات',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Row(children: [
                _chartToggle('أسبوعي', true, isDark),
                const SizedBox(width: 8),
                _chartToggle('شهري', false, isDark),
              ]),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Obx(() => ctrl.salesTrend.isEmpty
                ? Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.grey[500])))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true, drawVerticalLine: false,
                        horizontalInterval: 1000,
                        getDrawingHorizontalLine: (val) =>
                            FlLine(color: Colors.grey.withAlpha(20), strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, reservedSize: 30, interval: 1,
                            getTitlesWidget: (val, meta) {
                              if (val.toInt() >= 0 && val.toInt() < ctrl.salesTrend.length) {
                                return Text(ctrl.salesTrend[val.toInt()]['dayName'] ?? '',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12));
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, reservedSize: 45, interval: 1000,
                            getTitlesWidget: (val, meta) =>
                                Text('${val.toInt()}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          color: DesignTokens.neonCyan,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                              radius: 4,
                              color: DesignTokens.neonCyan,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [DesignTokens.neonCyan.withAlpha(50), DesignTokens.neonCyan.withAlpha(0)],
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            ),
                          ),
                          spots: ctrl.salesTrend.asMap().entries
                              .map((e) => FlSpot(e.key.toDouble(), (e.value['total'] as num).toDouble()))
                              .toList(),
                        ),
                      ],
                    ),
                  )),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _chartToggle(String label, bool isActive, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? (isDark ? DesignTokens.neonCyan.withAlpha(20) : DesignTokens.neonCyan.withAlpha(15))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(DesignTokens.kChipRadius),
        border: isActive ? Border.all(color: DesignTokens.neonCyan.withAlpha(50)) : null,
      ),
      child: Text(label, style: TextStyle(
        color: isActive ? DesignTokens.neonCyan : Colors.grey[500],
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      )),
    );
  }

  // ─── Side Panels (Alerts & Top Products) ─────────────────────────────────
  Widget _buildSidePanels(BuildContext context, DashboardController ctrl, bool isDark) {
    return Column(
      children: [
        Expanded(flex: 4, child: _buildAlertsCard(context, ctrl, isDark)),
        const SizedBox(height: 20),
        Expanded(flex: 5, child: _buildTopProductsCard(context, ctrl, isDark)),
      ],
    );
  }

  Widget _buildAlertsCard(BuildContext context, DashboardController ctrl, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.kPanelPadding),
      decoration: DesignTokens.panelDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: DesignTokens.neonOrange, size: 20),
              const SizedBox(width: 8),
              Text('تنبيهات عاجلة', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(() {
              final overdue = ctrl.overdueDetails;
              final lowStock = ctrl.lowStockDetails;
              
              if (overdue.isEmpty && lowStock.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 40, color: Colors.green.withAlpha(100)),
                      const SizedBox(height: 8),
                      Text('كل شيء على ما يرام', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                );
              }

              return ListView(
                children: [
                  if (overdue.isNotEmpty) ...[
                    Text('أقساط متأخرة (${overdue.length})', style: TextStyle(color: DesignTokens.neonRed, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ...overdue.take(5).map((item) => _buildAlertItem(
                      icon: Icons.money_off,
                      iconColor: DesignTokens.neonRed,
                      title: 'العميل: ${item['customerName']}',
                      subtitle: 'تأخير ${item['daysOverdue']} يوم - القسط: ${item['amount']} ج.م',
                      isDark: isDark,
                    )),
                    const SizedBox(height: 12),
                  ],
                  if (lowStock.isNotEmpty) ...[
                    Text('مخزون ناقص (${lowStock.length})', style: TextStyle(color: DesignTokens.neonOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ...lowStock.take(5).map((item) => _buildAlertItem(
                      icon: Icons.inventory_2_outlined,
                      iconColor: DesignTokens.neonOrange,
                      title: '${item['name']}',
                      subtitle: 'متبقي ${item['stockQuantity']} فقط',
                      isDark: isDark,
                    )),
                  ]
                ],
              );
            }),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.05);
  }

  Widget _buildTopProductsCard(BuildContext context, DashboardController ctrl, bool isDark) {
    final txColors = [DesignTokens.neonCyan, DesignTokens.neonGreen, DesignTokens.neonOrange, DesignTokens.neonPink, DesignTokens.neonPurple];
    final txIcons = [Icons.tv_rounded, Icons.kitchen_rounded, Icons.local_laundry_service_rounded, Icons.microwave_rounded, Icons.coffee_maker_rounded];

    return Container(
      padding: const EdgeInsets.all(DesignTokens.kPanelPadding),
      decoration: DesignTokens.panelDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text('الأعلى ربحية هذا الشهر', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(() {
              if (ctrl.topProfitableProducts.isEmpty) {
                return Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.grey[500])));
              }
              final items = ctrl.topProfitableProducts.take(5).toList();
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  final c = txColors[i % txColors.length];
                  final ic = txIcons[i % txIcons.length];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? DesignTokens.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(DesignTokens.kChipRadius),
                      border: Border.all(color: c.withAlpha(isDark ? 30 : 20)),
                      boxShadow: [BoxShadow(color: c.withAlpha(10), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: c.withAlpha(25), shape: BoxShape.circle),
                          child: Icon(ic, color: c, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item['productName']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text('بيعت ${item['quantitySold']} مرات', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                            ],
                          ),
                        ),
                        Text('${item['totalProfit']} ج.م', style: TextStyle(color: DesignTokens.neonGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ).animate().fadeIn(delay: Duration(milliseconds: 100 * i)).slideX(begin: 0.05);
                },
              );
            }),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms).slideX(begin: 0.05);
  }

  Widget _buildAlertItem({required IconData icon, required Color iconColor, required String title, required String subtitle, required bool isDark}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(5) : Colors.grey[50],
        borderRadius: BorderRadius.circular(DesignTokens.kChipRadius),
        border: Border(
          top: BorderSide(color: isDark ? Colors.white.withAlpha(10) : Colors.grey[200]!),
          right: BorderSide(color: isDark ? Colors.white.withAlpha(10) : Colors.grey[200]!),
          bottom: BorderSide(color: isDark ? Colors.white.withAlpha(10) : Colors.grey[200]!),
          left: BorderSide(color: iconColor, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
