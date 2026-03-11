import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/customer_model.dart';
import '../controllers/customer_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../core/utils/formatters.dart';
import '../services/pdf_service.dart';

class CustomerProfileScreen extends StatelessWidget {
  final CustomerModel customer;
  const CustomerProfileScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<CustomerController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Trigger fetch when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctrl.selectCustomer(customer);
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DesignTokens.neoPageBackgroundWidget(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, ctrl, isDark),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sidebar Summary
                    SizedBox(width: 300, child: _buildSidebarSummary(context, ctrl, isDark)),
                    const SizedBox(width: 24),
                    // Timeline Main Area
                    Expanded(child: _buildTimelineArea(context, ctrl, isDark)),
                    const SizedBox(width: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CustomerController ctrl, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 28),
            onPressed: () => Get.back(),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primaryColor.withAlpha(30),
            child: const Icon(Icons.person, color: AppTheme.primaryColor, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(customer.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              if (customer.phone != null)
                Text(customer.phone!, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.print),
            label: const Text('طباعة كشف الحساب'),
            onPressed: () async {
              try {
                // Use PdfService to fetch and show the statement PDF
                await PdfService.fetchAndShowPdf(
                  endpoint: 'customers/${customer.id}/statement/pdf',
                  title: 'كشف حساب - ${customer.name}',
                );
              } catch (e) {
                Get.snackbar('خطأ', 'فشل في تحميل كشف الحساب', backgroundColor: Colors.red.withAlpha(200), colorText: Colors.white);
              }
            },
          ),
        ],
      ),
    ).animate().fade().slideY(begin: -0.1);
  }

  Widget _buildSidebarSummary(BuildContext context, CustomerController ctrl, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(200),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(isDark ? 20 : 60)),
            ),
            child: Obx(() {
              if (ctrl.isLoading.value) return const Center(child: CircularProgressIndicator());
              
              final bal = ctrl.remainingBalance.value;
              final isDebt = bal > 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('الرصيد المستحق', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    AppFormatters.currency(bal),
                    style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold,
                      color: isDebt ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isDebt)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.payments),
                        label: const Text('تسجيل دفعة نقدية', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _showPaymentDialog(context, ctrl),
                      ),
                    ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildSummaryItem(Icons.shopping_bag, 'إجمالي المشتريات', AppFormatters.currency(ctrl.totalDue.value), Colors.blue),
                  const SizedBox(height: 16),
                  _buildSummaryItem(Icons.account_balance_wallet, 'إجمالي المدفوعات', AppFormatters.currency(ctrl.totalPaid.value), Colors.green),
                  const SizedBox(height: 16),
                  _buildSummaryItem(Icons.assignment_return, 'المرتجعات', AppFormatters.currency(ctrl.totalReturns.value), Colors.orange),
                ],
              );
            }),
          ),
        ),
      ),
    ).animate().fade().slideX(begin: -0.1);
  }

  Widget _buildSummaryItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineArea(BuildContext context, CustomerController ctrl, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(5) : Colors.white.withAlpha(180),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(isDark ? 20 : 60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('السجل المالي الزمني (Timeline)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Obx(() {
                  if (ctrl.isLoading.value) return const Center(child: CircularProgressIndicator());
                  if (ctrl.statement.isEmpty) {
                    return Center(child: Text('لا يوجد سجل مالي لهذا العميل بعد.', style: TextStyle(color: Colors.grey[500])));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: ctrl.statement.length,
                    itemBuilder: (context, index) {
                      final item = ctrl.statement[index];
                      return _buildTimelineNode(item, isDark);
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    ).animate().fade().slideX(begin: 0.1);
  }

  Widget _buildTimelineNode(Map<String, dynamic> item, bool isDark) {
    final type = item['type'] as String? ?? 'Invoice';
    final isInvoice = type == 'Invoice';
    final isInstallment = type == 'Installment';
    final isReturn = type == 'Return';

    final ref = item['reference'] as String? ?? '';
    final date = DateTime.tryParse(item['date']?.toString() ?? '');
    
    final total = (item['totalAmount'] as num?)?.toDouble() ?? 0;
    final paid = (item['paidAmount'] as num?)?.toDouble() ?? 0;
    final remaining = (item['remainingAmount'] as num?)?.toDouble() ?? 0;
    
    IconData icon = Icons.receipt;
    Color color = Colors.blue;
    String title = 'فاتورة مبيعات';

    if (isInstallment) {
      icon = Icons.calendar_month;
      color = Colors.purple;
      title = 'استحقاق قسط';
      if (item['status'] == 2) { // Paid
        color = Colors.green;
        title = 'قسط مسدد';
      } else if (item['isOverdue'] == true) {
        color = Colors.red;
        title = 'قسط متأخر (لم يسدد)';
      }
    } else if (isReturn) {
      icon = Icons.assignment_return;
      color = Colors.orange;
      title = 'مرتجع مبيعات';
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Line & Icon
          Column(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle, border: Border.all(color: color.withAlpha(50))),
                child: Icon(icon, color: color, size: 20),
              ),
              Expanded(child: Container(width: 2, color: Colors.grey.withAlpha(50))),
            ],
          ),
          const SizedBox(width: 16),
          // Content Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withAlpha(30) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withAlpha(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
                      if (date != null)
                        Text(AppFormatters.dateTime(date), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('المرجع: $ref', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (item['originalInvoiceNo'] != null && item['originalInvoiceNo'].toString().isNotEmpty)
                    Text('للفاتورة الأصلية: ${item['originalInvoiceNo']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 12),
                  // Amounts row
                  Row(
                    children: [
                      _amountBlock('الإجمالي', total, isDark),
                      if (isInvoice || isInstallment) ...[
                        _amountBlock('المدفوع', paid, isDark, color: Colors.green),
                        _amountBlock('المتبقي', remaining, isDark, color: remaining > 0 ? Colors.red : null),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountBlock(String label, double amount, bool isDark, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          Text(AppFormatters.currency(amount), style: TextStyle(fontWeight: FontWeight.bold, color: color ?? (isDark ? Colors.white : Colors.black87), fontSize: 14)),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, CustomerController ctrl) {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل دفعة نقدية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الرصيد المستحق: ${AppFormatters.currency(ctrl.remainingBalance.value)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 16),
            TextField(
              controller: amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'المبلغ المدفوع', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text) ?? 0;
              if (amt <= 0) return;
              Get.back();
              await ctrl.registerPayment(customer.id, amt, noteCtrl.text);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
