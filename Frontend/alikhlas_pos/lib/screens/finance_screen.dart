import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/accounting_controller.dart';
import '../core/theme/design_tokens.dart';

import 'accounting_tabs/treasury_tab.dart';
import 'accounting_tabs/coa_tab.dart';
import 'accounting_tabs/journal_tab.dart';
import 'accounting_tabs/reports_tab.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Shared controller for Accounting tabs
    final AccountingController ctrl = Get.put(AccountingController());

    return DesignTokens.neoPageBackgroundWidget(
      child: SafeArea(
        child: Row(
          children: [
            // Inner Sidebar for Navigation between Accounting features
            _buildSideRail(ctrl),
            // Main Content Area
            Expanded(
              child: Obx(() {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _buildCurrentTab(ctrl.currentTab.value),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return const TreasuryTab(key: ValueKey(0));
      case 1:
        return const ChartOfAccountsTab(key: ValueKey(1));
      case 2:
        return const JournalEntryTab(key: ValueKey(2));
      case 3:
        return const FinancialReportsTab(key: ValueKey(3));
      default:
        return const TreasuryTab(key: ValueKey(0));
    }
  }

  Widget _buildSideRail(AccountingController ctrl) {
    return Container(
      width: 250,
      margin: const EdgeInsets.only(left: 16, top: 16, bottom: 16),
      decoration: DesignTokens.neoGlassDecoration(borderRadius: 16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.account_balance, size: 48, color: DesignTokens.neonPurple),
          const SizedBox(height: 12),
          const Text('الخزينة والمحاسبة',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          
          Expanded(
            child: Obx(() => ListView(
              children: [
                _navItem(ctrl, 0, 'الخزينة وحركة النقدية', Icons.point_of_sale, DesignTokens.neonCyan),
                _navItem(ctrl, 1, 'دليل الحسابات (COA)', Icons.account_tree, DesignTokens.neonGreen),
                _navItem(ctrl, 2, 'قيود اليومية', Icons.edit_document, DesignTokens.neonOrange),
                _navItem(ctrl, 3, 'التقارير المالية والختامية', Icons.analytics, DesignTokens.neonPurple),
              ],
            )),
          ),
        ],
      ).animate().fadeIn().slideX(begin: -0.1),
    );
  }

  Widget _navItem(AccountingController ctrl, int index, String label, IconData icon, Color accentColor) {
    final bool isSelected = ctrl.currentTab.value == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => ctrl.switchTab(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? accentColor.withAlpha(100) : Colors.transparent),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? accentColor : Colors.grey[500]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
