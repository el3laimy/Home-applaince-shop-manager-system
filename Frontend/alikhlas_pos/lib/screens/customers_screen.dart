import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/customer_model.dart';
import '../services/api_service.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/toast_service.dart';
import '../controllers/customer_controller.dart';

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
          colors: isDark ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)] : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)],
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
                      Text('كشف الحساب، المشتريات، والأرصدة', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
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
                child: Row(
                  children: [
                    // Customer list
                    SizedBox(
                      width: 300,
                      child: _buildCustomerList(context, ctrl, isDark),
                    ),
                    const SizedBox(width: 20),
                    // Detail panel
                    Expanded(
                      child: Obx(() => ctrl.selected.value == null
                          ? _buildEmptyDetail(context)
                          : _buildDetailPanel(context, ctrl, isDark)),
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
              Expanded(
                child: Obx(() {
                  if (ctrl.isLoading.value && ctrl.customers.isEmpty) return const Center(child: CircularProgressIndicator());
                  if (ctrl.customers.isEmpty) return Center(child: Text('لا يوجد عملاء', style: TextStyle(color: Colors.grey[500])));
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: ctrl.customers.length,
                    itemBuilder: (ctx, i) {
                      final c = ctrl.customers[i];
                      return Obx(() {
                        final isSelected = ctrl.selected.value?.id == c.id;
                        return GestureDetector(
                          onTap: () => ctrl.selectCustomer(c),
                          child: AnimatedContainer(
                            duration: 200.ms,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryColor.withAlpha(25) : (isDark ? Colors.black.withAlpha(30) : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.withAlpha(40)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor.withAlpha(isSelected ? 50 : 20), radius: 18,
                                  child: Icon(Icons.person, color: AppTheme.primaryColor, size: 18),
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
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _buildEmptyDetail(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 80, color: Colors.grey.withAlpha(70)),
          const SizedBox(height: 16),
          Text('اختر عميلًا لعرض كشف حسابه', style: TextStyle(color: Colors.grey[500], fontSize: 18)),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildDetailPanel(BuildContext context, CustomerController ctrl, bool isDark) {
    final c = ctrl.selected.value!;
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.primaryColor.withAlpha(180), AppTheme.secondaryColor.withAlpha(180)]),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      if (c.phone != null) Text(c.phone!, style: const TextStyle(color: Colors.white70)),
                    ]),
                    Row(children: [
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.white70), onPressed: () => ctrl.deleteCustomer(c.id, context)),
                    ]),
                  ],
                ),
              ),
              // Stats
              Obx(() => Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  _statTile(context, 'إجمالي الشراء', '${ctrl.totalDue.value.toStringAsFixed(2)} ج.م', Colors.blue, isDark),
                  const SizedBox(width: 12),
                  _statTile(context, 'المدفوع', '${ctrl.totalPaid.value.toStringAsFixed(2)} ج.م', Colors.green, isDark),
                  const SizedBox(width: 12),
                  _statTile(context, 'الرصيد', '${(ctrl.totalDue.value - ctrl.totalPaid.value).toStringAsFixed(2)} ج.م',
                      (ctrl.totalDue.value - ctrl.totalPaid.value) > 0 ? Colors.orange : Colors.grey, isDark),
                ]),
              )),
              // Invoices
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('سجل الفواتير', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Obx(() {
                  if (ctrl.isLoading.value) return const Center(child: CircularProgressIndicator());
                  if (ctrl.statement.isEmpty) return Center(child: Text('لا توجد فواتير', style: TextStyle(color: Colors.grey[500])));
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: ctrl.statement.length,
                    itemBuilder: (ctx, i) {
                      final inv = ctrl.statement[i];
                      return Card(
                        elevation: 0,
                        color: isDark ? Colors.white.withAlpha(8) : Colors.white,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: AppTheme.primaryColor.withAlpha(25), child: Icon(Icons.receipt, color: AppTheme.primaryColor, size: 20)),
                          title: Text(inv['invoiceNo'] as String? ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(inv['createdAt'] as String? ?? ''),
                          trailing: Text('${inv['totalAmount']} ج.م', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _statTile(BuildContext context, String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withAlpha(60))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
        ]),
      ),
    );
  }

  void _showAddDialog(BuildContext context, CustomerController ctrl) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة عميل جديد'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم العميل *')),
          const SizedBox(height: 12),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
        ]),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final ok = await ctrl.addCustomer(nameCtrl.text, phoneCtrl.text.isEmpty ? null : phoneCtrl.text, context);
              if (ok) Get.back();
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
