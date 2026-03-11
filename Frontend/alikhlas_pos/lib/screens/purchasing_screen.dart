import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/purchasing_controller.dart';
import '../models/product_model.dart';
import '../models/supplier_model.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import 'package:intl/intl.dart';
import '../core/utils/toast_service.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../widgets/create_purchase_order_modal.dart';

class PurchasingScreen extends StatefulWidget {
  const PurchasingScreen({super.key});

  @override
  State<PurchasingScreen> createState() => _PurchasingScreenState();
}

class _PurchasingScreenState extends State<PurchasingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PurchasingController ctrl = Get.find<PurchasingController>();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Tab controller length reduced to 2 (New Invoice, History). Suppliers will be handled by SuppliersScreen
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesignTokens.neoPageBackgroundWidget(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.kPagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, isDark),
              const SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNewInvoiceTab(context, isDark),
                    _buildInvoiceHistoryTab(context, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DesignTokens.holographicText(
                  text: 'المشتريات وإدارة الفواتير',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 4),
                Text('إدخال فواتير الشراء وسجل التعاملات السابقة',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ).animate().fade().slideX(begin: 0.05),
            ElevatedButton.icon(
              onPressed: () => Get.dialog(const CreatePurchaseOrderModal()),
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('إنشاء طلب شراء (Stitch Design)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
           decoration: BoxDecoration(
              color: isDark ? Colors.black.withAlpha(50) : Colors.white.withAlpha(150),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withAlpha(40)),
           ),
           child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                 borderRadius: BorderRadius.circular(12),
                 color: AppTheme.primaryColor,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[800],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              tabs: const [
                 Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long), SizedBox(width: 8), Text('إدخال فاتورة جديدة')])),
                 Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history), SizedBox(width: 8), Text('سجل المشتريات')])),
              ],
           ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 1: NEW INVOICE
  // ==========================================
  Widget _buildNewInvoiceTab(BuildContext context, bool isDark) {
     final searchCtrl = TextEditingController();
     final paidAmountCtrl = TextEditingController();

     return Row(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         // Left Side: Invoice Items & Form
         Expanded(
           flex: 3,
           child: ClipRRect(
             borderRadius: BorderRadius.circular(20),
             child: BackdropFilter(
               filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
               child: Container(
                 padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(
                   color: isDark ? Colors.white.withAlpha(8) : Colors.white.withAlpha(200),
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(color: Colors.white.withAlpha(isDark ? 20 : 60)),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Top Row: Supplier & Ref Number
                     Row(
                       children: [
                         Expanded(
                            child: Obx(() => DropdownSearch<SupplierModel>(
                                popupProps: PopupProps.menu(
                                  showSearchBox: true,
                                  searchFieldProps: TextFieldProps(
                                    decoration: InputDecoration(
                                      hintText: "ابحث عن المورد...",
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                                items: (filter, props) => ctrl.suppliersWithBalances.toList(),
                                itemAsString: (SupplierModel s) => s.name,
                                compareFn: (SupplierModel i, SupplierModel s) => i.id == s.id,
                                decoratorProps: DropDownDecoratorProps(
                                  decoration: InputDecoration(
                                    labelText: "اختر المورد *",
                                    prefixIcon: const Icon(Icons.person),
                                    filled: true,
                                    fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                onChanged: (SupplierModel? s) {
                                  if (s != null) ctrl.selectSupplierById(s.id);
                                },
                                selectedItem: ctrl.selectedSupplier.value,
                                dropdownBuilder: (context, selectedItem) {
                                  if (selectedItem == null) return const Text("لم يتم اختيار مورد");
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(selectedItem.name),
                                      Text(
                                        'الرصيد: ${selectedItem.currentBalance ?? 0} ج.م', 
                                        style: TextStyle(color: (selectedItem.currentBalance ?? 0) > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)
                                      ),
                                    ],
                                  );
                                },
                            )),
                         ),
                         const SizedBox(width: 16),
                         Expanded(
                           child: TextField(
                             onChanged: (val) => ctrl.referenceNumber.value = val,
                             decoration: InputDecoration(
                               labelText: 'رقم الفاتورة الورقية (اختياري)',
                               prefixIcon: const Icon(Icons.numbers),
                               filled: true, fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                               border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                             ),
                           ),
                         ),
                       ],
                     ),
                     const Divider(height: 32),
                     // Product Search Section
                     Container(
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: isDark ? Colors.black.withAlpha(50) : AppTheme.primaryColor.withAlpha(15),
                         borderRadius: BorderRadius.circular(16),
                       ),
                       child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Row(
                               children: [
                                  Expanded(
                                    child: RawKeyboardListener(
                                      focusNode: FocusNode(),
                                      onKey: (event) {
                                        // Optional: handle physical enter key
                                      },
                                      child: TextField(
                                        controller: searchCtrl,
                                        focusNode: _searchFocusNode,
                                        autofocus: true,
                                        onChanged: (val) {
                                          EasyDebounce.debounce(
                                            'product-search',
                                            const Duration(milliseconds: 300),
                                            () {
                                              if (val.length > 2) ctrl.searchProducts(val);
                                            }
                                          );
                                        },
                                        decoration: InputDecoration(
                                          hintText: 'امسح الباركود أو ابحث باسم الصنف (يضاف تلقائياً)...',
                                          prefixIcon: const Icon(Icons.qr_code_scanner),
                                          filled: true, fillColor: isDark ? Colors.black.withAlpha(60) : Colors.white,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        ),
                                        onSubmitted: (val) {
                                           // If scanner sends 'Enter' key
                                           ctrl.searchProducts(val);
                                           searchCtrl.clear();
                                           _searchFocusNode.requestFocus();
                                        },
                                      ),
                                    ),
                                  ),
                               ],
                             ),
                             Obx(() {
                                if (ctrl.isSearchingProducts.value) return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
                                if (ctrl.searchResults.isEmpty && searchCtrl.text.isNotEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.add_box),
                                        label: const Text('إضافة كصنف جديد للمخزن'),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                                        onPressed: () {
                                           // Optional: Show dialog
                                        },
                                      ),
                                    );
                                }
                                if (ctrl.searchResults.isEmpty) return const SizedBox();
                                
                                return Container(
                                   margin: const EdgeInsets.only(top: 8),
                                   decoration: BoxDecoration(
                                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.withAlpha(50)),
                                   ),
                                   height: 150,
                                   child: ListView.builder(
                                      itemCount: ctrl.searchResults.length,
                                      itemBuilder: (ctx, i) {
                                         final p = ctrl.searchResults[i];
                                         return ListTile(
                                            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            subtitle: Text('باركود: ${p.globalBarcode ?? "لا يوجد"} | مخزون: ${p.stockQuantity}'),
                                            trailing: Text('شراء: ${p.purchasePrice} ج', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                                            onTap: () {
                                              ctrl.addItemToInvoice(p, 1.0, p.purchasePrice);
                                              searchCtrl.clear();
                                              ctrl.searchResults.clear();
                                              _searchFocusNode.requestFocus();
                                            },
                                         );
                                      },
                                   ),
                                );
                             }),
                          ]
                       ),
                     ),
                     const SizedBox(height: 16),
                     // Invoice Items Table (Inline Editing)
                     const Text('الأصناف المضافة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                     const SizedBox(height: 8),
                     Expanded(
                       child: Obx(() => Container(
                         decoration: BoxDecoration(
                           border: Border.all(color: Colors.grey.withAlpha(40)),
                           borderRadius: BorderRadius.circular(12),
                           color: isDark ? Colors.black.withAlpha(20) : Colors.white,
                         ),
                         child: Column(
                           children: [
                             // Table Header
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                               decoration: BoxDecoration(
                                 color: isDark ? Colors.black.withAlpha(50) : Colors.grey[200],
                                 borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                               ),
                               child: Row(
                                 children: const [
                                   Expanded(flex: 3, child: Text('الصنف', style: TextStyle(fontWeight: FontWeight.bold))),
                                   Expanded(flex: 2, child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                   Expanded(flex: 2, child: Text('سعر الشراء', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                   Expanded(flex: 2, child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                   SizedBox(width: 40), // For delete button
                                 ],
                               ),
                             ),
                             // Table Body
                             Expanded(
                               child: ListView.separated(
                                 itemCount: ctrl.purchaseItems.length,
                                 separatorBuilder: (c, i) => const Divider(height: 1),
                                 itemBuilder: (context, index) {
                                   final item = ctrl.purchaseItems[index];
                                   
                                   return Padding(
                                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                     child: Row(
                                       children: [
                                         Expanded(flex: 3, child: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                         Expanded(
                                           flex: 2,
                                           child: Padding(
                                             padding: const EdgeInsets.symmetric(horizontal: 8),
                                             child: TextFormField(
                                               initialValue: item.quantity.toString(),
                                               keyboardType: TextInputType.number,
                                               textAlign: TextAlign.center,
                                               decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()),
                                               onChanged: (val) {
                                                 final q = double.tryParse(val) ?? 0;
                                                 ctrl.updateItemQuantity(index, q);
                                               },
                                             ),
                                           ),
                                         ),
                                         Expanded(
                                           flex: 2,
                                           child: Padding(
                                             padding: const EdgeInsets.symmetric(horizontal: 8),
                                             child: TextFormField(
                                               initialValue: item.unitCost.toString(),
                                               keyboardType: TextInputType.number,
                                               textAlign: TextAlign.center,
                                               decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()),
                                               onChanged: (val) {
                                                 final c = double.tryParse(val) ?? 0;
                                                 ctrl.updateItemCost(index, c);
                                               },
                                             ),
                                           ),
                                         ),
                                         Expanded(
                                           flex: 2,
                                           child: Text('${item.total.toStringAsFixed(2)} ج.م', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                                         ),
                                         IconButton(
                                           icon: const Icon(Icons.delete, color: Colors.red),
                                           onPressed: () => ctrl.removeItem(index),
                                         ),
                                       ],
                                     ),
                                   );
                                 },
                               ),
                             ),
                           ],
                         ),
                       )),
                     ),
                   ],
                 ),
               ),
             ),
           ),
         ),
         const SizedBox(width: 20),
         // Right Side: Summary & Payment
         SizedBox(
           width: 320,
           child: ClipRRect(
             borderRadius: BorderRadius.circular(20),
             child: BackdropFilter(
               filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
               child: Container(
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(
                   color: isDark ? Colors.white.withAlpha(5) : Colors.white.withAlpha(180),
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(color: Colors.white.withAlpha(isDark ? 20 : 60)),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text('ملخص الفاتورة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                     const Divider(height: 32),
                     Obx(() => _summaryRow('الإجمالي', '${ctrl.invoiceTotal.toStringAsFixed(2)} ج.م', isBold: true, size: 18)),
                     const SizedBox(height: 16),
                     TextField(
                       controller: paidAmountCtrl,
                       keyboardType: TextInputType.number,
                       onChanged: (val) => setState((){}), // rebuild to update remaining
                       decoration: InputDecoration(
                         labelText: 'المدفوع نقداً',
                         prefixIcon: const Icon(Icons.payments),
                         filled: true, fillColor: isDark ? Colors.black.withAlpha(30) : Colors.white,
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                     ),
                     const SizedBox(height: 16),
                     Obx(() {
                        final paid = double.tryParse(paidAmountCtrl.text) ?? 0;
                        final remaining = ctrl.invoiceTotal - paid;
                        final isOverBalance = paid > ctrl.safeBalance.value && paid > 0;
                        return Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             if (isOverBalance)
                                Padding(
                                   padding: const EdgeInsets.only(bottom: 8.0),
                                   child: Text('عفواً، رصيد الخزينة الحالي (${ctrl.safeBalance.value} ج.م) لا يكفي!', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                             _summaryRow('المتبقي (مديونية)', '${remaining.toStringAsFixed(2)} ج.م', isBold: true, color: remaining > 0 ? Colors.red : Colors.green),
                            if (remaining > 0)
                               Padding(
                                 padding: const EdgeInsets.only(top: 8.0),
                                 child: Row(
                                   children: const [
                                      Icon(Icons.warning, color: Colors.orange, size: 16),
                                      SizedBox(width: 4),
                                      Expanded(child: Text('سيُضاف هذا المبلغ لحساب المورد', style: TextStyle(color: Colors.orange, fontSize: 12))),
                                   ],
                                 ),
                               ),
                          ],
                        );
                     }),
                     const Spacer(),
                     SizedBox(
                       width: double.infinity,
                       height: 56,
                       child: Obx(() {
                         final paid = double.tryParse(paidAmountCtrl.text) ?? 0;
                         final isForbidden = ctrl.isLoading.value || (paid > ctrl.safeBalance.value && paid > 0);
                         return Row(
                           children: [
                             Expanded(
                               child: ElevatedButton(
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: isForbidden ? Colors.grey : Colors.orange,
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                 ),
                                 onPressed: isForbidden ? null : () async {
                                    bool ok = await ctrl.submitInvoice(paid, context, status: 'Draft');
                                  if (ok) {
                                     paidAmountCtrl.clear();
                                     searchCtrl.clear();
                                    }
                                 },
                                 child: ctrl.isLoading.value 
                                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                                    : const Text('حفظ كمسودة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                               ),
                             ),
                             const SizedBox(width: 8),
                             Expanded(
                               child: ElevatedButton(
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: isForbidden ? Colors.grey : AppTheme.primaryColor,
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                 ),
                                 onPressed: isForbidden ? null : () async {
                                    bool ok = await ctrl.submitInvoice(paid, context);
                                  if (ok) {
                                     paidAmountCtrl.clear();
                                     searchCtrl.clear();
                                    }
                                 },
                                 child: ctrl.isLoading.value 
                                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                                    : const Text('ترحيل الفاتورة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                               ),
                             ),
                           ],
                         );
                       }),
                     ),
                   ],
                 ),
               ),
             ),
           ),
         ),
       ],
     ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, double size = 14, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: size, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.grey[600])),
        Text(value, style: TextStyle(fontSize: size, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
      ],
    );
  }

  // ==========================================
  // TAB 2: INVOICE HISTORY
  // ==========================================
  Widget _buildInvoiceHistoryTab(BuildContext context, bool isDark) {
    return Obx(() {
      if (ctrl.isLoadingInvoices.value && ctrl.allInvoices.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (ctrl.allInvoices.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('لا يوجد سجل فواتير بعد', style: TextStyle(fontSize: 20, color: Colors.grey)),
            ],
          ),
        );
      }
      return ClipRRect(
         borderRadius: BorderRadius.circular(20),
         child: Container(
            color: isDark ? Colors.white.withAlpha(10) : Colors.white,
            child: SingleChildScrollView(
               child: SizedBox(
                 width: double.infinity,
                 child: DataTable(
                    headingRowColor: WidgetStateProperty.all(isDark ? Colors.black.withAlpha(50) : AppTheme.primaryColor.withAlpha(15)),
                    columns: const [
                       DataColumn(label: Text('رقم الفاتورة')),
                       DataColumn(label: Text('المورد')),
                       DataColumn(label: Text('تاريخ الفاتورة')),
                       DataColumn(label: Text('الإجمالي')),
                       DataColumn(label: Text('المدفوع')),
                       DataColumn(label: Text('المتبقي (مديونية)')),
                    ],
                    rows: ctrl.allInvoices.map((inv) {
                       final fmtDate = DateTime.parse(inv['createdAt'].toString()).toLocal().toString().split('.')[0];
                       final isPaidFull = (inv['remainingAmount'] as num) == 0;
                       return DataRow(cells: [
                          DataCell(Text(inv['invoiceNo'] ?? '-')),
                          DataCell(Text(inv['supplier'] != null ? inv['supplier']['name'] : 'غير معروف', style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(fmtDate)),
                          DataCell(Text('${inv['netAmount']} ج')),
                          DataCell(Text('${inv['paidAmount']} ج', style: const TextStyle(color: Colors.green))),
                          DataCell(Text('${inv['remainingAmount']} ج', style: TextStyle(color: isPaidFull ? Colors.green : Colors.red, fontWeight: FontWeight.bold))),
                       ]);
                    }).toList(),
                 ),
               ),
            ),
         ),
      ).animate().fadeIn();
    });
  }
}
