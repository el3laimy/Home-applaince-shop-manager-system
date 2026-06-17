import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/reports_controller.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/neo_button.dart';
import '../core/widgets/neo_data_table.dart';
import '../services/report_pdf_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ReportsController());

    return DesignTokens.neoPageBackgroundWidget(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.kPagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, ctrl),
              const SizedBox(height: 24),
              Expanded(
                child: Obx(() {
                  if (ctrl.isLoading.value && ctrl.salesMetrics.isEmpty) {
                    return const Center(child: CircularProgressIndicator(color: DesignTokens.neonCyan));
                  }
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSalesCards(ctrl),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 350,
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: _buildSalesChart(context, ctrl)),
                              const SizedBox(width: 20),
                              Expanded(flex: 1, child: _buildTopProducts(context, ctrl)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildInventoryValuePanel(context, ctrl),
                        const SizedBox(height: 40),
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context, ReportsController ctrl) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesignTokens.holographicText(
              text: 'التقارير التحليلية',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text('نظرة شاملة على المبيعات، الأرباح، والمخزون',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ).animate().fade().slideX(begin: 0.05),
        Row(
          children: [
            // Date range picker
            InkWell(
              onTap: () async {
                final DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: DateTimeRange(start: ctrl.startDate.value, end: ctrl.endDate.value),
                );
                if (picked != null) {
                  ctrl.updateDateRange(picked.start, picked.end);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(13),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withAlpha(25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: DesignTokens.neonCyan, size: 20),
                    const SizedBox(width: 12),
                    Obx(() => Text(
                      '${ctrl.startDate.value.toString().split(' ')[0]}  إلى  ${ctrl.endDate.value.toString().split(' ')[0]}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            NeoButton.outlined(
              label: 'Excel',
              icon: Icons.table_chart_rounded,
              color: DesignTokens.neonGreen,
              onPressed: ctrl.salesMetrics.isNotEmpty ? () => ctrl.exportToExcel() : null,
            ),
            const SizedBox(width: 8),
            NeoButton.outlined(
              label: 'PDF',
              icon: Icons.picture_as_pdf_rounded,
              color: DesignTokens.neonRed,
              onPressed: ctrl.salesMetrics.isNotEmpty ? () => ReportPdfService.exportSalesReport(
                from: ctrl.startDate.value,
                to: ctrl.endDate.value,
                salesMetrics: ctrl.salesMetrics,
                topProducts: ctrl.topProducts,
                inventoryMetrics: ctrl.inventoryMetrics,
              ).catchError((_) {}) : null,
            ),
          ],
        ).animate().fade().slideX(begin: -0.05),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STAT CARDS — Liquid Border
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSalesCards(ReportsController ctrl) {
    if (ctrl.salesMetrics.isEmpty) return const SizedBox();
    final m = ctrl.salesMetrics;
    return Row(
      children: [
        Expanded(child: _liquidStat('الإيرادات', AppFormatters.currency((m['totalRevenue'] as num).toDouble()),
            Icons.monetization_on, DesignTokens.neonCyan)),
        const SizedBox(width: DesignTokens.kCardGap),
        Expanded(child: _liquidStat('التكلفة', AppFormatters.currency((m['totalCost'] as num).toDouble()),
            Icons.shopping_cart, DesignTokens.neonOrange)),
        const SizedBox(width: DesignTokens.kCardGap),
        Expanded(child: _liquidStat('المرتجعات', AppFormatters.currency((m['totalRefunds'] as num).toDouble()),
            Icons.keyboard_return, DesignTokens.neonRed)),
        const SizedBox(width: DesignTokens.kCardGap),
        Expanded(child: _liquidStat('المصروفات', AppFormatters.currency((m['totalExpenses'] ?? 0 as num).toDouble()),
            Icons.receipt_long, DesignTokens.neonPurple)),
        const SizedBox(width: DesignTokens.kCardGap),
        Expanded(child: _liquidStat('صافي الربح', AppFormatters.currency((m['netProfit'] as num).toDouble()),
            Icons.trending_up, DesignTokens.neonGreen)),
      ],
    );
  }

  Widget _liquidStat(String label, String value, IconData icon, Color color) {
    return DesignTokens.liquidBorderCard(
      height: 100,
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(25)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SALES CHART — Neo-Glass
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSalesChart(BuildContext context, ReportsController ctrl) {
    return DesignTokens.neoGlassBox(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('المبيعات خلال الفترة المحددة',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
          const SizedBox(height: 24),
          Expanded(
            child: ctrl.salesTrend.isEmpty
                ? Center(child: Text('لا توجد بيانات للفترة المحددة', style: TextStyle(color: Colors.grey[500])))
                : RepaintBoundary(
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true, drawVerticalLine: false,
                          getDrawingHorizontalLine: (val) => FlLine(color: Colors.white.withAlpha(10), strokeWidth: 1),
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true, reservedSize: 30,
                              interval: (ctrl.salesTrend.length / 5).ceil().toDouble(),
                              getTitlesWidget: (val, meta) {
                                if (val.toInt() >= 0 && val.toInt() < ctrl.salesTrend.length) {
                                  final dateStr = ctrl.salesTrend[val.toInt()]['date'] as String;
                                  return Text(dateStr.substring(5), style: TextStyle(color: Colors.grey[500], fontSize: 10));
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
                            isCurved: true, color: DesignTokens.neonCyan, barWidth: 4, isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [DesignTokens.neonCyan.withAlpha(80), DesignTokens.neonCyan.withAlpha(0)],
                                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              ),
                            ),
                            spots: ctrl.salesTrend.asMap().entries
                                .map((e) => FlSpot(e.key.toDouble(), (e.value['revenue'] as num).toDouble()))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TOP PRODUCTS — Neo-Glass
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTopProducts(BuildContext context, ReportsController ctrl) {
    return DesignTokens.neoGlassBox(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              const Text('أكثر المنتجات مبيعاً',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
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
                      return NeoListTile(
                        title: '${i + 1}. ${item['productName']}',
                        subtitle: 'الكمية المباعة: ${item['quantitySold']}',
                        iconColor: _rankColor(i),
                        icon: Icons.inventory_2_rounded,
                        trailing: Text('${item['totalRevenue']} ج',
                            style: TextStyle(color: _rankColor(i), fontWeight: FontWeight.bold, fontSize: 12)),
                      );
                    },
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.05);
  }

  Color _rankColor(int i) {
    const colors = [DesignTokens.neonCyan, DesignTokens.neonPurple, DesignTokens.neonPink,
        DesignTokens.neonOrange, DesignTokens.neonGreen];
    return colors[i % colors.length];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  INVENTORY VALUE — Neo-Glass
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildInventoryValuePanel(BuildContext context, ReportsController ctrl) {
    if (ctrl.inventoryMetrics.isEmpty) return const SizedBox();
    final m = ctrl.inventoryMetrics;

    return DesignTokens.neoGlassBox(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2, color: DesignTokens.neonCyan, size: 22),
              const SizedBox(width: 8),
              const Text('تقييم المخزون الحالي',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _inventoryMetric('إجمالي تكلفة المخزون',
                  '${(m['TotalCostValue'] as num).toDouble().toStringAsFixed(2)} ج.م', DesignTokens.neonOrange)),
              Container(width: 1, height: 50, color: Colors.white.withAlpha(13)),
              Expanded(child: _inventoryMetric('إجمالي قيمة البيع المتوقعة',
                  '${(m['TotalRetailValue'] as num).toDouble().toStringAsFixed(2)} ج.م', DesignTokens.neonCyan)),
              Container(width: 1, height: 50, color: Colors.white.withAlpha(13)),
              Expanded(child: _inventoryMetric('الربح المتوقع للمخزون',
                  '${(m['ExpectedProfit'] as num).toDouble().toStringAsFixed(2)} ج.م', DesignTokens.neonGreen)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.08);
  }

  Widget _inventoryMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        const SizedBox(height: 8),
        DesignTokens.holographicText(
          text: value,
          style: const TextStyle(fontSize: 20),
        ),
      ],
    );
  }
}
