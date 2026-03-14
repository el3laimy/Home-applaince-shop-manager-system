import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:collection/collection.dart';
import '../controllers/inventory_controller.dart';
import '../models/product_model.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/widgets/neo_button.dart';
import '../core/widgets/neo_text_field.dart';
import '../core/widgets/neo_dialog.dart';
import '../services/api_service.dart';
import '../services/barcode_print_service.dart';
import '../core/utils/toast_service.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  // Add Product Form Controllers — created fresh per build, disposed by Flutter framework
  static final nameCtrl = TextEditingController();
  static final barcodeCtrl = TextEditingController();
  static final purchasePriceCtrl = TextEditingController();
  static final salePriceCtrl = TextEditingController();
  static final stockCtrl = TextEditingController();
  static final customCategoryCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(InventoryController());
    final isDark = true; // Neo-Glass is always dark
    return DesignTokens.neoPageBackgroundWidget(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 950;
            return Padding(
              padding: EdgeInsets.all(isNarrow ? 12 : DesignTokens.kPagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, ctrl, isDark),
                  const SizedBox(height: 16),
                  _buildStatsRow(context, ctrl, isDark),
                  const SizedBox(height: 20),
                  Expanded(
                    child: isNarrow
                        ? _buildInventoryTable(context, ctrl, isDark)
                        : Row(
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
            );
          },
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
            DesignTokens.holographicText(
              text: 'إدارة المخزون والمنتجات',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Obx(() => Text(
              '${ctrl.totalCount} منتج إجمالي — ${ctrl.lowStockProducts.length} وصل لحد التنبيه',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            )),
          ],
        ).animate().fade().slideX(begin: 0.05),
        Row(
          children: [
            _buildFilterChip('نقص المخزون', Icons.warning_amber_rounded, Colors.orange, ctrl),
            const SizedBox(width: 12),
            NeoButton(
              label: 'تحديث',
              icon: Icons.refresh,
              color: DesignTokens.neonCyan,
              onPressed: () => ctrl.fetchProducts(reset: true),
            ),
          ],
        ).animate().fade().slideX(begin: -0.05),
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
      child: DesignTokens.liquidBorderCard(
        height: 80,
        child: Row(
          children: [
            Container(
               width: 40, height: 40,
               decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(25)),
               child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 12), overflow: TextOverflow.ellipsis),
                   const SizedBox(height: 2),
                   Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 100.ms),
    );
  }

  Widget _buildInventoryTable(BuildContext context, InventoryController ctrl, bool isDark) {
    final hostUrl = (dotenv.env['API_BASE_URL'] ?? 'http://localhost:5291/api').replaceAll('/api', '');
    return Container(
      decoration: DesignTokens.neoGlassDecoration(borderRadius: DesignTokens.kNeoCardRadius),
      child: Column(
        children: [
          // Search bar & Category filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو الباركود أو الفئة...',
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[500]),
                      filled: true,
                      fillColor: DesignTokens.glassBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: DesignTokens.glassBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: DesignTokens.glassBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: DesignTokens.neonCyan, width: 1.5)),
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
                       borderRadius: BorderRadius.circular(DesignTokens.kChipRadius),
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
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(5) : Colors.grey.withAlpha(8),
              border: Border(bottom: BorderSide(color: isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(20))),
            ),
            child: Row(
              children: [
                const SizedBox(width: 50), // image col
                const SizedBox(width: 12),
                Expanded(flex: 2, child: Text('رمز المنتج', style: _tableHeaderStyle(isDark))),
                Expanded(flex: 3, child: Text('اسم المنتج', style: _tableHeaderStyle(isDark))),
                Expanded(flex: 2, child: Text('الفئة', style: _tableHeaderStyle(isDark))),
                Expanded(flex: 2, child: Text('مستوى المخزون', style: _tableHeaderStyle(isDark))),
                Expanded(flex: 1, child: Text('السعر', style: _tableHeaderStyle(isDark))),
                const SizedBox(width: 130), // actions col
              ],
            ),
          ),
          // Table Rows
          Expanded(
            child: Obx(() {
              if (ctrl.isLoading.value && ctrl.products.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (ctrl.products.isEmpty) {
                return Center(child: Text('لا توجد منتجات', style: TextStyle(color: Colors.grey[500])));
              }
              return ListView.builder(
                itemCount: ctrl.products.length,
                itemBuilder: (context, index) {
                  final p = ctrl.products[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: isDark ? Colors.white.withAlpha(5) : Colors.grey.withAlpha(12))),
                      color: index.isEven ? Colors.transparent : (isDark ? Colors.white.withAlpha(3) : Colors.grey.withAlpha(5)),
                    ),
                    child: Row(
                      children: [
                        // Image
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15),
                            borderRadius: BorderRadius.circular(8),
                            image: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                ? DecorationImage(image: NetworkImage('$hostUrl${p.imageUrl!}'), fit: BoxFit.cover)
                                : null,
                          ),
                          child: (p.imageUrl == null || p.imageUrl!.isEmpty)
                              ? Icon(Icons.image_not_supported_rounded, size: 18, color: Colors.grey[600])
                              : null,
                        ),
                        const SizedBox(width: 12),
                        // SKU / Barcode
                        Expanded(
                          flex: 2,
                          child: Text(
                            p.globalBarcode.isNotEmpty ? p.globalBarcode : (p.internalBarcode ?? '-'),
                            style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Name
                        Expanded(
                          flex: 3,
                          child: Text(p.name, style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        // Category Badge
                        Expanded(
                          flex: 2,
                          child: p.category != null && p.category!.isNotEmpty
                              ? DesignTokens.buildCategoryBadge(p.category!)
                              : Text('-', style: TextStyle(color: Colors.grey[500])),
                        ),
                        // Stock Level Bar
                        Expanded(
                          flex: 2,
                          child: DesignTokens.buildStockBar(
                            p.stockQuantity.toInt(),
                            p.minStockAlert.toInt(),
                            width: 90,
                          ),
                        ),
                        // Price
                        Expanded(
                          flex: 1,
                          child: Text('${p.price.toStringAsFixed(0)} ج.م', style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13,
                            color: isDark ? DesignTokens.neonCyan : AppTheme.primaryColor,
                          )),
                        ),
                        // Actions
                        SizedBox(
                          width: 130,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _actionIcon(Icons.history, Colors.teal, 'سجل الحركات',
                                  () => _showStockHistoryDialog(context, p, ctrl, isDark)),
                              _actionIcon(Icons.print_outlined, Colors.orange, 'طباعة ملصق',
                                  () => _showPrintLabelDialog(context, p, isDark)),
                              _actionIcon(Icons.camera_alt_outlined, DesignTokens.neonPurple, 'تغيير الصورة',
                                  () => ctrl.pickAndUploadImage(p.id)),
                              _actionIcon(Icons.edit_outlined, DesignTokens.neonBlue, 'تعديل',
                                  () => _showEditProductDialog(context, p, isDark, ctrl)),
                              _actionIcon(Icons.delete_outline_rounded, DesignTokens.neonRed, 'حذف',
                                  () => _showDeleteConfirmationDialog(context, p, ctrl)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }),
          ),
          // Pagination footer
          Obx(() => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(20))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (ctrl.isLoadingMore.value)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else if (ctrl.hasMore)
                  TextButton.icon(
                    onPressed: ctrl.loadMore,
                    icon: const Icon(Icons.expand_more_rounded, size: 18),
                    label: Text('تحميل المزيد (${ctrl.totalCount.value - ctrl.products.length} متبقٍ)',
                        style: const TextStyle(fontSize: 12)),
                  )
                else
                  Text('${ctrl.totalCount.value} منتج إجمالي',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          )),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _actionIcon(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  TextStyle _tableHeaderStyle(bool isDark) => TextStyle(
    fontWeight: FontWeight.w700, fontSize: 12,
    color: isDark ? Colors.grey[400] : Colors.grey[600],
  );

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
           title: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text('طباعة ملصق لـ: ${p.name}'),
               IconButton(
                 icon: const Icon(Icons.help_outline, color: Colors.blue),
                 onPressed: () => _showWindowsPrintHelp(context),
                 tooltip: 'تعليمات إعدادات الويندوز',
               ),
             ],
           ),
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

  void _showWindowsPrintHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعدادات طابعة الباركود في Windows'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('لضمان جودة الطباعة وعدم خروج الباركود عن الملصق، يرجى التأكد من الإعدادات التالية في لوحة التحكم (Control Panel):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _bulletPoint('1. افتح "Devices and Printers" في Windows.'),
              _bulletPoint('2. اضغط بيمين الماوس على الطابعة واختر "Printing Preferences".'),
              _bulletPoint('3. في تبويب "Page Setup"، اختر مقاس الورق (New) وادخل: 50mm عرض و 25mm طول.'),
              _bulletPoint('4. في تبويب "Stock"، تأكد من اختيار نوع "Labels with Gaps".'),
              _bulletPoint('5. تأكد من إيقاف خيارات "Scaling" أو "Fit to Page"'),
              const SizedBox(height: 12),
              const Text('💡 نصيحة: استخدم زر "معايرة الباركود" في الإعدادات للتأكد من المحاذاة.', style: TextStyle(color: Colors.blue, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً، فهمت')),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
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
                        if (!ctrl.isCustomCategory.value)
                          DropdownButtonFormField<String>(
                            value: ctrl.selectedFormCategory.value,
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
                                 ctrl.isCustomCategory.value = true;
                                 ctrl.selectedFormCategory.value = null;
                               } else {
                                 ctrl.selectedFormCategory.value = val;
                               }
                            },
                          ),
                        if (ctrl.isCustomCategory.value)
                          Row(
                            children: [
                              Expanded(child: _input(customCategoryCtrl, 'اسم الفئة الجديدة', Icons.edit, isDark)),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                tooltip: 'إلغاء وإختيار من القائمة',
                                onPressed: () {
                                   ctrl.isCustomCategory.value = false;
                                   customCategoryCtrl.clear();
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
    if (ctrl.isCustomCategory.value && customCategoryCtrl.text.isNotEmpty) {
      finalCategory = customCategoryCtrl.text;
    } else if (!ctrl.isCustomCategory.value && ctrl.selectedFormCategory.value != null) {
      finalCategory = ctrl.selectedFormCategory.value;
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
              });

              if (success) {
                nameCtrl.clear(); barcodeCtrl.clear(); customCategoryCtrl.clear();
                purchasePriceCtrl.clear(); salePriceCtrl.clear(); stockCtrl.clear();
                ctrl.isCustomCategory.value = false;
                  ctrl.selectedFormCategory.value = null;
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
              ctrl.deleteProduct(p.id);
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
                  });
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showStockHistoryDialog(BuildContext context, ProductModel p, InventoryController ctrl, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: ctrl.fetchStockHistory(p.id),
          builder: (context, snapshot) {
            return AlertDialog(
              title: Text('سجل حركات الرصيد: ${p.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SizedBox(
                width: 600,
                height: 400,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                        ? const Center(child: Text('حدث خطأ في جلب البيانات', style: TextStyle(color: Colors.red)))
                        : snapshot.data == null || snapshot.data!.isEmpty
                            ? const Center(child: Text('لا توجد حركات مسجلة لهذا المنتج', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  final item = snapshot.data![index];
                                  final qty = item['quantity'] as int? ?? 0;
                                  final isPositive = qty > 0;
                                  final balanceAfter = item['balanceAfter']?.toString() ?? '-';
                                  final typeLabel = item['typeLabel']?.toString() ?? 'حركة رصيد';
                                  final refNo = item['referenceNumber']?.toString() ?? '';
                                  final dateStr = item['createdAt']?.toString() ?? '';
                                  final DateTime? date = DateTime.tryParse(dateStr);
                                  
                                  return Card(
                                    color: isDark ? Colors.white.withAlpha(10) : Colors.white,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isPositive ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
                                        child: Icon(
                                          isPositive ? Icons.add_shopping_cart : Icons.remove_shopping_cart,
                                          color: isPositive ? Colors.green : Colors.red,
                                        ),
                                      ),
                                      title: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(typeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text('${isPositive ? '+' : ''}$qty', 
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isPositive ? Colors.green : Colors.red),
                                          ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          if (refNo.isNotEmpty) Text('رقم المرجع: $refNo', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                          Text('المستخدم: ${item['createdBy'] ?? 'مجهول'} | التاريخ: ${date != null ? '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')} ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}' : '-'}', style: const TextStyle(fontSize: 11)),
                                          const SizedBox(height: 4),
                                          Text('الرصيد بعد الحركة: $balanceAfter قطعة', style: TextStyle(color: isDark ? DesignTokens.neonCyan : AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))
              ],
            );
          },
        );
      },
    );
  }
}

