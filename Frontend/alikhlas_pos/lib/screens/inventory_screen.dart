import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/inventory_controller.dart';
import '../models/product_model.dart';
import '../core/theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/barcode_print_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // Add Product Form Controllers
  final nameCtrl = TextEditingController();
  final barcodeCtrl = TextEditingController();
  final purchasePriceCtrl = TextEditingController();
  final salePriceCtrl = TextEditingController();
  final stockCtrl = TextEditingController();
  
  // Custom Category State
  String? selectedFormCategory;
  final customCategoryCtrl = TextEditingController();
  bool isCustomCategory = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(InventoryController());
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
              _buildHeader(context, ctrl, isDark),
              const SizedBox(height: 16),
              _buildStatsRow(context, ctrl, isDark),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildInventoryTable(context, ctrl, isDark)),
                    const SizedBox(width: 20),
                    SizedBox(width: 320, child: _buildAddProductPanel(context, ctrl, isDark)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, InventoryController ctrl, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إدارة المخزون والمنتجات',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Obx(() => Text(
              '${ctrl.totalCount} منتج إجمالي — ${ctrl.lowStockProducts.length} وصل لحد التنبيه',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            )),
          ],
        ).animate().fade().slideX(begin: 0.1),
        Row(
          children: [
            _buildFilterChip('نقص المخزون', Icons.warning_amber_rounded, Colors.orange, ctrl),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => ctrl.fetchProducts(reset: true),
            ),
          ],
        ).animate().fade().slideX(begin: -0.1),
      ],
    );
  }

  Widget _buildFilterChip(String label, IconData icon, Color color, InventoryController ctrl) {
    return Obx(() => FilterChip(
      selected: ctrl.showLowStockOnly.value,
      onSelected: (val) {
        ctrl.showLowStockOnly.value = val;
        ctrl.fetchProducts(reset: true);
      },
      avatar: Icon(icon, color: color, size: 16),
      label: Text(label),
      selectedColor: color.withAlpha(30),
      checkmarkColor: color,
    ));
  }

  Widget _buildStatsRow(BuildContext context, InventoryController ctrl, bool isDark) {
    return Obx(() => Row(
      children: [
        _buildStatCard(context, 'إجمالي الأصناف', '${ctrl.totalCount}', Icons.inventory_2, const Color(0xFF6C63FF), isDark),
        const SizedBox(width: 16),
        _buildStatCard(context, 'منخفض المخزون', '${ctrl.lowStockProducts.length}', Icons.warning_amber_rounded, Colors.orange, isDark),
        const SizedBox(width: 16),
        _buildStatCard(context, 'صفحة حالية', '${ctrl.currentPage}', Icons.pages, AppTheme.secondaryColor, isDark),
      ],
    ));
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(8) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          children: [
            Container(
               padding: const EdgeInsets.all(10),
               decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(25)),
               child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                 Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(delay: 100.ms),
    );
  }

  Widget _buildInventoryTable(BuildContext context, InventoryController ctrl, bool isDark) {
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
            children: [
              // Search bar & Category filter
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'ابحث بالاسم أو الباركود أو الفئة...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: ctrl.onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Obx(() => DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                           color: isDark ? Colors.black.withAlpha(40) : Colors.white,
                           borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: ctrl.selectedCategory.value.isEmpty ? null : ctrl.selectedCategory.value,
                          hint: const Text('جميع الفئات'),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('الكل')),
                            ...ctrl.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                          ],
                          onChanged: (val) {
                            ctrl.selectedCategory.value = val ?? '';
                            ctrl.fetchProducts(reset: true);
                          },
                        ),
                      ),
                    )),
                  ],
                ),
              ),
              // Table
              Expanded(
                child: Obx(() {
                  if (ctrl.isLoading.value && ctrl.products.isEmpty) {
                     return const Center(child: CircularProgressIndicator());
                  }
                  if (ctrl.products.isEmpty) {
                     return Center(child: Text('لا توجد منتجات', style: TextStyle(color: Colors.grey[500])));
                  }
                  return SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          isDark ? Colors.black.withAlpha(50) : AppTheme.primaryColor.withAlpha(15),
                        ),
                        columnSpacing: 16,
                        columns: const [
                          DataColumn(label: Text('صورة', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('الباركود', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('اسم المنتج', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('الفئة', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('الرصيد', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('سعر الشراء', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('سعر البيع', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('إجراءات', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: ctrl.products.map((p) => _buildProductRow(p, ctrl, isDark, context)).toList(),
                      ),
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

  DataRow _buildProductRow(ProductModel p, InventoryController ctrl, bool isDark, BuildContext context) {
    final isLow = p.isLowStock;
    String hostUrl = ApiService.baseUrl.replaceAll('/api', '');

    return DataRow(
      color: WidgetStateProperty.resolveWith((states) => isLow ? Colors.orange.withAlpha(15) : null),
      cells: [
        DataCell(
          Container(
             width: 40, height: 40,
             decoration: BoxDecoration(
               color: Colors.grey.withAlpha(50),
               borderRadius: BorderRadius.circular(8),
               image: p.imageUrl != null && p.imageUrl!.isNotEmpty
                   ? DecorationImage(
                       image: NetworkImage('$hostUrl${p.imageUrl}'),
                       fit: BoxFit.cover,
                     )
                   : null,
             ),
             child: p.imageUrl == null || p.imageUrl!.isEmpty
                 ? const Icon(Icons.image_not_supported, size: 20, color: Colors.grey)
                 : null,
          ),
        ),
        DataCell(Text(p.globalBarcode.isEmpty ? p.internalBarcode ?? '-' : p.globalBarcode,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLow) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16)),
            Flexible(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          ],
        )),
        DataCell(Text(p.category ?? '-', style: TextStyle(color: Colors.grey[500]))),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
             color: isLow ? Colors.red.withAlpha(30) : Colors.green.withAlpha(30),
             borderRadius: BorderRadius.circular(8),
          ),
          child: Text('${p.stockQuantity.toStringAsFixed(0)} قطعة',
             style: TextStyle(color: isLow ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
        )),
        DataCell(Text('${p.purchasePrice.toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 13))),
        DataCell(Text('${p.price.toStringAsFixed(2)} ج.م', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
               icon: const Icon(Icons.print_outlined, color: Colors.orange, size: 20),
               onPressed: () => _showPrintLabelDialog(context, p, isDark),
               tooltip: 'طباعة ملصق الباركود',
            ),
            IconButton(
               icon: const Icon(Icons.camera_alt_outlined, color: Colors.purple, size: 20),
               onPressed: () => ctrl.pickAndUploadImage(p.id, context),
               tooltip: 'تغيير الصورة',
            ),
            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20), onPressed: () {}, tooltip: 'تعديل'),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => ctrl.deleteProduct(p.id, context), tooltip: 'حذف'),
          ],
        )),
      ],
    );
  }

  void _showPrintLabelDialog(BuildContext context, ProductModel p, bool isDark) {
     final qtyCtrl = TextEditingController(text: '1');
     
     // Validate if the product has any barcode to print
     final barcode = p.globalBarcode.isNotEmpty ? p.globalBarcode : p.internalBarcode ?? '';
     if (barcode.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المنتج ليس له باركود للطباعة'), backgroundColor: Colors.red));
        return;
     }

     showDialog(context: context, builder: (ctx) {
        return AlertDialog(
           title: Text('طباعة ملصق لـ: ${p.name}'),
           content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 Text('الباركود الذي سيتم طباعته: $barcode', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                 const SizedBox(height: 16),
                 TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'عدد الملصقات (النسخ)', border: OutlineInputBorder()),
                 )
              ],
           ),
           actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton.icon(
                 icon: const Icon(Icons.print),
                 label: const Text('طباعة الآن'),
                 style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                 onPressed: () {
                    final qty = int.tryParse(qtyCtrl.text) ?? 1;
                    if (qty > 0) {
                       BarcodePrintService.printProductLabel(p, qty);
                       Navigator.pop(ctx);
                    }
                 },
              )
           ],
        );
     });
  }

  Widget _buildAddProductPanel(BuildContext context, InventoryController ctrl, bool isDark) {
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text('إضافة منتج جديد', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 20),
                 
                 _input(nameCtrl, 'اسم المنتج *', Icons.title, isDark),
                 const SizedBox(height: 12),
                 
                 // Auto Barcode Preview with Refresh
                 Obx(() {
                   String hint = ctrl.isBarcodeLoading.value 
                        ? 'جاري التوليد...' 
                        : (ctrl.nextBarcode.value.isNotEmpty ? 'تلقائي: ${ctrl.nextBarcode.value}' : 'باركود (اختياري)');
                   return TextField(
                     controller: barcodeCtrl,
                     decoration: InputDecoration(
                       labelText: 'الباركود',
                       hintText: hint,
                       prefixIcon: const Icon(Icons.qr_code, color: AppTheme.primaryColor, size: 20),
                       suffixIcon: IconButton(
                         icon: const Icon(Icons.refresh, size: 20),
                         onPressed: () => ctrl.fetchNextBarcode(),
                         tooltip: 'جلب باركود جديد',
                       ),
                       filled: true,
                       fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withAlpha(40))),
                       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                     ),
                   );
                 }),
                 const SizedBox(height: 12),

                 // Category Dropdown + Switch to Custom
                 Obx(() {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isCustomCategory)
                          DropdownButtonFormField<String>(
                            value: selectedFormCategory,
                            decoration: InputDecoration(
                               labelText: 'الفئة',
                               prefixIcon: const Icon(Icons.category, color: AppTheme.primaryColor, size: 20),
                               filled: true,
                               fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                               border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withAlpha(40))),
                               contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: [
                               ...ctrl.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                               const DropdownMenuItem(value: '__NEW__', child: Text('➕ إضافة فئة جديدة', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold))),
                            ],
                            onChanged: (val) {
                               if (val == '__NEW__') {
                                  setState(() {
                                    isCustomCategory = true;
                                    selectedFormCategory = null;
                                  });
                               } else {
                                  setState(() { selectedFormCategory = val; });
                               }
                            },
                          ),
                        if (isCustomCategory)
                          Row(
                            children: [
                              Expanded(child: _input(customCategoryCtrl, 'اسم الفئة الجديدة', Icons.edit, isDark)),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                tooltip: 'إلغاء وإختيار من القائمة',
                                onPressed: () {
                                   setState(() {
                                     isCustomCategory = false;
                                     customCategoryCtrl.clear();
                                   });
                                },
                              )
                            ],
                          ),
                      ],
                    );
                 }),
                 
                 const SizedBox(height: 12),
                 _input(purchasePriceCtrl, 'سعر الشراء', Icons.money_off, isDark, isNumber: true),
                 const SizedBox(height: 12),
                 _input(salePriceCtrl, 'سعر البيع *', Icons.attach_money, isDark, isNumber: true),
                 const SizedBox(height: 12),
                 _input(stockCtrl, 'الرصيد الافتتاحي', Icons.add_box, isDark, isNumber: true),
                 const SizedBox(height: 24),

                 SizedBox(
                   width: double.infinity,
                   height: 48,
                   child: Obx(() => ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: AppTheme.primaryColor,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     ),
                     onPressed: ctrl.isLoading.value ? null : () async {
                       if (nameCtrl.text.isEmpty || salePriceCtrl.text.isEmpty) return;
                       
                       String? finalCategory;
                       if (isCustomCategory && customCategoryCtrl.text.isNotEmpty) {
                          finalCategory = customCategoryCtrl.text;
                       } else if (!isCustomCategory && selectedFormCategory != null) {
                          finalCategory = selectedFormCategory;
                       }

                       bool success = await ctrl.addProduct({
                         'name': nameCtrl.text,
                         'globalBarcode': barcodeCtrl.text.isEmpty ? null : barcodeCtrl.text,
                         'category': finalCategory,
                         'purchasePrice': double.tryParse(purchasePriceCtrl.text) ?? 0,
                         'wholesalePrice': double.tryParse(purchasePriceCtrl.text) ?? 0,
                         'price': double.tryParse(salePriceCtrl.text) ?? 0,
                         'stockQuantity': int.tryParse(stockCtrl.text) ?? 0,
                       }, context);

                       if (success) {
                          nameCtrl.clear(); barcodeCtrl.clear(); customCategoryCtrl.clear();
                          purchasePriceCtrl.clear(); salePriceCtrl.clear(); stockCtrl.clear();
                          setState(() {
                             isCustomCategory = false;
                             selectedFormCategory = null;
                          });
                       }
                     },
                     child: ctrl.isLoading.value
                         ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                         : const Text('حفظ المنتج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                   )),
                 ),
                 const SizedBox(height: 12),
                 Text('ملاحظة: لرفع صورة للمنتج، قم بإنشائه أولًا ثم اضغط على أيقونة الكاميرا في الجدول.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1);
  }

  Widget _input(TextEditingController ctrl, String label, IconData icon, bool isDark, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
        filled: true,
        fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withAlpha(40))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
