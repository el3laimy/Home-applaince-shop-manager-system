import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../controllers/finance_controller.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/neo_button.dart';
import '../../core/widgets/neo_text_field.dart';
import '../../core/widgets/neo_dialog.dart';

class TreasuryTab extends StatelessWidget {
  const TreasuryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(FinanceController());

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, ctrl),
          const SizedBox(height: 20),
          _buildSummaryCards(ctrl),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildTransactionsPanel(context, ctrl)),
                const SizedBox(width: 20),
                SizedBox(width: 320, child: _buildExpensePanel(context, ctrl)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context, FinanceController ctrl) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesignTokens.holographicText(
              text: 'الخزينة والمحاسبة المالية',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text('مراقبة التدفق النقدي، المصروفات، والإقفال الدوري',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ).animate().fade().slideX(begin: 0.05),
        Row(
          children: [
            // Date filter
            Obx(() {
              final d = ctrl.selectedDate.value;
              final isToday = d.year == DateTime.now().year && d.month == DateTime.now().month && d.day == DateTime.now().day;
              return NeoButton.outlined(
                label: isToday ? 'اليوم' : '${d.day}/${d.month}/${d.year}',
                icon: Icons.calendar_month,
                color: isToday ? Colors.grey : DesignTokens.neonCyan,
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
            NeoButton(
              label: 'توريد نقدية',
              icon: Icons.account_balance,
              color: DesignTokens.neonGreen,
              onPressed: () => _showTransferDialog(context, ctrl),
            ),
            const SizedBox(width: 8),
            NeoButton(
              label: 'إقفال الفترة',
              icon: Icons.lock_clock,
              color: DesignTokens.neonPurple,
              onPressed: () => _showClosePeriodDialog(context, ctrl),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(13),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(25)),
              ),
              child: Obx(() => ctrl.isLoading.value
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: DesignTokens.neonCyan),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
                      onPressed: ctrl.fetchFinanceSummary,
                      padding: EdgeInsets.zero,
                    )),
            ),
          ],
        ).animate().fade().slideX(begin: -0.05),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SUMMARY CARDS — Liquid Border
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSummaryCards(FinanceController ctrl) {
    return Obx(() => Row(
      children: [
        Expanded(child: _liquidCard('رصيد درج الكاشير', '${ctrl.cashDrawerBalance.value.toStringAsFixed(2)} ج.م',
            Icons.point_of_sale, DesignTokens.neonCyan)),
        const SizedBox(width: DesignTokens.kCardGap),
        Expanded(child: _liquidCard('رصيد الخزينة الرئيسية', '${ctrl.mainTreasuryBalance.value.toStringAsFixed(2)} ج.م',
            Icons.account_balance_wallet, DesignTokens.neonGreen)),
        const SizedBox(width: DesignTokens.kCardGap),
        Expanded(child: _liquidCard('مبيعات اليوم', '${ctrl.todaySales.value.toStringAsFixed(2)} ج.م',
            Icons.trending_up, DesignTokens.neonPurple)),
        const SizedBox(width: DesignTokens.kCardGap),
        Expanded(child: _liquidCard('مصروفات اليوم', '${ctrl.todayExpenses.value.toStringAsFixed(2)} ج.م',
            Icons.money_off, DesignTokens.neonRed)),
      ],
    ));
  }

  Widget _liquidCard(String title, String value, IconData icon, Color color) {
    return DesignTokens.liquidBorderCard(
      height: 120,
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(25),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                DesignTokens.holographicText(
                  text: value,
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: -0.08);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TRANSACTIONS TABLE — Neo-Glass
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTransactionsPanel(BuildContext context, FinanceController ctrl) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.kNeoCardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: DesignTokens.neoGlassDecoration(borderRadius: DesignTokens.kNeoCardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(5),
                    border: Border(bottom: BorderSide(color: Colors.white.withAlpha(13))),
                  ),
                  child: const Text('حركة الخزينة التفصيلية (اليوم)',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                ),
                // Table body
                Expanded(
                  child: Obx(() {
                    if (ctrl.isLoading.value && ctrl.cashTransactions.isEmpty) {
                      return const Center(child: CircularProgressIndicator(color: DesignTokens.neonCyan));
                    }
                    if (ctrl.cashTransactions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 40, color: Colors.white.withAlpha(30)),
                            const SizedBox(height: 8),
                            Text('لا توجد حركات اليوم', style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.white.withAlpha(8)),
                        dataRowColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) return Colors.white.withAlpha(10);
                          return Colors.transparent;
                        }),
                        columns: [
                          DataColumn(label: Text('الوقت', style: _headerStyle())),
                          DataColumn(label: Text('رقم المستند', style: _headerStyle())),
                          DataColumn(label: Text('نوع الحركة', style: _headerStyle())),
                          DataColumn(label: Text('البيان', style: _headerStyle())),
                          DataColumn(label: Text('وارد (+)', style: _headerStyle())),
                          DataColumn(label: Text('صادر (-)', style: _headerStyle())),
                        ],
                        rows: ctrl.cashTransactions.map((tx) {
                          final isIn = (tx['type'] as String? ?? '') == 'in';
                          final amount = (tx['amount'] as num? ?? 0).toStringAsFixed(2);
                          return DataRow(cells: [
                            DataCell(Text(tx['time'] as String? ?? '-', style: TextStyle(color: Colors.grey[300], fontSize: 12))),
                            DataCell(Text(tx['referenceNo'] as String? ?? '-',
                                style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey[400]))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isIn ? DesignTokens.neonGreen : DesignTokens.neonRed).withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(tx['typeName'] as String? ?? '-',
                                  style: TextStyle(
                                    color: isIn ? DesignTokens.neonGreen : DesignTokens.neonRed,
                                    fontWeight: FontWeight.bold, fontSize: 12,
                                  )),
                            )),
                            DataCell(Text(tx['description'] as String? ?? '-',
                                style: TextStyle(color: Colors.grey[300]), overflow: TextOverflow.ellipsis)),
                            DataCell(Text(isIn ? '$amount ج.م' : '-',
                                style: const TextStyle(color: DesignTokens.neonGreen, fontWeight: FontWeight.bold))),
                            DataCell(Text(!isIn ? '$amount ج.م' : '-',
                                style: const TextStyle(color: DesignTokens.neonRed, fontWeight: FontWeight.bold))),
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
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  TextStyle _headerStyle() => TextStyle(
    color: Colors.grey[400],
    fontWeight: FontWeight.w700,
    fontSize: 12,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  //  EXPENSE PANEL — Neo-Glass
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildExpensePanel(BuildContext context, FinanceController ctrl) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = 'operational';

    return DesignTokens.neoGlassBox(
      borderRadius: DesignTokens.kNeoCardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تسجيل مصروف', style: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white,
          )),
          const SizedBox(height: 20),
          // Type dropdown with neo-glass style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: DesignTokens.glassBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DesignTokens.glassBorder),
            ),
            child: DropdownButtonFormField<String>(
              value: selectedType,
              dropdownColor: DesignTokens.cardDark,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'نوع المصروف',
                labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                border: InputBorder.none,
                icon: Icon(Icons.category, color: DesignTokens.neonPurple, size: 20),
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
          ),
          const SizedBox(height: 14),
          NeoTextField(
            controller: amountCtrl,
            label: 'المبلغ (ج.م)',
            icon: Icons.money,
            keyboardType: TextInputType.number,
            focusColor: DesignTokens.neonRed,
          ),
          const SizedBox(height: 14),
          NeoTextField(
            controller: descCtrl,
            label: 'بيان المصروف',
            icon: Icons.description,
            maxLines: 3,
            focusColor: DesignTokens.neonOrange,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: Obx(() => NeoButton(
              label: ctrl.isLoading.value ? 'جاري الحفظ...' : 'خصم من الكاشير',
              icon: Icons.outbox_rounded,
              color: DesignTokens.neonRed,
              isLoading: ctrl.isLoading.value,
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
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.05);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DIALOGS — using NeoDialog
  // ═══════════════════════════════════════════════════════════════════════════

  void _showClosePeriodDialog(BuildContext context, FinanceController ctrl) async {
    final confirmed = await NeoDialog.confirm(
      context,
      title: 'تأكيد إقفال الفترة',
      message: 'سيتم ترحيل الأرباح وإغلاق الفترة المالية الحالية. هذا الإجراء لا يمكن التراجع عنه. هل أنت متأكد؟',
      confirmLabel: 'تأكيد الإقفال',
      cancelLabel: 'إلغاء',
      accentColor: DesignTokens.neonPurple,
    );
    if (confirmed) {
      await ctrl.closePeriod();
    }
  }

  void _showTransferDialog(BuildContext context, FinanceController ctrl) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    NeoDialog.showCustom(
      context,
      title: 'توريد للخزينة الرئيسية',
      accentColor: DesignTokens.neonGreen,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Available balance display
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DesignTokens.neonGreen.withAlpha(13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DesignTokens.neonGreen.withAlpha(50)),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet, color: DesignTokens.neonGreen, size: 20),
              const SizedBox(width: 10),
              Text('الرصيد المتاح بالدرج: ${ctrl.cashDrawerBalance.value.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: DesignTokens.neonGreen, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        NeoTextField(
          controller: amountCtrl,
          label: 'المبلغ المراد توريده',
          icon: Icons.money,
          keyboardType: TextInputType.number,
          focusColor: DesignTokens.neonGreen,
        ),
        const SizedBox(height: 14),
        NeoTextField(
          controller: descCtrl,
          label: 'البيان (اختياري)',
          icon: Icons.description,
          maxLines: 2,
        ),
      ]),
      actions: [
        NeoButton.outlined(label: 'إلغاء', color: Colors.grey, onPressed: () => Get.back()),
        const SizedBox(width: 12),
        NeoButton(
          label: 'تأكيد التوريد',
          icon: Icons.check_circle,
          color: DesignTokens.neonGreen,
          onPressed: () async {
            final amount = double.tryParse(amountCtrl.text) ?? 0;
            if (amount <= 0) return;
            Get.back();
            await ctrl.transferToTreasury(amount, descCtrl.text);
          },
        ),
      ],
    );
  }
}
