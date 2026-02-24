import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/reports_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../services/report_pdf_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ReportsController());
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
                child: Obx(() {
                  if (ctrl.isLoading.value && ctrl.salesMetrics.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSalesCards(context, ctrl, isDark),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 350,
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: _buildSalesChart(context, ctrl, isDark)),
                              const SizedBox(width: 20),
                              Expanded(flex: 1, child: _buildTopProducts(context, ctrl, isDark)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildInventoryValuePanel(context, ctrl, isDark),
                        const SizedBox(height: 40), // Bottom padding
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ReportsController ctrl, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التقارير التحليلية', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('نظرة شاملة على المبيعات، الأرباح، والمخزون', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ).animate().fade().slideX(begin: 0.1),
        
        Row(
          children: [
            // Date Picker
            InkWell(
              onTap: () async {
                final DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: DateTimeRange(start: ctrl.startDate.value, end: ctrl.endDate.value),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(primary: AppTheme.primaryColor),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  ctrl.updateDateRange(picked.start, picked.end);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Obx(() => Text(
                      '${ctrl.startDate.value.toString().split(' ')[0]}  إلى  ${ctrl.endDate.value.toString().split(' ')[0]}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
              onPressed: ctrl.salesMetrics.isNotEmpty ? () => ReportPdfService.exportSalesReport(
                from: ctrl.startDate.value,
                to: ctrl.endDate.value,
                salesMetrics: ctrl.salesMetrics,
                topProducts: ctrl.topProducts,
                inventoryMetrics: ctrl.inventoryMetrics,
              ).catchError((_) {}) : null,
              tooltip: 'تصدير PDF',
            ),
          ],
        ).animate().fade().slideX(begin: -0.1),
      ],
    );
  }

  Widget _buildSalesCards(BuildContext context, ReportsController ctrl, bool isDark) {
    if (ctrl.salesMetrics.isEmpty) return const SizedBox();
    
    final metrics = ctrl.salesMetrics;
    return Row(
      children: [
        _statCard('المبيعات الإجمالية', AppFormatters.currency((metrics['totalRevenue'] as num).toDouble()), Icons.monetization_on, const Color(0xFF00E5FF), isDark),
        const SizedBox(width: 16),
        _statCard('تكلفة البضاعة المباعة', AppFormatters.currency((metrics['totalCost'] as num).toDouble()), Icons.shopping_cart, Colors.orange, isDark),
        const SizedBox(width: 16),
        _statCard('المرتجعات', AppFormatters.currency((metrics['totalRefunds'] as num).toDouble()), Icons.keyboard_return, Colors.redAccent, isDark),
        const SizedBox(width: 16),
        _statCard('صافي الربح', AppFormatters.currency((metrics['netProfit'] as num).toDouble()), Icons.trending_up, const Color(0xFF43E97B), isDark),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(200),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha(40)),
              boxShadow: isDark ? [] : [BoxShadow(color: color.withAlpha(15), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 28),
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
      ).animate().fadeIn().slideY(begin: 0.1),
    );
  }

  Widget _buildSalesChart(BuildContext context, ReportsController ctrl, bool isDark) {
    return _panelBox(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المبيعات خلال الفترة المحددة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: ctrl.salesTrend.isEmpty
                ? Center(child: Text('لا توجد بيانات للفترة المحددة', style: TextStyle(color: Colors.grey[500])))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.withAlpha(30), strokeWidth: 1)),
                      titlesData: FlTitlesData(
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, reservedSize: 30, interval: (ctrl.salesTrend.length / 5).ceil().toDouble(),
                            getTitlesWidget: (val, meta) {
                              if (val.toInt() >= 0 && val.toInt() < ctrl.salesTrend.length) {
                                final dateStr = ctrl.salesTrend[val.toInt()]['date'] as String;
                                return Text(dateStr.substring(5), style: TextStyle(color: Colors.grey[500], fontSize: 10)); // Show MM-dd
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, reservedSize: 50, interval: 1000,
                            getTitlesWidget: (val, meta) => Text('${val.toInt()}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true, color: AppTheme.primaryColor, barWidth: 4, isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [AppTheme.primaryColor.withAlpha(80), AppTheme.primaryColor.withAlpha(0)],
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            ),
                          ),
                          spots: ctrl.salesTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['revenue'] as num).toDouble())).toList(),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildTopProducts(BuildContext context, ReportsController ctrl, bool isDark) {
    return _panelBox(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber),
              const SizedBox(width: 8),
              Text('أكثر المنتجات مبيعاً', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ctrl.topProducts.isEmpty
                ? Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.grey[500])))
                : ListView.builder(
                    itemCount: ctrl.topProducts.length,
                    itemBuilder: (ctx, i) {
                      final item = ctrl.topProducts[i];
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
                            Text('${item['totalRevenue']} ج', style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.05);
  }

  Widget _buildInventoryValuePanel(BuildContext context, ReportsController ctrl, bool isDark) {
    if (ctrl.inventoryMetrics.isEmpty) return const SizedBox();
    final metrics = ctrl.inventoryMetrics;
    
    return _panelBox(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2, color: AppTheme.secondaryColor),
              const SizedBox(width: 8),
              Text('تقييم المخزون الحالي', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('إجمالي تكلفة المخزون', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('${(metrics['TotalCostValue'] as num).toDouble().toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.orange)),
                  ],
                ),
              ),
              Container(width: 1, height: 50, color: Colors.grey.withAlpha(50)),
              Expanded(
                child: Column(
                  children: [
                    Text('إجمالي قيمة البيع المتوقعة', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('${(metrics['TotalRetailValue'] as num).toDouble().toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF00E5FF))),
                  ],
                ),
              ),
              Container(width: 1, height: 50, color: Colors.grey.withAlpha(50)),
              Expanded(
                child: Column(
                  children: [
                    Text('الربح المتوقع للمخزون', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('${(metrics['ExpectedProfit'] as num).toDouble().toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF43E97B))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _panelBox(bool isDark, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
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
}
