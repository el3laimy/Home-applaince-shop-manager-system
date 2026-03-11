import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/finance_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(FinanceController());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: isDark
              ? [DesignTokens.bgDark, const Color(0xFF0F1629)]
              : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, ctrl, isDark),
              const SizedBox(height: 20),
              _buildSummaryCards(context, ctrl, isDark),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildTransactionsPanel(context, ctrl, isDark)),
                    const SizedBox(width: 20),
                    SizedBox(width: 300, child: _buildExpensePanel(context, ctrl, isDark)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FinanceController ctrl, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الخزينة والمحاسبة المالية',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('مراقبة التدفق النقدي، المصروفات، والإقفال الدوري',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ).animate().fade().slideX(begin: 0.1),
        Row(
          children: [
            // Date filter (Task 3.1)
            Obx(() {
              final d = ctrl.selectedDate.value;
              final isToday = d.year == DateTime.now().year && d.month == DateTime.now().month && d.day == DateTime.now().day;
              return TextButton.icon(
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(isToday ? 'اليوم' : '${d.day}/${d.month}/${d.year}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isToday ? Colors.grey : AppTheme.primaryColor)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: ctrl.selectedDate.value,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    ctrl.selectedDate.value = picked;
                    ctrl.fetchFinanceSummary();
                  }
                },
              );
            }),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.account_balance),
              label: const Text('توريد نقدية', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showTransferDialog(context, ctrl),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.lock_clock),
              label: const Text('إقفال الفترة', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showClosePeriodDialog(context, ctrl),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Obx(() => ctrl.isLoading.value
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh)),
              onPressed: ctrl.fetchFinanceSummary,
              tooltip: 'تحديث',
            ),
          ],
        ).animate().fade().slideX(begin: -0.1),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, FinanceController ctrl, bool isDark) {
    return Obx(() => Row(
      children: [
        _card(context, 'رصيد درج الكاشير', '${ctrl.cashDrawerBalance.value.toStringAsFixed(2)} ج.م',
            Icons.point_of_sale, const Color(0xFF00E5FF), isDark),
        const SizedBox(width: 16),
        _card(context, 'رصيد الخزينة الرئيسية', '${ctrl.mainTreasuryBalance.value.toStringAsFixed(2)} ج.م',
            Icons.account_balance_wallet, const Color(0xFF00FF87), isDark),
        const SizedBox(width: 16),
        _card(context, 'مبيعات اليوم', '${ctrl.todaySales.value.toStringAsFixed(2)} ج.م',
            Icons.trending_up, AppTheme.primaryColor, isDark),
        const SizedBox(width: 16),
        _card(context, 'مصروفات اليوم', '${ctrl.todayExpenses.value.toStringAsFixed(2)} ج.م',
            Icons.money_off, Colors.redAccent, isDark),
      ],
    ));
  }

  Widget _card(BuildContext context, String title, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.kPanelPadding),
        decoration: DesignTokens.glowCardDecoration(glowColor: color, isDark: isDark),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(25),
                  boxShadow: [BoxShadow(color: color.withAlpha(40), blurRadius: 12)]),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 150.ms).slideY(begin: -0.1),
    );
  }

  Widget _buildTransactionsPanel(BuildContext context, FinanceController ctrl, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(8) : Colors.white.withAlpha(200),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(isDark ? 20 : 60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('حركة الخزينة التفصيلية (اليوم)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              Expanded(
                child: Obx(() {
                  if (ctrl.isLoading.value && ctrl.cashTransactions.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (ctrl.cashTransactions.isEmpty) {
                    return Center(child: Text('لا توجد حركات اليوم', style: TextStyle(color: Colors.grey[500])));
                  }
                  return SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(isDark ? Colors.black.withAlpha(40) : Colors.grey.withAlpha(20)),
                      columns: const [
                        DataColumn(label: Text('الوقت', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('رقم المستند', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('نوع الحركة', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('البيان', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('وارد (+)', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('صادر (-)', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: ctrl.cashTransactions.map((tx) {
                        final isIn = (tx['type'] as String? ?? '') == 'in';
                        final amount = (tx['amount'] as num? ?? 0).toStringAsFixed(2);
                        return DataRow(cells: [
                          DataCell(Text(tx['time'] as String? ?? '-')),
                          DataCell(Text(tx['referenceNo'] as String? ?? '-', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isIn ? Colors.green : Colors.red).withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(tx['typeName'] as String? ?? '-',
                                style: TextStyle(color: isIn ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          )),
                          DataCell(Text(tx['description'] as String? ?? '-', overflow: TextOverflow.ellipsis)),
                          DataCell(Text(isIn ? '$amount ج.م' : '-', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                          DataCell(Text(!isIn ? '$amount ج.م' : '-', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                        ]);
                      }).toList(),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildExpensePanel(BuildContext context, FinanceController ctrl, bool isDark) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = 'operational';
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(5) : Colors.white.withAlpha(180),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(isDark ? 20 : 60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تسجيل مصروف', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: InputDecoration(
                  labelText: 'نوع المصروف',
                  prefixIcon: Icon(Icons.category, color: AppTheme.primaryColor),
                  filled: true, fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'operational', child: Text('تشغيلي')),
                  DropdownMenuItem(value: 'salary', child: Text('رواتب ويوميات')),
                  DropdownMenuItem(value: 'transport', child: Text('نقل ومشال')),
                  DropdownMenuItem(value: 'hospitality', child: Text('ضيافة')),
                  DropdownMenuItem(value: 'other', child: Text('أخرى')),
                ],
                onChanged: (v) => selectedType = v ?? selectedType,
              ),
              const SizedBox(height: 14),
              _inputField(amountCtrl, 'المبلغ (ج.م)', Icons.money, isDark, isNumber: true),
              const SizedBox(height: 14),
              _inputField(descCtrl, 'بيان المصروف', Icons.description, isDark, maxLines: 3),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Obx(() => ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.outbox, color: Colors.white),
                  label: Text(ctrl.isLoading.value ? 'جاري الحفظ...' : 'خصم من الكاشير',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: ctrl.isLoading.value ? null : () async {
                    if (amountCtrl.text.isEmpty) return;
                    await ctrl.recordExpense({
                      'type': selectedType,
                      'amount': double.tryParse(amountCtrl.text) ?? 0,
                      'description': descCtrl.text,
                    });
                    amountCtrl.clear();
                    descCtrl.clear();
                  },
                )),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1);
  }

  Widget _inputField(TextEditingController ctrl, String label, IconData icon, bool isDark, {bool isNumber = false, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.multiline,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: maxLines == 1 ? Icon(icon, color: AppTheme.primaryColor, size: 20) : null,
        filled: true,
        fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withAlpha(40))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  void _showClosePeriodDialog(BuildContext context, FinanceController ctrl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 8), Text('تأكيد إقفال الفترة')]),
        content: const Text('سيتم ترحيل الأرباح وإغلاق الفترة المالية الحالية. هذا الإجراء لا يمكن التراجع عنه. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            onPressed: () async {
              Get.back();
              await ctrl.closePeriod();
            },
            child: const Text('تأكيد الإقفال', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTransferDialog(BuildContext context, FinanceController ctrl) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.account_balance, color: Colors.teal), SizedBox(width: 8), Text('توريد للخزينة الرئيسية')]),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الرصيد المتاح بالدرج: ${ctrl.cashDrawerBalance.value.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 16),
              _inputField(amountCtrl, 'المبلغ المراد توريده', Icons.money, Theme.of(context).brightness == Brightness.dark, isNumber: true),
              const SizedBox(height: 12),
              _inputField(descCtrl, 'البيان (اختياري)', Icons.description, Theme.of(context).brightness == Brightness.dark, maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;
              Get.back();
              await ctrl.transferToTreasury(amount, descCtrl.text);
            },
            child: const Text('تأكيد التوريد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
