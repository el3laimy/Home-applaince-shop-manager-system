import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/accounting_controller.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/neo_button.dart';
import '../../core/widgets/neo_text_field.dart';

class JournalEntryTab extends StatefulWidget {
  const JournalEntryTab({super.key});

  @override
  State<JournalEntryTab> createState() => _JournalEntryTabState();
}

class _JournalEntryTabState extends State<JournalEntryTab> {
  final AccountingController ctrl = Get.find<AccountingController>();
  final descCtrl = TextEditingController();
  final refCtrl = TextEditingController();
  
  List<Map<String, dynamic>> lines = [
    {'accountId': null, 'debit': 0.0, 'credit': 0.0},
    {'accountId': null, 'debit': 0.0, 'credit': 0.0},
  ];

  double get totalDebit => lines.fold(0.0, (sum, ln) => sum + (ln['debit'] as double));
  double get totalCredit => lines.fold(0.0, (sum, ln) => sum + (ln['credit'] as double));
  bool get isBalanced => totalDebit == totalCredit && totalDebit > 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesignTokens.holographicText(text: 'قيود اليومية اليدوية (Manual Journal Entry)', style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text('تسجيل قيد تسوية محاسبي مزدوج.', style: TextStyle(color: Colors.grey[400])),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(child: NeoTextField(controller: descCtrl, label: 'البيان (وصف القيد)', icon: Icons.description)),
              const SizedBox(width: 16),
              Expanded(child: NeoTextField(controller: refCtrl, label: 'رقم المرجع (اختياري)', icon: Icons.receipt)),
            ],
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: DesignTokens.neoGlassDecoration(borderRadius: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('أطراف القيد المزدوج', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton.icon(
                        icon: const Icon(Icons.add, color: DesignTokens.neonGreen),
                        label: const Text('إضافة طرف', style: TextStyle(color: DesignTokens.neonGreen)),
                        onPressed: () => setState(() => lines.add({'accountId': null, 'debit': 0.0, 'credit': 0.0})),
                      )
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: lines.length,
                      itemBuilder: (context, i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              // Account Dropdown
                              Expanded(
                                flex: 3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Obx(() {
                                    if (ctrl.chartOfAccounts.isEmpty) return const Text('جاري التحميل...', style: TextStyle(color: Colors.white));
                                    // filter to leaf nodes only (accounts that have no children) logic for simplicity is omitted if not trivial, 
                                    // but basically any account is selectable in this raw ERP unless parent constrained.
                                    return DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        dropdownColor: DesignTokens.cardDark,
                                        value: lines[i]['accountId'],
                                        isExpanded: true,
                                        hint: Text('اختر الحساب', style: TextStyle(color: Colors.grey[500])),
                                        items: ctrl.chartOfAccounts.map<DropdownMenuItem<String>>((acc) {
                                          return DropdownMenuItem<String>(
                                            value: acc['id'],
                                            child: Text('${acc['code']} - ${acc['name']}', style: const TextStyle(color: Colors.white)),
                                          );
                                        }).toList(),
                                        onChanged: (v) => setState(() => lines[i]['accountId'] = v),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  style: const TextStyle(color: DesignTokens.neonCyan),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'مدين', 
                                    labelStyle: const TextStyle(color: Colors.grey),
                                    filled: true,
                                    fillColor: Colors.white.withAlpha(5),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (v) => setState(() => lines[i]['debit'] = double.tryParse(v) ?? 0.0),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  style: const TextStyle(color: DesignTokens.neonPurple),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'دائن', 
                                    labelStyle: const TextStyle(color: Colors.grey),
                                    filled: true,
                                    fillColor: Colors.white.withAlpha(5),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (v) => setState(() => lines[i]['credit'] = double.tryParse(v) ?? 0.0),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: lines.length > 2 ? () => setState(() => lines.removeAt(i)) : null,
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          // Balances & Save
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isBalanced ? DesignTokens.neonGreen.withAlpha(20) : DesignTokens.neonRed.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('إجمالي المدين: ${totalDebit.toStringAsFixed(2)}', style: const TextStyle(color: DesignTokens.neonCyan, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 24),
                    Text('إجمالي الدائن: ${totalCredit.toStringAsFixed(2)}', style: const TextStyle(color: DesignTokens.neonPurple, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 24),
                    Text('الفرق: ${(totalDebit - totalCredit).abs().toStringAsFixed(2)}', 
                      style: TextStyle(color: isBalanced ? DesignTokens.neonGreen : DesignTokens.neonRed, fontWeight: FontWeight.bold)),
                  ],
                ),
                Obx(() => NeoButton(
                  label: ctrl.isLoading.value ? 'جاري الحفظ...' : 'حفظ القيد المحاسبي',
                  icon: Icons.save,
                  color: DesignTokens.neonPurple,
                  isLoading: ctrl.isLoading.value,
                  onPressed: isBalanced && lines.every((l) => l['accountId'] != null) ? () async {
                    final success = await ctrl.submitManualJournal(descCtrl.text, refCtrl.text, lines);
                    if (success) {
                      descCtrl.clear();
                      refCtrl.clear();
                      setState(() {
                        lines = [{'accountId': null, 'debit': 0.0, 'credit': 0.0}, {'accountId': null, 'debit': 0.0, 'credit': 0.0}];
                      });
                    }
                  } : null,
                )),
              ],
            ),
          )

        ],
      ),
    );
  }
}
