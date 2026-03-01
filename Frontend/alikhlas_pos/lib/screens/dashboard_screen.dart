import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import '../controllers/dashboard_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(DashboardController());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
              : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, ctrl, isDark),
              const SizedBox(height: 24),
              
              Expanded(
                child: Column(
                  children: [
                    Obx(() {
                      if (ctrl.isLoading.value && ctrl.todaySales.value == 0) return const SizedBox.shrink(); // Hide during initial load if really needed, but shimmer is better
                      if (ctrl.errorMessage.isNotEmpty) return Center(child: Text(ctrl.errorMessage.value, style: const TextStyle(color: Colors.red)));
                      return const SizedBox.shrink();
                    }),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main Column
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
                          // Side Column
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                Expanded(flex: 3, child: _buildTopProducts(context, ctrl, isDark)),
                                const SizedBox(height: 20),
                                Expanded(flex: 2, child: _buildRecentInvoices(context, ctrl, isDark)),
                                const SizedBox(height: 20),
                                Expanded(flex: 1, child: _buildAlertsCard(context, ctrl, isDark)),
                              ],
                            ),
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

  Widget _buildHeader(BuildContext context, DashboardController ctrl, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('لوحة القياة والتحليلات', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('نظرة عامة على أداء المبيعات والمخزون', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ).animate().fade().slideX(begin: 0.1),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: ctrl.fetchSummary,
              tooltip: 'تحديث البيانات',
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(DateTime.now().toString().split(' ')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ).animate().fade().slideX(begin: -0.1),
      ],
    );
  }

  Widget _buildStatCards(BuildContext context, DashboardController ctrl, bool isDark) {
    return Column(
      children: [
        // Row 1: Core KPIs + Daily Growth
        Row(
          children: [
            Expanded(
              child: Obx(() => _cardWithGrowth(
                'مبيعات اليوم',
                AppFormatters.currency(ctrl.todaySales.value),
                ctrl.dailySalesGrowth.value,
                Icons.point_of_sale,
                const Color(0xFF00E5FF),
                'النمو اليومي',
                isDark,
              )),
            ),
            const SizedBox(width: 16),
            Expanded(child: Obx(() => _statCard('فواتير اليوم', '${ctrl.dailyInvoicesCount.value}', Icons.receipt_long, const Color(0xFF4FACFE), isDark))),
            const SizedBox(width: 16),
            Expanded(
              child: Obx(() => _cardWithGrowth(
                'مبيعات الشهر',
                AppFormatters.currency(ctrl.monthlySales.value),
                ctrl.monthlySalesGrowth.value,
                Icons.account_balance_wallet,
                const Color(0xFF43E97B),
                'النمو الشهري',
                isDark,
              )),
            ),
            const SizedBox(width: 16),
            Expanded(child: Obx(() => _statCard('العملاء', '${ctrl.totalCustomers.value}', Icons.people, const Color(0xFFF093FB), isDark))),
          ],
        ),
        const SizedBox(height: 16),
        
        // Row 2: Advanced Profit Margins (NEW)
        Row(
          children: [
            Expanded(child: Obx(() => _marginCard('إجمالي الربح (الشهري)', AppFormatters.currency(ctrl.monthlyGrossProfit.value), ctrl.grossMargin.value, const Color(0xFF00C9FF), isDark))),
            const SizedBox(width: 16),
            Expanded(child: Obx(() => _marginCard('صافي الربح (الشهري)', AppFormatters.currency(ctrl.monthlyNetProfit.value), ctrl.netMargin.value, const Color(0xFF43E97B), isDark))),
            const SizedBox(width: 16),
            Expanded(child: Obx(() => _marginCard('هيكلة المصروفات', '${ctrl.expenseRatio.value}% من المبيعات', ctrl.expenseRatio.value, Colors.orangeAccent, isDark, invertColor: true))),
          ],
        ),
      ],
    );
  }

  Widget _marginCard(String title, String value, double percentage, Color color, bool isDark, {bool invertColor = false}) {
    Color ringColor = invertColor 
      ? (percentage > 20 ? Colors.redAccent : color) 
      : (percentage > 0 ? color : Colors.redAccent);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(200),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(40)),
            boxShadow: [BoxShadow(color: color.withAlpha(15), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 50, height: 50,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: color.withAlpha(30),
                      color: ringColor,
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(child: Text('${percentage.toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ringColor))),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _cardWithGrowth(String title, String value, double growth, IconData icon, Color color, String growthLabel, bool isDark) {
    bool isPositive = growth >= 0;
    Color growthColor = isPositive ? const Color(0xFF43E97B) : Colors.redAccent;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(200),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(40)),
            boxShadow: [BoxShadow(color: color.withAlpha(15), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: growthColor.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, color: growthColor, size: 12),
                        const SizedBox(width: 4),
                        Text('${growth.abs()}%', style: TextStyle(color: growthColor, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _statCard(String title, String value, IconData icon, Color color, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(200),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(40)),
            boxShadow: [BoxShadow(color: color.withAlpha(15), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
               const SizedBox(height: 12),
              Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildSalesChart(BuildContext context, DashboardController ctrl, bool isDark) {
    return _panelBox(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('أداء المبيعات مقابل الأرباح (7 أيام)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  _legendItem('المبيعات', AppTheme.primaryColor),
                  const SizedBox(width: 16),
                  _legendItem('صافي الربح', const Color(0xFF43E97B)),
                ],
              )
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
                        getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.withAlpha(30), strokeWidth: 1),
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
                            getTitlesWidget: (val, meta) => Text('${val.toInt()}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        // Sales Line
                        LineChartBarData(
                          isCurved: true,
                          color: AppTheme.primaryColor,
                          barWidth: 4, isStrokeCapRound: true,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [AppTheme.primaryColor.withAlpha(40), AppTheme.primaryColor.withAlpha(0)],
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            ),
                          ),
                          spots: ctrl.salesTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['total'] as num).toDouble())).toList(),
                        ),
                        // Profit Line
                        LineChartBarData(
                          isCurved: true,
                          color: const Color(0xFF43E97B),
                          barWidth: 3, isStrokeCapRound: true,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(show: false),
                          spots: ctrl.salesTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), ((e.value['profit'] ?? 0) as num).toDouble())).toList(),
                        ),
                      ],
                    ),
                  )),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTopProducts(BuildContext context, DashboardController ctrl, bool isDark) {
     return _panelBox(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
             children: [
                const Icon(Icons.workspace_premium, color: Colors.amber),
                const SizedBox(width: 8),
                Text('أبطال الأرباح (الشهر)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
             ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(() => ctrl.topProfitableProducts.isEmpty
                ? Center(child: Text('لا توجد بيانات أرباح للمنتجات', style: TextStyle(color: Colors.grey[500])))
                : ListView.builder(
                    itemCount: ctrl.topProfitableProducts.length,
                    itemBuilder: (ctx, i) {
                      final item = ctrl.topProfitableProducts[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black.withAlpha(40) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withAlpha(isDark ? 30 : 50)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text('${i+1}. ${item['productName']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                   const SizedBox(height: 4),
                                   Text('الكمية المباعة: ${item['quantitySold']}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                 ],
                               ),
                            ),
                            Column(
                               crossAxisAlignment: CrossAxisAlignment.end,
                               children: [
                                  Text('${item['totalProfit']} ج', style: const TextStyle(color: Color(0xFF43E97B), fontWeight: FontWeight.bold, fontSize: 14)),
                                  const Text('صافي ربح', style: TextStyle(fontSize: 10, color: Colors.grey)),
                               ],
                            )
                          ],
                        ),
                      );
                    },
                  )),
          )
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.05);
  }

  Widget _buildRecentInvoices(BuildContext context, DashboardController ctrl, bool isDark) {
    return _panelBox(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('أحدث الفواتير', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(() => ctrl.recentInvoices.isEmpty
                ? Center(child: Text('لا توجد فواتير حديثة', style: TextStyle(color: Colors.grey[500])))
                : ListView.builder(
                    itemCount: ctrl.recentInvoices.length,
                    itemBuilder: (ctx, i) {
                      final inv = ctrl.recentInvoices[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black.withAlpha(40) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withAlpha(isDark ? 30 : 50)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(inv['invoiceNo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace')),
                                const SizedBox(height: 4),
                                Text(inv['customerName'] ?? 'عميل نقدي', style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Text('${inv['totalAmount']} ج', style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      );
                    },
                  )),
          )
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.05);
  }

  Widget _buildAlertsCard(BuildContext context, DashboardController ctrl, bool isDark) {
    return _panelBox(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text('تنبيهات النظام', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(() => ListView(
              children: [
                if (ctrl.lowStockProducts.value > 0)
                  _alertItem('المخزون', 'يوجد ${ctrl.lowStockProducts.value} منتج وصل للحد الأدنى للمخزون!', Colors.orange, isDark),
                if (ctrl.lowStockProducts.value == 0)
                  const Center(child: Text('لا توجد تنبيهات', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
              ],
            )),
          )
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.05);
  }

  Widget _alertItem(String title, String msg, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withAlpha(40))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withAlpha(40), shape: BoxShape.circle), child: Icon(Icons.notifications_active, color: color, size: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Added to prevent vertical growth
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
                Text(msg, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelBox(bool isDark, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(5) : Colors.white.withAlpha(200),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(isDark ? 20 : 60)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    
    Widget box(double height) => Container(
      height: height,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    );

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: Column(
              children: [
                Row(
                  children: List.generate(4, (i) => Expanded(child: Padding(padding: const EdgeInsets.only(left: 16), child: box(100)))),
                ),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(3, (i) => Expanded(child: Padding(padding: const EdgeInsets.only(left: 16), child: box(130)))),
                ),
                const SizedBox(height: 20),
                Expanded(child: box(300)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                 Expanded(flex: 3, child: box(double.infinity)),
                 const SizedBox(height: 20),
                 Expanded(flex: 2, child: box(double.infinity)),
                 const SizedBox(height: 20),
                 Expanded(flex: 1, child: box(double.infinity)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
