import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/accounting_controller.dart';
import '../../core/theme/design_tokens.dart';

class FinancialReportsTab extends StatelessWidget {
  const FinancialReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AccountingController>();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DesignTokens.holographicText(text: 'التقارير المالية والختامية', style: const TextStyle(fontSize: 20)),
              _buildDateFilters(context, ctrl),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: DesignTokens.neonCyan,
                    labelColor: DesignTokens.neonCyan,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(icon: Icon(Icons.balance), text: 'ميزان المراجعة'),
                      Tab(icon: Icon(Icons.show_chart), text: 'قائمة الدخل (الأرباح والخسائر)'),
                      Tab(icon: Icon(Icons.account_balance), text: 'الميزانية العمومية'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildTrialBalance(ctrl),
                        _buildIncomeStatement(ctrl),
                        _buildBalanceSheet(ctrl),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilters(BuildContext context, AccountingController ctrl) {
    return Row(
      children: [
        Obx(() => TextButton.icon(
          icon: const Icon(Icons.date_range, color: DesignTokens.neonPurple),
          label: Text(ctrl.selectedFromDate.value != null ? 'من: ${ctrl.selectedFromDate.value.toString().split(' ')[0]}' : 'تاريخ البداية', style: const TextStyle(color: Colors.white)),
          onPressed: () async {
            final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
            if (date != null) ctrl.selectedFromDate.value = date;
          },
        )),
        const SizedBox(width: 8),
        Obx(() => TextButton.icon(
          icon: const Icon(Icons.date_range, color: DesignTokens.neonCyan),
          label: Text(ctrl.selectedToDate.value != null ? 'إلى: ${ctrl.selectedToDate.value.toString().split(' ')[0]}' : 'تاريخ النهاية', style: const TextStyle(color: Colors.white)),
          onPressed: () async {
            final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
            if (date != null) ctrl.selectedToDate.value = date;
          },
        )),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.neonGreen.withAlpha(50), foregroundColor: DesignTokens.neonGreen),
          icon: const Icon(Icons.refresh),
          label: const Text('تحديث'),
          onPressed: ctrl.refreshReports,
        ),
      ],
    );
  }

  Widget _buildTrialBalance(AccountingController ctrl) {
    return Obx(() {
      if (ctrl.isLoading.value && ctrl.trialBalanceData.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: DesignTokens.neonCyan));
      }
      
      final data = ctrl.trialBalanceData;
      if (data.isEmpty || data['accounts'] == null) return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white)));
      
      final accounts = data['accounts'] as List<dynamic>;
      final tDebit = data['totalDebit'] as num;
      final tCredit = data['totalCredit'] as num;
      final isBal = data['isBalanced'] as bool;

      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: (isBal ? DesignTokens.neonGreen : DesignTokens.neonRed).withAlpha(20), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('إجمالي المدين: ${tDebit.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('إجمالي الدائن: ${tCredit.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Icon(isBal ? Icons.check_circle : Icons.warning, color: isBal ? DesignTokens.neonGreen : DesignTokens.neonRed),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.white.withAlpha(10)),
                columns: const [
                  DataColumn(label: Text('كود الحساب', style: TextStyle(color: Colors.white))),
                  DataColumn(label: Text('اسم الحساب', style: TextStyle(color: Colors.white))),
                  DataColumn(label: Text('رصيد مدين', style: TextStyle(color: DesignTokens.neonCyan))),
                  DataColumn(label: Text('رصيد دائن', style: TextStyle(color: DesignTokens.neonPurple))),
                ],
                rows: accounts.map((acc) {
                  final bal = (acc['balance'] as num).toDouble();
                  return DataRow(cells: [
                    DataCell(Text(acc['code'], style: TextStyle(color: Colors.grey[400]))),
                    DataCell(Text(acc['name'], style: const TextStyle(color: Colors.white))),
                    DataCell(Text(bal > 0 ? bal.toStringAsFixed(2) : '-', style: const TextStyle(color: DesignTokens.neonCyan))),
                    DataCell(Text(bal < 0 ? bal.abs().toStringAsFixed(2) : '-', style: const TextStyle(color: DesignTokens.neonPurple))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildIncomeStatement(AccountingController ctrl) {
    return Obx(() {
      if (ctrl.isLoading.value && ctrl.incomeStatementData.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: DesignTokens.neonPurple));
      }

      final data = ctrl.incomeStatementData;
      if (data.isEmpty) return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white)));

      final revenues = data['revenues'] as List<dynamic>? ?? [];
      final expenses = data['expenses'] as List<dynamic>? ?? [];
      final netIncome = (data['netIncome'] as num?)?.toDouble() ?? 0;

      return SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildReportSection('الإيرادات (Revenues)', revenues, DesignTokens.neonGreen)),
            const SizedBox(width: 16),
            Expanded(child: _buildReportSection('المصروفات (Expenses)', expenses, DesignTokens.neonRed)),
            const SizedBox(width: 16),
            Container(
              width: 250,
              padding: const EdgeInsets.all(24),
              decoration: DesignTokens.neoGlassDecoration(borderRadius: 16),
              child: Column(
                children: [
                  const Icon(Icons.attach_money, size: 48, color: DesignTokens.neonPurple),
                  const SizedBox(height: 16),
                  const Text('صافي الربح / الخسارة', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    '${netIncome.toStringAsFixed(2)} ج.م',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: netIncome >= 0 ? DesignTokens.neonGreen : DesignTokens.neonRed,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      );
    });
  }

  Widget _buildBalanceSheet(AccountingController ctrl) {
    return Obx(() {
      if (ctrl.isLoading.value && ctrl.balanceSheetData.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: DesignTokens.neonCyan));
      }

      final data = ctrl.balanceSheetData;
      if (data.isEmpty) return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white)));

      final assets = data['assets'] as List<dynamic>? ?? [];
      final liabilities = data['liabilities'] as List<dynamic>? ?? [];
      final equity = data['equity'] as List<dynamic>? ?? [];
      final tAssets = data['totalAssets'] as num? ?? 0;
      final tLiabilities = data['totalLiabilities'] as num? ?? 0;
      final tEquity = data['totalEquity'] as num? ?? 0;
      final isBal = data['isBalanced'] as bool? ?? false;

      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: (isBal ? DesignTokens.neonGreen : DesignTokens.neonRed).withAlpha(20), borderRadius: BorderRadius.circular(8)),
            child: Text(isBal ? ' الميزانية متوازنة المليم (الأصول = الخصوم + حقوق الملكية)' : ' الميزانية غير متوازنة!', style: TextStyle(color: isBal ? DesignTokens.neonGreen : DesignTokens.neonRed, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildReportSection('الأصول (Assets)', assets, DesignTokens.neonCyan),
                        const SizedBox(height: 8),
                        Text('إجمالي الأصول: ${tAssets.toStringAsFixed(2)}', style: const TextStyle(color: DesignTokens.neonCyan, fontWeight: FontWeight.bold, fontSize: 16))
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _buildReportSection('الخصوم (Liabilities)', liabilities, DesignTokens.neonOrange),
                        const SizedBox(height: 16),
                        _buildReportSection('حقوق الملكية (Equity)', equity, DesignTokens.neonPurple),
                        const SizedBox(height: 8),
                        Text('إجمالي الالتزامات والملكية: ${(tLiabilities + tEquity).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      );
    });
  }

  Widget _buildReportSection(String title, List<dynamic> items, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        border: Border(top: BorderSide(color: accentColor, width: 3)),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(color: Colors.white24),
          ...items.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e['name'], style: const TextStyle(color: Colors.white)),
                Text('${(e['balance'] as num).abs().toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[300], fontWeight: FontWeight.bold)),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}
