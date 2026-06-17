import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/accounting_controller.dart';
import '../../core/theme/design_tokens.dart';

class ChartOfAccountsTab extends StatelessWidget {
  const ChartOfAccountsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AccountingController ctrl = Get.find<AccountingController>();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DesignTokens.holographicText(
                text: 'شجرة الحسابات (Chart of Accounts)',
                style: const TextStyle(fontSize: 20),
              ),
              Obx(() => ctrl.isLoading.value 
                  ? const CircularProgressIndicator(color: DesignTokens.neonCyan)
                  : IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: ctrl.loadChartOfAccounts,
                    )),
            ],
          ),
          const SizedBox(height: 8),
          Text('عرض هرمي لكافة الحسابات بالمؤسسة', style: TextStyle(color: Colors.grey[400])),
          const SizedBox(height: 24),
          Expanded(
            child: Obx(() {
              if (ctrl.chartOfAccounts.isEmpty && ctrl.isLoading.value) {
                return const Center(child: CircularProgressIndicator(color: DesignTokens.neonPurple));
              }

              if (ctrl.chartOfAccounts.isEmpty) {
                return const Center(child: Text('لا توجد حسابات مسجلة', style: TextStyle(color: Colors.white)));
              }

              // Group accounts by parent
              final rootAccounts = ctrl.chartOfAccounts.where((a) => a['parentAccountId'] == null).toList();
              
              return ListView.builder(
                itemCount: rootAccounts.length,
                itemBuilder: (context, index) {
                  return _buildAccountNode(rootAccounts[index], ctrl.chartOfAccounts);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountNode(Map<String, dynamic> account, List<dynamic> allAccounts) {
    final children = allAccounts.where((a) => a['parentAccountId'] == account['id']).toList();
    Color typeColor = _getColorForType(account['type']);

    if (children.isEmpty) {
      return Card(
        color: typeColor.withAlpha(20),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: typeColor.withAlpha(50))),
        child: ListTile(
          dense: true,
          leading: Icon(Icons.article_outlined, color: typeColor),
          title: Text(account['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('كود الحساب: ${account['code']}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: typeColor.withAlpha(30), borderRadius: BorderRadius.circular(6)),
            child: Text(account['type'], style: TextStyle(color: typeColor, fontSize: 10)),
          ),
        ),
      );
    }

    return Card(
      color: Colors.white.withAlpha(5),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: account['parentAccountId'] == null,
        collapsedIconColor: Colors.grey,
        iconColor: typeColor,
        leading: Icon(Icons.folder_open, color: typeColor),
        title: Text('${account['code']} - ${account['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        children: children.map((child) => Padding(
          padding: const EdgeInsets.only(right: 24.0),
          child: _buildAccountNode(child, allAccounts),
        )).toList(),
      ),
    );
  }

  Color _getColorForType(String? type) {
    switch (type) {
      case 'Asset': return DesignTokens.neonCyan;
      case 'Liability': return DesignTokens.neonRed;
      case 'Equity': return DesignTokens.neonPurple;
      case 'Revenue': return DesignTokens.neonGreen;
      case 'Expense': return DesignTokens.neonOrange;
      default: return Colors.grey;
    }
  }
}
