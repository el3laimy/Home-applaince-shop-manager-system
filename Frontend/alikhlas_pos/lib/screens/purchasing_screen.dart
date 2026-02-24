import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/purchasing_controller.dart';
import '../models/product_model.dart';
import '../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class PurchasingScreen extends StatefulWidget {
  const PurchasingScreen({super.key});

  @override
  State<PurchasingScreen> createState() => _PurchasingScreenState();
}

class _PurchasingScreenState extends State<PurchasingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PurchasingController ctrl = Get.put(PurchasingController());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Fetch if needed, though controller does it onInit
    ctrl.fetchAllInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(24),
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
                    _buildSuppliersListTab(context, isDark),
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
                Text('شؤون الموردين والمشتريات',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('إدارة فواتير الشراء، أرصدة الموردين، والدفعات',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ).animate().fade().slideX(begin: 0.1),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.person_add),
              label: const Text('إضافة مورد جديد', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showAddSupplierDialog(context, isDark),
            ).animate().fade().slideX(begin: -0.1),
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
                 Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long), SizedBox(width: 8), Text('فاتورة جديدة')])),
                 Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.domain), SizedBox(width: 8), Text('الموردين وحساباتهم')])),
                 Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history), SizedBox(width: 8), Text('سجل الفواتير')])),
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
                           child: Obx(() => DropdownButtonFormField<String>(
                             value: ctrl.selectedSupplier.value?.id,
                             decoration: InputDecoration(
                               labelText: 'اختر المورد *',
                               prefixIcon: const Icon(Icons.business),
                               filled: true, fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                               border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                             ),
                             hint: const Text('ابحث أو اختر مورد...'),
                             items: ctrl.suppliersWithBalances.map((s) => DropdownMenuItem(
                               value: s['id'] as String,
                               child: Text('${s['name']} (رصيد: ${s['currentBalance']} ج.م)'),
                             )).toList(),
                             onChanged: (id) {
                               if (id != null) ctrl.selectSupplierById(id);
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
                                    child: TextField(
                                      controller: searchCtrl,
                                      onChanged: (val) {
                                         if (val.length > 2) ctrl.searchProducts(val);
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'ابحث بالاسم أو امسح الباركود لإضافة صنف...',
                                        prefixIcon: const Icon(Icons.search),
                                        filled: true, fillColor: isDark ? Colors.black.withAlpha(60) : Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                       padding: const EdgeInsets.all(16),
                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                    ),
                                    onPressed: () => ctrl.searchProducts(searchCtrl.text),
                                    child: const Icon(Icons.search),
                                  )
                               ],
                             ),
                             Obx(() {
                                if (ctrl.isSearchingProducts.value) return const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator());
                                if (ctrl.searchResults.isEmpty && searchCtrl.text.isNotEmpty) {
                                    return const Padding(padding: EdgeInsets.all(8), child: Text('لم يتم العثور على منتج بهذا الاسم/الباركود. أضفه من المخزن أولًا.', style: TextStyle(color: Colors.red)));
                                }
                                if (ctrl.searchResults.isEmpty) return const SizedBox();
                                
                                return Container(
                                   margin: const EdgeInsets.only(top: 8),
                                   height: 120,
                                   child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: ctrl.searchResults.length,
                                      itemBuilder: (ctx, i) {
                                         final p = ctrl.searchResults[i];
                                         return Card(
                                            margin: const EdgeInsets.only(left: 8),
                                            child: InkWell(
                                               borderRadius: BorderRadius.circular(12),
                                               onTap: () => _showAddItemDialog(context, p, isDark),
                                               child: Container(
                                                  width: 160, padding: const EdgeInsets.all(12),
                                                  child: Column(
                                                     mainAxisAlignment: MainAxisAlignment.center,
                                                     crossAxisAlignment: CrossAxisAlignment.start,
                                                     children: [
                                                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                        Text('مخزون: ${p.stockQuantity}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                                        Text('شراء سابق: ${p.purchasePrice} ج', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
                                                     ],
                                                  ),
                                               ),
                                            ),
                                         );
                                      },
                                   ),
                                );
                             }),
                          ]
                       ),
                     ),
                     const SizedBox(height: 16),
                     // Invoice Items Table
                     const Text('الأصناف المضافة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                     const SizedBox(height: 8),
                     Expanded(
                       child: Obx(() => Container(
                         decoration: BoxDecoration(
                           border: Border.all(color: Colors.grey.withAlpha(40)),
                           borderRadius: BorderRadius.circular(12),
                         ),
                         child: ListView.separated(
                           itemCount: ctrl.purchaseItems.length,
                           separatorBuilder: (c, i) => const Divider(height: 1),
                           itemBuilder: (context, index) {
                             final item = ctrl.purchaseItems[index];
                             final total = item['quantity'] * item['unitCost'];
                             return ListTile(
                               leading: CircleAvatar(backgroundColor: AppTheme.primaryColor.withAlpha(20), child: Text('${index + 1}')),
                               title: Text(item['productName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                               subtitle: Text('${item['quantity']} × ${item['unitCost']} ج.م = $total ج.م'),
                               trailing: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => ctrl.updateItemQuantity(index, item['quantity'] - 1)),
                                   Text('${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                   IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => ctrl.updateItemQuantity(index, item['quantity'] + 1)),
                                   const SizedBox(width: 8),
                                   IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => ctrl.removeItem(index)),
                                 ],
                               ),
                             );
                           },
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
                        return Column(
                          children: [
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
                       child: Obx(() => ElevatedButton(
                         style: ElevatedButton.styleFrom(
                           backgroundColor: AppTheme.primaryColor,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                         ),
                         onPressed: ctrl.isLoading.value ? null : () async {
                            final paid = double.tryParse(paidAmountCtrl.text) ?? 0;
                            bool ok = await ctrl.submitInvoice(paid, context);
                            if (ok) {
                               paidAmountCtrl.clear();
                               searchCtrl.clear();
                            }
                         },
                         child: ctrl.isLoading.value
                             ? const CircularProgressIndicator(color: Colors.white)
                             : const Text('ترحيل للمخزن والحسابات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                       )),
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

  void _showAddItemDialog(BuildContext context, ProductModel product, bool isDark) {
      final qtyCtrl = TextEditingController(text: '1');
      final costCtrl = TextEditingController(text: product.purchasePrice.toString());
      
      showDialog(context: context, builder: (ctx) {
         return AlertDialog(
            title: Text('إضافة: ${product.name}'),
            content: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                  TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية المشتراة')),
                  const SizedBox(height: 12),
                  TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الشراء للوحدة (ج.م)')),
               ],
            ),
            actions: [
               TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
               ElevatedButton(
                 onPressed: () {
                    final q = double.tryParse(qtyCtrl.text) ?? 1;
                    final c = double.tryParse(costCtrl.text) ?? product.purchasePrice;
                    ctrl.addItemToInvoice(product, q, c);
                    Navigator.pop(ctx);
                 },
                 child: const Text('إضافة לפاتورة'),
               )
            ],
         );
      });
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
  // TAB 2: SUPPLIERS LIST & BALANCES
  // ==========================================
  Widget _buildSuppliersListTab(BuildContext context, bool isDark) {
    return Obx(() {
      if (ctrl.isLoadingSuppliers.value && ctrl.suppliersWithBalances.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (ctrl.suppliersWithBalances.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.business, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('لا يوجد موردين بعد', style: TextStyle(fontSize: 20, color: Colors.grey)),
            ],
          ),
        );
      }
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
           crossAxisCount: 3, childAspectRatio: 1.5, crossAxisSpacing: 16, mainAxisSpacing: 16
        ),
        itemCount: ctrl.suppliersWithBalances.length,
        itemBuilder: (ctx, i) {
           final s = ctrl.suppliersWithBalances[i];
           final balance = (s['currentBalance'] as num).toDouble();
           final hasDebt = balance > 0;
           final currencyFmt = NumberFormat.currency(symbol: 'ج.م ', decimalDigits: 2);

           return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                 padding: const EdgeInsets.all(20),
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Expanded(child: Text(s['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                           Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: hasDebt ? Colors.red.withAlpha(30) : Colors.green.withAlpha(30), borderRadius: BorderRadius.circular(20)),
                              child: Text(hasDebt ? 'عليه أرصدة' : 'مسوَّى', style: TextStyle(color: hasDebt ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                           )
                         ],
                       ),
                       const SizedBox(height: 8),
                       Text('📞 ${s['phone'] ?? 'لا يوجد رقم'}', style: TextStyle(color: Colors.grey[600])),
                       const Spacer(),
                       const Divider(),
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                            const Text('رصيد المديونية:'),
                            Text(currencyFmt.format(balance), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: hasDebt ? Colors.red : Colors.green)),
                         ],
                       ),
                       const SizedBox(height: 12),
                       SizedBox(
                         width: double.infinity,
                         child: OutlinedButton.icon(
                            icon: const Icon(Icons.payment),
                            label: const Text('تسجيل دفعة لمورد'),
                            style: OutlinedButton.styleFrom(
                               foregroundColor: AppTheme.primaryColor,
                               side: const BorderSide(color: AppTheme.primaryColor),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showPaymentDialog(context, s['id'], s['name'], balance),
                         ),
                       )
                    ],
                 ),
              ),
           ).animate().fadeIn(delay: (i * 50).ms).slideY(begin: 0.1);
        },
      );
    });
  }

  void _showPaymentDialog(BuildContext context, String id, String name, double currentBalance) {
     final amountCtrl = TextEditingController(text: currentBalance > 0 ? currentBalance.toString() : '');
     final notesCtrl = TextEditingController(text: 'دفعة حساب');
     showDialog(context: context, builder: (ctx) {
        return AlertDialog(
           title: Text('تسجيل دفعة للمورد: $name'),
           content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text('المديونية الحالية: ${currentBalance.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 16),
                 TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المدفوع (كاش)', border: OutlineInputBorder())),
                 const SizedBox(height: 12),
                 TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات', border: OutlineInputBorder())),
              ],
           ),
           actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                onPressed: () async {
                   final am = double.tryParse(amountCtrl.text) ?? 0;
                   if (am <= 0) return;
                   bool ok = await ctrl.registerSupplierPayment(id, am, notesCtrl.text, context);
                   if (ok) Navigator.pop(ctx);
                },
                child: const Text('تسجيل سحب كاش وتخفيض مديونية'),
              )
           ],
        );
     });
  }

  // ==========================================
  // TAB 3: INVOICE HISTORY
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

  void _showAddSupplierDialog(BuildContext context, bool isDark) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final openingBalanceCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مورد جديد', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المورد *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: companyCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                 controller: openingBalanceCtrl,
                 keyboardType: TextInputType.number,
                 decoration: const InputDecoration(labelText: 'رصيد افتتاحي (مديونية سابقة)', border: OutlineInputBorder())
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              bool success = await ctrl.addSupplier({
                 'name': nameCtrl.text,
                 'phone': phoneCtrl.text,
                 'companyName': companyCtrl.text,
                 'address': addressCtrl.text,
                 'openingBalance': double.tryParse(openingBalanceCtrl.text) ?? 0,
              }, context);
              if (success) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
