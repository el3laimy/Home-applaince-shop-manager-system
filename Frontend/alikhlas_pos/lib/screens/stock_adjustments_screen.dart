import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/stock_adjustment_controller.dart';
import '../core/theme/app_theme.dart';
import '../models/product_model.dart';
import 'package:intl/intl.dart';

class StockAdjustmentsScreen extends StatelessWidget {
  const StockAdjustmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final StockAdjustmentController ctrl = Get.put(StockAdjustmentController());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text('تسويات المخزون والهالك', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                       const SizedBox(height: 4),
                       Text('مراقبة المنتجات التالفة وتسوية الجرد إلكترونياً', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                     ],
                   ),
                   ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_box),
                      label: const Text('تسجيل تسوية/إعدام جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _showAddAdjustmentDialog(context, ctrl, isDark),
                   ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Obx(() {
                  if (ctrl.isLoading.value && ctrl.adjustments.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (ctrl.adjustments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('لا توجد سجلات تسوية أو هوالك مضافة', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                        ],
                      ),
                    );
                  }

                  return Container(
                     decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCardColor : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withAlpha(40)),
                     ),
                     child: SingleChildScrollView(
                       child: SizedBox(
                         width: double.infinity,
                         child: DataTable(
                            headingRowColor: WidgetStateProperty.all(isDark ? Colors.black.withAlpha(50) : AppTheme.primaryColor.withAlpha(15)),
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                            columns: const [
                               DataColumn(label: Text('اسم المنتج')),
                               DataColumn(label: Text('نوع التسوية')),
                               DataColumn(label: Text('الكمية')),
                               DataColumn(label: Text('التكلفة')),
                               DataColumn(label: Text('السبب / الملاحظات')),
                               DataColumn(label: Text('التاريخ')),
                               DataColumn(label: Text('المسؤول')),
                            ],
                            rows: ctrl.adjustments.map((adj) {
                               final dateStr = DateTime.parse(adj['createdAt'].toString()).toLocal().toString().split('.')[0];
                               final qty = adj['quantityAdjusted'] as int;
                               final isDesc = qty < 0;
                               return DataRow(cells: [
                                  DataCell(Text(adj['productName'], style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                     decoration: BoxDecoration(
                                        color: isDesc ? Colors.red.withAlpha(30) : Colors.green.withAlpha(30),
                                        borderRadius: BorderRadius.circular(8)
                                     ),
                                     child: Text(adj['typeLabel'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDesc ? Colors.red : Colors.green))
                                  )),
                                  DataCell(Text(qty > 0 ? '+$qty' : '$qty', style: TextStyle(fontWeight: FontWeight.bold, color: isDesc ? Colors.red : Colors.green))),
                                  DataCell(Text('${(adj['cost'] as num).toDouble().toStringAsFixed(2)} ج.م')),
                                  DataCell(Text(adj['reason'])),
                                  DataCell(Text(dateStr, style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(adj['createdBy'], style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                               ]);
                            }).toList(),
                         ),
                       ),
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

  void _showAddAdjustmentDialog(BuildContext context, StockAdjustmentController ctrl, bool isDark) {
    ProductModel? selectedProduct;
    final searchCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    int selectedType = 0; // 0=Damage, 1=Correction, 2=Loss

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('تسجيل تسوية مخزون', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
               width: 500,
               child: SingleChildScrollView(
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Search
                     TextField(
                       controller: searchCtrl,
                       onChanged: (val) {
                         if (val.length > 2) ctrl.searchProducts(val);
                       },
                       decoration: InputDecoration(
                         labelText: 'ابحث عن المنتج بالاسم أو الباركود',
                         prefixIcon: const Icon(Icons.search),
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                     ),
                     const SizedBox(height: 8),
                     Obx(() {
                        if (ctrl.isSearching.value) return const LinearProgressIndicator();
                        if (ctrl.searchResults.isEmpty) return const SizedBox();
                        return Container(
                           height: 120,
                           decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                           child: ListView.builder(
                              itemCount: ctrl.searchResults.length,
                              itemBuilder: (c, i) {
                                 final p = ctrl.searchResults[i];
                                 return ListTile(
                                    title: Text(p.name),
                                    subtitle: Text('المخزون الحالي: ${p.stockQuantity}'),
                                    onTap: () {
                                       setState(() => selectedProduct = p);
                                       ctrl.searchResults.clear();
                                       searchCtrl.text = p.name;
                                    },
                                 );
                              }
                           ),
                        );
                     }),
                     if (selectedProduct != null) ...[
                        const Divider(height: 32),
                        Container(
                           padding: const EdgeInsets.all(12),
                           decoration: BoxDecoration(color: AppTheme.primaryColor.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                           child: Row(
                              children: [
                                 const Icon(Icons.check_circle, color: AppTheme.primaryColor),
                                 const SizedBox(width: 8),
                                 Expanded(child: Text('تم اختيار: ${selectedProduct!.name}\nالمخزون الحالي: ${selectedProduct!.stockQuantity}', style: const TextStyle(fontWeight: FontWeight.bold))),
                              ],
                           ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                           value: selectedType,
                           decoration: InputDecoration(labelText: 'نوع التسوية', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                           items: const [
                              DropdownMenuItem(value: 0, child: Text('هالك / توالف (خصم من المخزون)')),
                              DropdownMenuItem(value: 1, child: Text('تعديل يدوي (إضافة أو خصم)')),
                              DropdownMenuItem(value: 2, child: Text('مفقودات (خصم من المخزون)')),
                           ],
                           onChanged: (v) => setState(() => selectedType = v!),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                             labelText: 'الكمية (${selectedType == 1 ? "بالموجب للإضافة والسالب للخصم" : "الكمية التالفة/المفقودة"})',
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: reasonCtrl,
                          decoration: InputDecoration(labelText: 'سبب التسوية / ملاحظات', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          maxLines: 2,
                        ),
                     ]
                   ],
                 ),
               ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                onPressed: () async {
                  if (selectedProduct == null) return;
                  final qty = int.tryParse(qtyCtrl.text) ?? 0;
                  if (qty == 0) return;
                  if (reasonCtrl.text.isEmpty) { ToastService.showError('يجب كتابة السبب'); return; }

                  bool ok = await ctrl.createAdjustment(selectedProduct!.id, selectedType, qty, reasonCtrl.text);
                  if (ok) Navigator.pop(ctx);
                },
                child: Obx(() => ctrl.isLoading.value 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('حفظ وتسوية', style: TextStyle(color: Colors.white))),
              ),
            ],
          );
        }
      ),
    );
  }
}
