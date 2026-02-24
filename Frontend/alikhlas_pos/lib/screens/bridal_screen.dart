import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/bridal_controller.dart';
import '../models/customer_model.dart';
import '../models/installment_model.dart';
import '../core/theme/app_theme.dart';

class BridalOrdersScreen extends StatelessWidget {
  const BridalOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(BridalController());
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
              const SizedBox(height: 24),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bridal list sidebar
                    SizedBox(width: 280, child: _buildBridalList(context, ctrl, isDark)),
                    const SizedBox(width: 20),
                    // Main detail panel
                    Expanded(child: Obx(() => ctrl.selectedCustomer.value == null
                        ? _buildEmptyState(context)
                        : _buildDetailPanel(context, ctrl, isDark))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, BridalController ctrl, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('طلبيات وتجهيزات العرائس',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('إدارة ملفات العرائس والأقساط والدفعات',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ).animate().fade().slideX(begin: 0.1),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('فتح ملف عروسة جديد', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => _showAddBridalDialog(context, ctrl),
        ).animate().fade().slideX(begin: -0.1),
      ],
    );
  }

  Widget _buildBridalList(BuildContext context, BridalController ctrl, bool isDark) {
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
                    hintText: 'ابحث باسم العروسة...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    ctrl.searchQuery.value = val;
                    ctrl.fetchBridalCustomers();
                  },
                ),
              ),
              Expanded(
                child: Obx(() {
                  if (ctrl.isLoading.value && ctrl.bridalCustomers.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (ctrl.bridalCustomers.isEmpty) {
                    return Center(child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('لا يوجد ملفات عرائس\nاضغط "فتح ملف جديد"', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
                    ));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: ctrl.bridalCustomers.length,
                    itemBuilder: (ctx, i) {
                      final c = ctrl.bridalCustomers[i];
                      return Obx(() {
                        final isSelected = ctrl.selectedCustomer.value?.id == c.id;
                        return GestureDetector(
                          onTap: () => ctrl.selectCustomer(c),
                          child: AnimatedContainer(
                            duration: 200.ms,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryColor.withAlpha(30) : (isDark ? Colors.black.withAlpha(30) : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.grey.withAlpha(40)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: (isSelected ? AppTheme.primaryColor : Colors.grey).withAlpha(40),
                                  radius: 18,
                                  child: Icon(Icons.face_3, color: isSelected ? AppTheme.primaryColor : Colors.grey, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                                      if (c.phone != null) Text(c.phone!, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                    ],
                                  ),
                                ),
                                if (c.balance > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.orange.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                                    child: Text('${c.balance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.face_3_outlined, size: 80, color: Colors.grey.withAlpha(80)),
          const SizedBox(height: 16),
          Text('اختر ملف عروسة من القائمة', style: TextStyle(color: Colors.grey[500], fontSize: 18)),
          const SizedBox(height: 8),
          Text('أو افتح ملفًا جديدًا بالضغط على الزر أعلاه', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildDetailPanel(BuildContext context, BridalController ctrl, bool isDark) {
    final c = ctrl.selectedCustomer.value!;
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
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.secondaryColor.withAlpha(180), AppTheme.primaryColor.withAlpha(180)],
                  ),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ملف العروسة: ${c.name}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                          if (c.phone != null)
                            Text(c.phone!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    // Completion ring
                    Obx(() => Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 70, height: 70,
                          child: CircularProgressIndicator(
                            value: ctrl.completionPct / 100,
                            strokeWidth: 8,
                            backgroundColor: Colors.white.withAlpha(40),
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        Text('${ctrl.completionPct.toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    )),
                  ],
                ),
              ),

              // Stats
              Obx(() => Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    _statTile(context, 'إجمالي المطلوب', '${ctrl.totalDue.toStringAsFixed(2)} ج.م', Colors.blue, isDark),
                    const SizedBox(width: 12),
                    _statTile(context, 'المدفوع', '${ctrl.totalPaid.toStringAsFixed(2)} ج.م', Colors.green, isDark),
                    const SizedBox(width: 12),
                    _statTile(context, 'الرصيد المتبقي', '${ctrl.remainingBalance.toStringAsFixed(2)} ج.م', Colors.orange, isDark),
                  ],
                ),
              )),

              // Installments
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الأقساط والدفعات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('سداد دفعة'),
                            onPressed: () => _showPaymentDialog(context, ctrl),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Obx(() {
                          if (ctrl.selectedCustomerInstallments.isEmpty) {
                            return Center(child: Text('لا توجد أقساط مسجلة', style: TextStyle(color: Colors.grey[500])));
                          }
                          return ListView.builder(
                            itemCount: ctrl.selectedCustomerInstallments.length,
                            itemBuilder: (ctx, i) => _buildInstallmentTile(ctrl.selectedCustomerInstallments[i], isDark),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
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
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallmentTile(InstallmentModel inst, bool isDark) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (inst.status) {
      case InstallmentStatus.paid:
        statusColor = Colors.green; statusText = 'مدفوع'; statusIcon = Icons.check_circle;
      case InstallmentStatus.overdue:
        statusColor = Colors.red; statusText = 'متأخر'; statusIcon = Icons.warning;
      case InstallmentStatus.pending:
        statusColor = Colors.orange; statusText = 'معلق'; statusIcon = Icons.schedule;
    }
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withAlpha(8) : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text('${inst.amount.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('الاستحقاق: ${_formatDate(inst.dueDate)}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
          child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  void _showAddBridalDialog(BuildContext context, BridalController ctrl) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('فتح ملف عروسة جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم العروسة *')),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final ok = await ctrl.createBridalCustomer(nameCtrl.text, phoneCtrl.text.isEmpty ? null : phoneCtrl.text, context);
              if (ok) Get.back();
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, BridalController ctrl) {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل دفعة جديدة'),
        content: TextField(
          controller: amountCtrl,
          decoration: const InputDecoration(labelText: 'مبلغ الدفعة (ج.م)', prefixIcon: Icon(Icons.money)),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              if (amountCtrl.text.isEmpty) return;
              final invoiceId = ctrl.selectedCustomerInvoices.firstOrNull?.id ?? '';
              final ok = await ctrl.addPayment(invoiceId, double.tryParse(amountCtrl.text) ?? 0, context);
              if (ok) Get.back();
            },
            child: const Text('تسجيل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
