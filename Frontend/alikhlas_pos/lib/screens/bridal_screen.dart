import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/bridal_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/formatters.dart';
import '../core/utils/toast_service.dart';

class BridalOrdersScreen extends StatelessWidget {
  const BridalOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(BridalController());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DesignTokens.neoPageBackgroundWidget(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.kPagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, ctrl, isDark),
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 280, child: _buildOrderList(context, ctrl, isDark)),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Obx(() => ctrl.selectedOrder.value == null
                          ? _buildEmptyState(context)
                          : Column(
                              children: [
                                Expanded(
                                  child: _buildDetailPanel(context, ctrl, isDark),
                                ),
                                // Deliver button section
                                if (ctrl.selectedOrder.value!['status'] == 1 && ctrl.completionPct >= 0) // 1 = Reserved
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (c) => AlertDialog(
                                              title: const Text('تسليم الطلب'),
                                              content: const Text('هل أنت متأكد من تسليم الطلب؟ سيتم خصم الأجهزة من المخزون.'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                                  onPressed: () => Navigator.pop(c, true),
                                                  child: const Text('تأكيد التسليم'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await ctrl.deliverOrder(ctrl.selectedOrder.value!['id']);
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green, foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        icon: ctrl.isLoading.value
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                            : const Icon(Icons.check_circle_outline),
                                        label: Text(ctrl.isLoading.value ? 'جاري التسليم...' : 'تسليم الطلب (خصم من المخزون)',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                    ),
                                  ),
                              ],
                            )),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, BridalController ctrl, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
               DesignTokens.holographicText(
                 text: 'طلبيات وتجهيزات العرايس',
                 style: const TextStyle(fontSize: 22),
               ),
               const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _showRemindersDialog(context, ctrl, isDark),
                icon: const Icon(Icons.notifications_active, color: Colors.orange),
                label: Text('تنبيهات التسليم', style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.orange.withAlpha(100)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('إدارة حجوزات الأجهزة المنزلية للعرائس',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ]).animate().fade().slideX(begin: 0.1),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('حجز عروسة جديد', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => _showNewOrderDialog(context, ctrl, isDark),
        ).animate().fade(),
      ],
    );
  }

  // ─── Order List Sidebar ─────────────────────────────────────────────────────

  Widget _buildOrderList(BuildContext context, BridalController ctrl, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(5) : Colors.white.withAlpha(180),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(isDark ? 20 : 60)),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'ابحث باسم العروسة...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true, fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) => ctrl.fetchOrders(search: v),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (ctrl.isLoading.value && ctrl.bridalOrders.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (ctrl.bridalOrders.isEmpty) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('لا يوجد حجوزات\nاضغط "حجز جديد"',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
                  ));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: ctrl.bridalOrders.length,
                  itemBuilder: (ctx, i) {
                    final order = ctrl.bridalOrders[i];
                    final isSelected = ctrl.selectedOrder.value?['id'] == order['id'];
                    final remaining = (order['remainingAmount'] as num?)?.toDouble() ?? 0;
                    final eventDate = order['eventDate'] as String?;
                    DateTime? eDt;
                    try { if (eventDate != null) eDt = DateTime.parse(eventDate); } catch (_) {}

                    return GestureDetector(
                      onTap: () => ctrl.selectOrder(order['id'] as String),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor.withAlpha(25) : (isDark ? Colors.black.withAlpha(30) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.withAlpha(40)),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            backgroundColor: (isSelected ? AppTheme.primaryColor : Colors.pink).withAlpha(20),
                            radius: 18,
                            child: Icon(Icons.face_3, color: isSelected ? AppTheme.primaryColor : Colors.pink, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(order['customerName'] as String? ?? 'عروسة',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis),
                            if (eDt != null)
                              Text('الفرح: ${AppFormatters.date(eDt)}',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                          ])),
                          if (remaining > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(color: Colors.orange.withAlpha(25), borderRadius: BorderRadius.circular(6)),
                              child: Text('${remaining.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ]),
                      ),
                    );
                  },
                );
              }),
            ),
          ]),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  // ─── Empty State ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.face_3_outlined, size: 80, color: Colors.pink.withAlpha(80)),
        const SizedBox(height: 16),
        Text('اختر ملف عروسة من القائمة', style: TextStyle(color: Colors.grey[500], fontSize: 18)),
        const SizedBox(height: 8),
        Text('أو افتح حجزًا جديدًا بالضغط على الزر أعلاه',
            style: TextStyle(color: Colors.grey[400], fontSize: 14)),
      ]),
    ).animate().fade();
  }

  // ─── Detail Panel ──────────────────────────────────────────────────────────

  Widget _buildDetailPanel(BuildContext context, BridalController ctrl, bool isDark) {
    final order = ctrl.selectedOrder.value!;
    final customerName = order['customerName'] as String? ?? 'عروسة';
    final eventDate = order['eventDate'] as String?;
    final deliveryDate = order['deliveryDate'] as String?;
    DateTime? eDt, dDt;
    try { if (eventDate != null) eDt = DateTime.parse(eventDate); } catch (_) {}
    try { if (deliveryDate != null) dDt = DateTime.parse(deliveryDate); } catch (_) {}

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
          child: Column(children: [
            // Header gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.pink.withAlpha(200), AppTheme.primaryColor.withAlpha(180)
                ]),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withAlpha(40), radius: 28,
                  child: const Icon(Icons.face_3, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ملف العروسة: $customerName',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (eDt != null) ...[
                      const Icon(Icons.celebration, size: 13, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text('الفرح: ${AppFormatters.date(eDt)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(width: 12),
                    ],
                    if (dDt != null) ...[
                      const Icon(Icons.local_shipping, size: 13, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text('التوصيل: ${AppFormatters.date(dDt)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ]),
                ])),
                // Completion ring
                Obx(() => Stack(alignment: Alignment.center, children: [
                  SizedBox(
                    width: 64, height: 64,
                    child: CircularProgressIndicator(
                      value: ctrl.completionPct / 100,
                      strokeWidth: 7,
                      backgroundColor: Colors.white.withAlpha(40),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  Text('${ctrl.completionPct.toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ])),
              ]),
            ),

            // Stats
            Obx(() => Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                _statTile(context, Icons.shopping_cart, 'إجمالي الأجهزة',
                    AppFormatters.currency(ctrl.totalAmount), Colors.blue, isDark),
                const SizedBox(width: 10),
                _statTile(context, Icons.payments, 'المدفوع (عربون)',
                    AppFormatters.currency(ctrl.paidAmount), Colors.green, isDark),
                const SizedBox(width: 10),
                _statTile(context, Icons.account_balance_wallet, 'المتبقي',
                    AppFormatters.currency(ctrl.remainingAmount),
                    ctrl.remainingAmount > 0 ? Colors.orange : Colors.grey, isDark),
                const SizedBox(width: 10),
                _statTile(context, Icons.devices, 'عدد الأجهزة',
                    '${ctrl.checklistItems.length}', Colors.purple, isDark),
              ]),
            )),

            // Checklist header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Row(children: [
                  Icon(Icons.checklist, size: 20),
                  SizedBox(width: 8),
                  Text('قائمة الأجهزة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                Row(children: [
                  // Add item button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('إضافة جهاز', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showCategoryPicker(context, ctrl, isDark),
                  ),
                  const SizedBox(width: 8),
                  // Save changes
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('حفظ التعديلات', style: TextStyle(fontSize: 12)),
                    onPressed: () => ctrl.updateItems(order['id'] as String),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 12),

            // Checklist items
            Expanded(
              child: Obx(() {
                if (ctrl.checklistItems.isEmpty) {
                  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_shopping_cart, size: 60, color: Colors.grey.withAlpha(60)),
                    const SizedBox(height: 12),
                    Text('لا توجد أجهزة في القائمة', style: TextStyle(color: Colors.grey[500])),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة جهاز'),
                      onPressed: () => _showCategoryPicker(context, ctrl, isDark),
                    ),
                  ]));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: ctrl.checklistItems.length,
                  itemBuilder: (ctx, i) => _buildChecklistItem(ctrl.checklistItems[i], ctrl, isDark),
                );
              }),
            ),
          ]),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildChecklistItem(BridalChecklistItem item, BridalController ctrl, bool isDark) {
    final isAvailable = item.stockQuantity >= item.quantity;
    final isLow = !isAvailable && item.stockQuantity > 0;

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withAlpha(8) : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          // Status icon
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (isAvailable ? Colors.green : (isLow ? Colors.orange : Colors.red)).withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isAvailable ? Icons.check_circle : (isLow ? Icons.warning : Icons.cancel),
              color: isAvailable ? Colors.green : (isLow ? Colors.orange : Colors.red),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(children: [
              Text('سعر: ${AppFormatters.currency(item.unitPrice)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              const SizedBox(width: 8),
              Text('مخزون: ${item.stockQuantity.toInt()}',
                  style: TextStyle(
                    color: isAvailable ? Colors.green : Colors.red,
                    fontSize: 11, fontWeight: FontWeight.bold,
                  )),
            ]),
          ])),
          // Qty stepper
          Row(children: [
            IconButton(
              onPressed: () {
                if (item.quantity > 1) {
                  ctrl.addItemToChecklist({'id': item.productId, 'name': item.productName, 'price': item.unitPrice, 'stockQuantity': item.stockQuantity},
                      item.category, item.quantity - 1);
                }
              },
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            IconButton(
              onPressed: () {
                ctrl.addItemToChecklist({'id': item.productId, 'name': item.productName, 'price': item.unitPrice, 'stockQuantity': item.stockQuantity},
                    item.category, item.quantity + 1);
              },
              icon: const Icon(Icons.add_circle_outline, size: 20),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(width: 8),
          Text(AppFormatters.currency(item.unitPrice * item.quantity),
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => ctrl.removeItem(item.productId),
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
      ),
    );
  }

  Widget _statTile(BuildContext context, IconData icon, String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withAlpha(40))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight,
            child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14))),
        ]),
      ),
    );
  }

  // ─── Category Picker Dialog ─────────────────────────────────────────────────

  void _showCategoryPicker(BuildContext context, BridalController ctrl, bool isDark) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.devices, size: 22),
          SizedBox(width: 8),
          Text('اختر فئة الجهاز'),
        ]),
        content: SizedBox(
          width: 400,
          child: Obx(() => Wrap(
            spacing: 8, runSpacing: 8,
            children: ctrl.defaultCategories.map((cat) => ActionChip(
              label: Text(cat),
              avatar: const Icon(Icons.arrow_forward, size: 16),
              onPressed: () {
                Get.back();
                _showProductPickerForCategory(context, ctrl, cat, isDark);
              },
            )).toList(),
          )),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => _showCustomCategoryDialog(context, ctrl, isDark),
            child: const Text('فئة أخرى...'),
          ),
        ],
      ),
    );
  }

  void _showCustomCategoryDialog(BuildContext context, BridalController ctrl, bool isDark) {
    final catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('أدخل اسم الفئة'),
        content: TextField(controller: catCtrl, decoration: const InputDecoration(hintText: 'مثال: ستيريو')),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              if (catCtrl.text.isEmpty) return;
              Get.back();
              _showProductPickerForCategory(context, ctrl, catCtrl.text, isDark);
            },
            child: const Text('بحث', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showProductPickerForCategory(BuildContext context, BridalController ctrl, String category, bool isDark) {
    ctrl.loadProductsByCategory(category);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.devices),
          const SizedBox(width: 8),
          Text('اختر $category'),
        ]),
        content: SizedBox(
          width: 500, height: 400,
          child: Obx(() {
            if (ctrl.loadingProducts.value) return const Center(child: CircularProgressIndicator());
            if (ctrl.categoryProducts.isEmpty) {
              return Center(child: Text('لا توجد منتجات في فئة "$category"',
                  style: TextStyle(color: Colors.grey[500])));
            }
            return ListView.builder(
              itemCount: ctrl.categoryProducts.length,
              itemBuilder: (ctx, i) {
                final p = ctrl.categoryProducts[i];
                final stock = (p['stockQuantity'] as num?)?.toDouble() ?? 0;
                final price = (p['price'] as num?)?.toDouble() ?? 0;
                final isAvailable = (p['isAvailable'] as bool?) ?? false;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (isAvailable ? Colors.green : Colors.red).withAlpha(20),
                    child: Icon(isAvailable ? Icons.check : Icons.close,
                        color: isAvailable ? Colors.green : Colors.red, size: 18),
                  ),
                  title: Text(p['name'] as String? ?? ''),
                  subtitle: Text('${AppFormatters.currency(price)} | مخزون: ${stock.toInt()}',
                      style: const TextStyle(fontSize: 12)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAvailable ? AppTheme.primaryColor : Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () {
                      ctrl.addItemToChecklist(p, category, 1);
                      Get.back();
                      ToastService.showSuccess('تمت الإضافة: ${p['name']}');
                    },
                    child: const Text('إضافة', style: TextStyle(fontSize: 12)),
                  ),
                );
              },
            );
          }),
        ),
        actions: [TextButton(onPressed: () => Get.back(), child: const Text('إغلاق'))],
      ),
    );
  }

  // ─── New Order Dialog ──────────────────────────────────────────────────────

  void _showNewOrderDialog(BuildContext context, BridalController ctrl, bool isDark) {
    final downPaymentCtrl = TextEditingController();
    final eventDateCtrl = TextEditingController();
    final deliveryDateCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final customerSearchCtrl = TextEditingController();
    String? selectedCustomerId;

    ctrl.checklistItems.clear();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.face_3, color: Colors.pink, size: 22),
            SizedBox(width: 8),
            Text('حجز عروسة جديد'),
          ]),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Customer search
                Obx(() => Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (TextEditingValue v) {
                    ctrl.searchCustomers(v.text);
                    return ctrl.customerSuggestions;
                  },
                  displayStringForOption: (o) => o['name'] as String? ?? '',
                  onSelected: (o) {
                    selectedCustomerId = o['id'] as String?;
                    customerSearchCtrl.text = o['name'] as String? ?? '';
                  },
                  fieldViewBuilder: (ctx, controller, fn, onSubmit) {
                    return TextField(
                      controller: controller,
                      focusNode: fn,
                      decoration: const InputDecoration(
                        labelText: 'اسم العروسة (عميل) *',
                        prefixIcon: Icon(Icons.person_search),
                      ),
                    );
                  },
                )),
                const SizedBox(height: 12),

                // Checklist builder
                Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('قائمة الأجهزة:', style: TextStyle(fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('إضافة جهاز'),
                        onPressed: () {
                          Get.back();
                          _showCategoryPicker(context, ctrl, isDark);
                          Future.delayed(500.ms, () => _showNewOrderDialog(context, ctrl, isDark));
                        },
                      ),
                    ]),
                    if (ctrl.checklistItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('أضف الأجهزة المطلوبة للعروسة', style: TextStyle(color: Colors.grey)),
                        ]),
                      ),
                    ...ctrl.checklistItems.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 13))),
                        Text('${item.quantity} × ${AppFormatters.currency(item.unitPrice)}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        IconButton(
                          onPressed: () => ctrl.removeItem(item.productId),
                          icon: const Icon(Icons.close, size: 14, color: Colors.red),
                          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                        ),
                      ]),
                    )),
                    if (ctrl.checklistItems.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'الإجمالي: ${AppFormatters.currency(ctrl.totalAmount)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                      ),
                  ],
                )),
                const SizedBox(height: 12),

                // Down payment
                TextField(
                  controller: downPaymentCtrl,
                  decoration: const InputDecoration(labelText: 'العربون (الدفعة المقدمة) *', prefixIcon: Icon(Icons.payments)),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),

                // Dates
                Row(children: [
                  Expanded(child: TextField(
                    controller: eventDateCtrl,
                    decoration: const InputDecoration(labelText: 'تاريخ الفرح', prefixIcon: Icon(Icons.celebration), hintText: 'YYYY-MM-DD'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(
                    controller: deliveryDateCtrl,
                    decoration: const InputDecoration(labelText: 'تاريخ التوصيل', prefixIcon: Icon(Icons.local_shipping), hintText: 'YYYY-MM-DD'),
                  )),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'ملاحظات', prefixIcon: Icon(Icons.notes)),
                  maxLines: 2,
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              onPressed: () async {
                if (selectedCustomerId == null) {
                  ToastService.showError('اختر اسم العروسة أولاً');
                  return;
                }
                if (downPaymentCtrl.text.isEmpty) {
                  ToastService.showError('أدخل مبلغ العربون');
                  return;
                }
                final ok = await ctrl.createOrder(
                  customerId: selectedCustomerId!,
                  downPayment: double.tryParse(downPaymentCtrl.text) ?? 0,
                  eventDate: DateTime.tryParse(eventDateCtrl.text),
                  deliveryDate: DateTime.tryParse(deliveryDateCtrl.text),
                  notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                );
                if (ok) Get.back();
              },
              child: const Text('تأكيد الحجز', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Reminders Dialog ──────────────────────────────────────────────────────

  void _showRemindersDialog(BuildContext context, BridalController ctrl, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 800,
          height: 600,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? DesignTokens.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange.withAlpha(20), shape: BoxShape.circle),
                    child: const Icon(Icons.notifications_active, color: Colors.orange, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تنبيهات التسليم', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('الطلبيات المقترب موعد تسليمها (خلال ١٤ يوماً)', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    ],
                  ),
                ],
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 24),
            Expanded(
              child: Obx(() {
                if (ctrl.isLoadingReminders.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (ctrl.deliveryReminders.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle_outline, size: 60, color: Colors.green.withAlpha(100)),
                      const SizedBox(height: 16),
                      const Text('لا يوجد طلبيات قريبة تواجه نقص في المخزون', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ]),
                  );
                }

                return ListView.separated(
                  itemCount: ctrl.deliveryReminders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, i) {
                    final rem = ctrl.deliveryReminders[i];
                    final missing = (rem['missingItems'] as List<dynamic>? ?? []);
                    final canDeliver = rem['canDeliver'] == true;
                    
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withAlpha(40) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: canDeliver ? Colors.green.withAlpha(50) : Colors.red.withAlpha(50)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('العروسة: ${rem['customerName']} - ${rem['invoiceNo']}', 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: rem['daysRemaining'] == 0 ? Colors.red.withAlpha(20) : Colors.orange.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(rem['daysRemaining'] == 0 ? 'التسليم اليوم' : 'باقي ${rem['daysRemaining']} أيام',
                                  style: TextStyle(
                                    color: rem['daysRemaining'] == 0 ? Colors.red : Colors.orange,
                                    fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (missing.isEmpty)
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                const SizedBox(width: 8),
                                const Text('جميع الأجهزة متوفرة في المخزن', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    ctrl.selectOrder(rem['id']);
                                  },
                                  child: const Text('تسليم الطلب'),
                                ),
                              ],
                            )
                          else ...[
                            Text('الأجهزة الناقصة ويلزم شراؤها:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ...missing.map((m) => Padding(
                              padding: const EdgeInsets.only(bottom: 4, right: 16),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(m['name'])),
                                  Text('مطلوب: ${m['requiredQuantity']} | ', style: TextStyle(color: Colors.grey[600])),
                                  Text('متوفر: ${m['availableQuantity']} | ', style: TextStyle(color: Colors.grey[600])),
                                  Text('ناقص: ${m['missingQuantity']}', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )).toList(),
                          ]
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ]),
        ),
      ),
    );
  }
}
