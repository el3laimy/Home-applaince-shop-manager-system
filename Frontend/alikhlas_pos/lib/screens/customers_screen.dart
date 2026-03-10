import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/customer_model.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/toast_service.dart';
import '../core/utils/formatters.dart';
import '../controllers/customer_controller.dart';
import 'customer_profile_screen.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<CustomerController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: isDark ? [DesignTokens.bgDark, const Color(0xFF0F1629)] : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إدارة العملاء', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Obx(() => Text('إجمالي: ${ctrl.totalCount.value} عميل', style: TextStyle(color: Colors.grey[500], fontSize: 13))),
                    ],
                  ).animate().fade().slideX(begin: 0.1),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.person_add),
                    label: const Text('إضافة عميل', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _showAddDialog(context, ctrl),
                  ).animate().fade(),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _buildCustomerList(context, ctrl, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerList(BuildContext context, CustomerController ctrl, bool isDark) {
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو الهاتف...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true, fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => ctrl.fetch(search: v),
                ),
              ),
              // Sort bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Obx(() => Row(
                  children: [
                    Icon(Icons.sort, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    _sortChip(ctrl, 'name', 'أبجدي', isDark),
                    const SizedBox(width: 6),
                    _sortChip(ctrl, 'balance', 'أعلى رصيد', isDark),
                    const SizedBox(width: 6),
                    _sortChip(ctrl, 'newest', 'الأحدث', isDark),
                  ],
                )),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  if (ctrl.isLoading.value && ctrl.customers.isEmpty) return const Center(child: CircularProgressIndicator());
                  if (ctrl.customers.isEmpty) return Center(child: Text('لا يوجد عملاء', style: TextStyle(color: Colors.grey[500])));
                  return NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollEndNotification &&
                          n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                        ctrl.loadMore();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: ctrl.customers.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == ctrl.customers.length) {
                          return Obx(() {
                            if (ctrl.isLoadingMore.value) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }
                            if (!ctrl.hasMore && ctrl.customers.isNotEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(12),
                                child: Center(child: Text(
                                  'تم عرض جميع العملاء (${ctrl.totalCount.value})',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                )),
                              );
                            }
                            return const SizedBox.shrink();
                          });
                        }
                        return Obx(() {
                          final c = ctrl.customers[i];
                          return GestureDetector(
                            onTap: () {
                              ctrl.selected.value = c;
                              Get.to(() => CustomerProfileScreen(customer: c));
                            },
                            child: AnimatedContainer(
                              duration: 200.ms,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black.withAlpha(30) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.withAlpha(40)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor.withAlpha(20), radius: 18,
                                    child: Text(c.name.isNotEmpty ? c.name[0] : '?',
                                        style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                        if (c.phone != null) Text(c.phone!, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  if (c.balance > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                                      child: Text('${c.balance.toStringAsFixed(0)} ج', style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ),
                          );
                        });
                      },
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _sortChip(CustomerController ctrl, String value, String label, bool isDark) {
    final isActive = ctrl.sortBy.value == value;
    return GestureDetector(
      onTap: () => ctrl.changeSort(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor.withAlpha(30) : (isDark ? Colors.black.withAlpha(20) : Colors.grey.withAlpha(20)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppTheme.primaryColor.withAlpha(80) : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? AppTheme.primaryColor : Colors.grey[500],
        )),
      ),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────────

  void _showAddDialog(BuildContext context, CustomerController ctrl) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.person_add, size: 22),
          SizedBox(width: 8),
          Text('إضافة عميل جديد'),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم العميل *', prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'العنوان', prefixIcon: Icon(Icons.location_on))),
            const SizedBox(height: 12),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات', prefixIcon: Icon(Icons.notes)), maxLines: 2),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final ok = await ctrl.addCustomer(
                nameCtrl.text,
                phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                addressCtrl.text.isEmpty ? null : addressCtrl.text,
                notesCtrl.text.isEmpty ? null : notesCtrl.text,
                context,
              );
              if (ok) Get.back();
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, CustomerController ctrl, CustomerModel c) {
    final nameCtrl = TextEditingController(text: c.name);
    final phoneCtrl = TextEditingController(text: c.phone ?? '');
    final addressCtrl = TextEditingController(text: c.address ?? '');
    final notesCtrl = TextEditingController(text: c.notes ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.edit, size: 22),
          SizedBox(width: 8),
          Text('تعديل بيانات العميل'),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم العميل *', prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'العنوان', prefixIcon: Icon(Icons.location_on))),
            const SizedBox(height: 12),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات', prefixIcon: Icon(Icons.notes)), maxLines: 2),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final ok = await ctrl.updateCustomer(
                c.id,
                nameCtrl.text,
                phoneCtrl.text.isEmpty ? null : phoneCtrl.text,
                addressCtrl.text.isEmpty ? null : addressCtrl.text,
                notesCtrl.text.isEmpty ? null : notesCtrl.text,
              );
              if (ok) Get.back();
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }



  void _showDeleteConfirm(BuildContext context, CustomerController ctrl, CustomerModel c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.red, size: 22),
          SizedBox(width: 8),
          Text('تأكيد الحذف'),
        ]),
        content: Text('هل أنت متأكد من حذف العميل "${c.name}"?\nلن يتم حذف الفواتير السابقة.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ctrl.deleteCustomer(c.id, context);
              Get.back();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }


}
