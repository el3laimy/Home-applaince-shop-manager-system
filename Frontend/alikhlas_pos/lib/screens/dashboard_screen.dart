import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/auth_controller.dart';

import '../core/theme/design_tokens.dart';
import '../core/utils/formatters.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(DashboardController());
    final authCtrl = Get.find<AuthController>();

    return DesignTokens.neoPageBackgroundWidget(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.kPagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, authCtrl),
              const SizedBox(height: 24),
              Expanded(
                child: Column(
                  children: [
                    // 4 Stat Cards
                    _buildStatCards(ctrl),
                    const SizedBox(height: 24),
                    // Chart + Transactions
                    Expanded(
                      child: Row(
                        children: [
                          // Sales Chart (2/3)
                          Expanded(
                            flex: 2,
                            child: _buildSalesChart(context, ctrl),
                          ),
                          const SizedBox(width: 24),
                          // Recent Transactions (1/3)
                          Expanded(
                            flex: 1,
                            child: _buildRecentTransactions(ctrl),
                          ),
                        ],
                      ),
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  HEADER — Holographic greeting + search bar
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context, AuthController authCtrl) {
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Obx(() {
            final name = authCtrl.currentUser.value?.fullName ?? 'المستخدم';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DesignTokens.holographicText(
                  text: 'أهلاً بك، $name',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 4),
                Text('إليك نظرة سريعة على أداء المتجر اليوم.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            );
          }).animate().fade().slideX(begin: 0.05),

          // Search bar + Notification bell
          Row(
            children: [
              // Search
              Container(
                width: 280,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(13),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(25)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search, color: Colors.grey[500], size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'بحث سريع...',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Notification bell
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withAlpha(13),
                  border: Border.all(color: Colors.white.withAlpha(25)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                    Positioned(
                      top: 10,
                      left: 10,
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
                ),
              ),
            ],
          ).animate().fade().slideX(begin: -0.05),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  4 STAT CARDS — Liquid Border
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStatCards(DashboardController ctrl) {
    return Row(
      children: [
        Expanded(
          child: Obx(() => _liquidStat(
            label: 'إجمالي المبيعات',
            value: AppFormatters.currency(ctrl.todaySales.value),
            icon: Icons.payments_rounded,
            iconBg: DesignTokens.neonCyan,
            badge: ctrl.dailySalesGrowth.value >= 0
                ? '+${ctrl.dailySalesGrowth.value.abs().toStringAsFixed(0)}٪'
                : '-${ctrl.dailySalesGrowth.value.abs().toStringAsFixed(0)}٪',
            badgeColor: ctrl.dailySalesGrowth.value >= 0
                ? DesignTokens.neonGreen
                : DesignTokens.neonRed,
          )),
        ),
        const SizedBox(width: DesignTokens.kCardGap),
        Expanded(
          child: Obx(() => _liquidStat(
            label: 'أقساط نشطة',
            value: '${ctrl.dailyInvoicesCount.value} عقد',
            icon: Icons.credit_score_rounded,
            iconBg: DesignTokens.neonPurple,
            badge: 'ثابت',
            badgeColor: Colors.grey,
          )),
        ),
        const SizedBox(width: DesignTokens.kCardGap),
        Expanded(
          child: Obx(() => _liquidStat(
            label: 'طلبات جديدة',
            value: '${ctrl.totalCustomers.value} طلب',
            icon: Icons.shopping_bag_rounded,
            iconBg: DesignTokens.neonPink,
            badge: '-٥٪',
            badgeColor: DesignTokens.neonRed,
          )),
        ),
        const SizedBox(width: DesignTokens.kCardGap),
        Expanded(
          child: Obx(() => _liquidStat(
            label: 'نقص المخزون',
            value: '${ctrl.lowStockProducts.value} أصناف',
            icon: Icons.inventory_rounded,
            iconBg: DesignTokens.neonOrange,
            badge: 'تنبيه',
            badgeColor: DesignTokens.neonOrange,
          )),
        ),
      ],
    );
  }

  Widget _liquidStat({
    required String label,
    required String value,
    required IconData icon,
    required Color iconBg,
    String? badge,
    Color? badgeColor,
  }) {
    return DesignTokens.liquidBorderCard(
      height: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top row: icon + badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: iconBg.withAlpha(25),
                ),
                child: Icon(icon, color: iconBg, size: 22),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? iconBg).withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge, style: TextStyle(
                    color: badgeColor ?? iconBg,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  )),
                ),
            ],
          ),
          // Bottom: label + value
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              const SizedBox(height: 4),
              DesignTokens.holographicText(
                text: value,
                style: const TextStyle(fontSize: 22),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SALES CHART — Neo-Glass Panel
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSalesChart(BuildContext context, DashboardController ctrl) {
    return DesignTokens.neoGlassBox(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('تحليل نمو المبيعات',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  )),
              // Toggle buttons
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(13),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(13)),
                ),
                child: Row(
                  children: [
                    _chartToggle('أسبوعي', true),
                    const SizedBox(width: 4),
                    _chartToggle('شهري', false),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Chart
          Expanded(
            child: Obx(() => ctrl.salesTrend.isEmpty
                ? Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.grey[500])))
                : RepaintBoundary(
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1000,
                          getDrawingHorizontalLine: (val) =>
                              FlLine(color: Colors.white.withAlpha(10), strokeWidth: 1),
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (val, meta) {
                                if (val.toInt() >= 0 && val.toInt() < ctrl.salesTrend.length) {
                                  return Text(ctrl.salesTrend[val.toInt()]['dayName'] ?? '',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 10));
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 45,
                              interval: 1000,
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
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                radius: 5,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: DesignTokens.neonCyan,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [DesignTokens.neonCyan.withAlpha(80), DesignTokens.neonCyan.withAlpha(0)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            spots: ctrl.salesTrend.asMap().entries
                                .map((e) => FlSpot(e.key.toDouble(), (e.value['total'] as num).toDouble()))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  )),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _chartToggle(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withAlpha(25) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isActive
            ? [BoxShadow(color: DesignTokens.neonCyan.withAlpha(25), blurRadius: 10)]
            : null,
      ),
      child: Text(label, style: TextStyle(
        color: isActive ? DesignTokens.neonCyan : Colors.grey[500],
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      )),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RECENT TRANSACTIONS — Neo-Glass Panel
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildRecentTransactions(DashboardController ctrl) {
    final txColors = [
      const Color(0xFF3B82F6), // blue
      DesignTokens.neonPurple,
      DesignTokens.neonPink,
      DesignTokens.neonGreen,
      DesignTokens.neonOrange,
    ];
    final txIcons = [
      Icons.tv_rounded,
      Icons.kitchen_rounded,
      Icons.local_laundry_service_rounded,
      Icons.microwave_rounded,
      Icons.coffee_maker_rounded,
    ];

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.kNeoPanelRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: DesignTokens.neoGlassDecoration(),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(5),
                    border: Border(bottom: BorderSide(color: Colors.white.withAlpha(13))),
                  ),
                  child: Row(
                    children: [
                      const Text('آخر المعاملات',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ],
                  ),
                ),
                // Transaction List
                Expanded(
                  child: Obx(() {
                    if (ctrl.recentInvoices.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 40, color: Colors.white.withAlpha(30)),
                            const SizedBox(height: 8),
                            Text('لا توجد معاملات بعد', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                          ],
                        ),
                      );
                    }
                    final items = ctrl.recentInvoices.take(6).toList();
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        final c = txColors[i % txColors.length];
                        final ic = txIcons[i % txIcons.length];
                        final total = (item['grandTotal'] as num?)?.toDouble() ?? 0.0;
                        final invoiceNo = item['invoiceNumber'] ?? '#${i + 1}';
                        final customerName = item['customerName'] ?? 'عميل';
                        final createdAt = item['createdAt'] ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(13),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withAlpha(13)),
                          ),
                          child: Row(
                            children: [
                              // Icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c.withAlpha(50),
                                ),
                                child: Icon(ic, color: c, size: 20),
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$customerName - $invoiceNo',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(_formatTime(createdAt),
                                        style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                                  ],
                                ),
                              ),
                              // Amount
                              Text(AppFormatters.currency(total),
                                  style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 13)),
                            ],
                          ),
                        ).animate().fadeIn(delay: Duration(milliseconds: 80 * i)).slideX(begin: 0.05);
                      },
                    );
                  }),
                ),
                // View all button
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(5),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        // Could navigate to reports or sales screen
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(13),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withAlpha(25)),
                        ),
                        child: const Center(
                          child: Text('عرض كل العمليات',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.05);
  }

  /// Formats a date string to a relative time (e.g. "قبل ٢٠ دقيقة").
  String _formatTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    return 'قبل ${diff.inDays} يوم';
  }
}
