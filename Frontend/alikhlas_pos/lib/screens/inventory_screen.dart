import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:collection/collection.dart';
import '../controllers/inventory_controller.dart';
import '../models/product_model.dart';
import '../core/theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/barcode_print_service.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../core/utils/toast_service.dart';

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

  PlutoGridStateManager? stateManager;
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    final ctrl = Get.put(InventoryController());
    _worker = ever(ctrl.products, (products) {
      if (stateManager != null) {
        stateManager!.removeAllRows();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        stateManager!.appendRows(products.map((p) => _getPlutoRow(p, isDark, ctrl, context)).toList());
      }
    });
  }

  @override
  void dispose() {
    _worker?.dispose();
    nameCtrl.dispose();
    barcodeCtrl.dispose();
    purchasePriceCtrl.dispose();
    salePriceCtrl.dispose();
    stockCtrl.dispose();
    customCategoryCtrl.dispose();
    super.dispose();
  }

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
                  return PlutoGrid(
                    columns: _getColumns(isDark, ctrl, context),
                    rows: ctrl.products.map((p) => _getPlutoRow(p, isDark, ctrl, context)).toList(),
                    onLoaded: (PlutoGridOnLoadedEvent event) {
                      event.stateManager.setShowColumnFilter(true);
                      event.stateManager.setPageSize(30);
                    },
                    configuration: PlutoGridConfiguration(
                      style: isDark ? PlutoGridStyleConfig.dark() : const PlutoGridStyleConfig(),
                      localeText: const PlutoGridLocaleText.arabic(),
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

  List<PlutoColumn> _getColumns(bool isDark, InventoryController ctrl, BuildContext context) {
    return [
      PlutoColumn(
        title: 'صورة',
        field: 'image',
        type: PlutoColumnType.text(),
        enableFilterMenuItem: false,
        enableSorting: false,
        width: 80,
        renderer: (rendererContext) {
          final imageUrl = rendererContext.cell.value as String?;
          final hostUrl = (dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5000/api').replaceAll('/api', '');
          return Container(
             width: 40, height: 40,
             decoration: BoxDecoration(
               color: Colors.grey.withAlpha(50),
               borderRadius: BorderRadius.circular(8),
               image: imageUrl != null && imageUrl.isNotEmpty
                   ? DecorationImage(image: NetworkImage('$hostUrl$imageUrl'), fit: BoxFit.cover)
                   : null,
             ),
             child: (imageUrl == null || imageUrl.isEmpty)
                 ? const Icon(Icons.image_not_supported, size: 20, color: Colors.grey)
                 : null,
          );
        },
      ),
      PlutoColumn(
        title: 'الباركود',
        field: 'barcode',
        type: PlutoColumnType.text(),
        width: 150,
      ),
      PlutoColumn(
        title: 'اسم المنتج',
        field: 'name',
        type: PlutoColumnType.text(),
        width: 250,
      ),
      PlutoColumn(
        title: 'الفئة',
        field: 'category',
        type: PlutoColumnType.text(),
        width: 120,
      ),
      PlutoColumn(
        title: 'الرصيد',
        field: 'stock',
        type: PlutoColumnType.number(),
        width: 100,
        renderer: (ctx) {
          final isLow = ctx.row.cells['isLow']?.value as bool;
          final stock = ctx.cell.value as num;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
               color: isLow ? Colors.red.withAlpha(30) : Colors.green.withAlpha(30),
               borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${stock.toStringAsFixed(0)} قطعة',
               style: TextStyle(color: isLow ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
          );
        },
      ),
      PlutoColumn(
        title: 'سعر الشراء',
        field: 'purchase',
        type: PlutoColumnType.number(),
        width: 100,
        renderer: (ctx) => Text('${(ctx.cell.value as num).toStringAsFixed(2)} ج.م', style: const TextStyle(fontSize: 13)),
      ),
      PlutoColumn(
        title: 'سعر البيع',
        field: 'price',
        type: PlutoColumnType.number(),
        width: 100,
        renderer: (ctx) => Text('${(ctx.cell.value as num).toStringAsFixed(2)} ج.م', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
      ),
      PlutoColumn(
        title: '',
        field: 'isLow',
        type: PlutoColumnType.text(),
        hide: true, // Hid isLow column
      ),
      PlutoColumn(
        title: 'ID',
        field: 'id',
        type: PlutoColumnType.text(),
        hide: true, // Hid Action context column
      ),
      PlutoColumn(
        title: 'إجراءات',
        field: 'actions',
        type: PlutoColumnType.text(),
        enableFilterMenuItem: false,
        enableSorting: false,
        width: 170,
        renderer: (ctx) {
          final id = ctx.row.cells['id']!.value.toString();
          final p = ctrl.products.firstWhereOrNull((prod) => prod.id == id);
          if (p == null) return const SizedBox.shrink();

          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.print_outlined, color: Colors.orange, size: 22), 
                onPressed: () => _showPrintLabelDialog(context, p, Theme.of(context).brightness == Brightness.dark), 
                tooltip: 'طباعة ملصق'
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.purple, size: 22), 
                onPressed: () => ctrl.pickAndUploadImage(p.id, context), 
                tooltip: 'تغيير الصورة'
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 22), 
                onPressed: () => _showEditProductDialog(context, p, Theme.of(context).brightness == Brightness.dark, ctrl), 
                tooltip: 'تعديل'
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22), 
                onPressed: () => _showDeleteConfirmationDialog(context, p, ctrl), 
                tooltip: 'حذف'
              ),
            ],
          );
        }
      ),
    ];
  }

  PlutoRow _getPlutoRow(ProductModel p, bool isDark, InventoryController ctrl, BuildContext context) {
    return PlutoRow(
      cells: {
        'image': PlutoCell(value: p.imageUrl ?? ''),
        'barcode': PlutoCell(value: p.globalBarcode.isEmpty ? (p.internalBarcode ?? '-') : p.globalBarcode),
        'name': PlutoCell(value: p.name),
        'category': PlutoCell(value: p.category ?? '-'),
        'stock': PlutoCell(value: p.stockQuantity),
        'isLow': PlutoCell(value: p.isLowStock),
        'purchase': PlutoCell(value: p.purchasePrice),
        'price': PlutoCell(value: p.price),
        'actions': PlutoCell(value: ''),
        'id': PlutoCell(value: p.id),
      },
    );
  }

  void _showPrintLabelDialog(BuildContext context, ProductModel p, bool isDark) {
     final qtyCtrl = TextEditingController(text: '1');
     
     // Validate if the product has any barcode to print
     final barcode = p.globalBarcode.isNotEmpty ? p.globalBarcode : p.internalBarcode ?? '';
     if (barcode.isEmpty) {
        ToastService.showError('المنتج ليس له باركود للطباعة');
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
                     onPressed: ctrl.isLoading.value ? null : () => _showConfirmAddProductDialog(context, ctrl, isDark),
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

  void _showConfirmAddProductDialog(BuildContext context, InventoryController ctrl, bool isDark) {
    if (nameCtrl.text.isEmpty || salePriceCtrl.text.isEmpty) {
        ToastService.showError('يرجى ملء الحقول الإلزامية (اسم المنتج وسعر البيع)');
        return;
    }

    String? finalCategory;
    if (isCustomCategory && customCategoryCtrl.text.isNotEmpty) {
      finalCategory = customCategoryCtrl.text;
    } else if (!isCustomCategory && selectedFormCategory != null) {
      finalCategory = selectedFormCategory;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد إضافة منتج', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('هل أنت متأكد من إضافة هذا المنتج بالبيانات التالية؟'),
            const SizedBox(height: 16),
            _buildDialogRow('الاسم:', nameCtrl.text),
            _buildDialogRow('الباركود:', barcodeCtrl.text.isEmpty ? (ctrl.nextBarcode.value.isNotEmpty ? '${ctrl.nextBarcode.value} (تلقائي)' : 'تلقائي') : barcodeCtrl.text),
            _buildDialogRow('الفئة:', finalCategory ?? 'غير محدد'),
            _buildDialogRow('الشراء:', '${purchasePriceCtrl.text.isEmpty ? '0' : purchasePriceCtrl.text} ج.م'),
            _buildDialogRow('البيع:', '${salePriceCtrl.text} ج.م'),
            _buildDialogRow('الرصيد:', '${stockCtrl.text.isEmpty ? '0' : stockCtrl.text} قطعة'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تعديل البيانات', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
               backgroundColor: AppTheme.primaryColor, 
               foregroundColor: Colors.white,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check, size: 20),
            label: const Text('تأكيد وإضافة'),
            onPressed: () async {
              Navigator.pop(ctx);

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
          ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: Colors.blueGrey))),
        ],
      ),
    );
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

  void _showDeleteConfirmationDialog(BuildContext context, ProductModel p, InventoryController ctrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من رغبتك في حذف المنتج "${p.name}" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('نعم، احذف'),
            onPressed: () {
              Navigator.pop(ctx);
              ctrl.deleteProduct(p.id, context);
            },
          ),
        ],
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, ProductModel p, bool isDark, InventoryController ctrl) {
    final editNameCtrl = TextEditingController(text: p.name);
    final editBarcodeCtrl = TextEditingController(text: p.globalBarcode.isEmpty ? p.internalBarcode : p.globalBarcode);
    final editPurchaseCtrl = TextEditingController(text: p.purchasePrice.toString());
    final editSaleCtrl = TextEditingController(text: p.price.toString());
    final editStockCtrl = TextEditingController(text: p.stockQuantity.toString());
    String selectedCat = p.category ?? '';
    if (selectedCat.isEmpty && ctrl.categories.isNotEmpty) selectedCat = ctrl.categories.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateBuilder) {
          return AlertDialog(
            title: const Text('تعديل المنتج', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _input(editNameCtrl, 'اسم المنتج *', Icons.text_fields, isDark),
                    const SizedBox(height: 12),
                    _input(editBarcodeCtrl, 'الباركود', Icons.qr_code, isDark),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: ctrl.categories.contains(selectedCat) ? selectedCat : null,
                      decoration: InputDecoration(
                        labelText: 'الفئة',
                        filled: true,
                        fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: ctrl.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setStateBuilder(() => selectedCat = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _input(editPurchaseCtrl, 'سعر الشراء', Icons.money_off, isDark, isNumber: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _input(editSaleCtrl, 'سعر البيع *', Icons.attach_money, isDark, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _input(editStockCtrl, 'الرصيد', Icons.inventory, isDark, isNumber: true),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                icon: const Icon(Icons.save, size: 18),
                label: const Text('حفظ التعديلات'),
                onPressed: () async {
                  if (editNameCtrl.text.isEmpty || editSaleCtrl.text.isEmpty) {
                    ToastService.showError('الاسم وسعر البيع مطلوبان');
                    return;
                  }
                  Navigator.pop(ctx);
                  await ctrl.updateProduct(p.id, {
                    'name': editNameCtrl.text,
                    'globalBarcode': editBarcodeCtrl.text.isEmpty ? null : editBarcodeCtrl.text,
                    'category': selectedCat.isEmpty ? null : selectedCat,
                    'purchasePrice': double.tryParse(editPurchaseCtrl.text) ?? 0,
                    'wholesalePrice': double.tryParse(editPurchaseCtrl.text) ?? 0,
                    'price': double.tryParse(editSaleCtrl.text) ?? 0,
                    'stockQuantity': double.tryParse(editStockCtrl.text) ?? 0,
                  }, context);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
