import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';

// ── Local model ────────────────────────────────────────────────────────────────
class _InstallmentItem {
  final String id;
  final double amount;
  final DateTime dueDate;
  final String status;       // "Pending" | "Paid" | "Overdue"
  final int daysOverdue;
  final String customerName;
  final String? customerPhone;
  final String invoiceNo;
  final String invoiceId;
  final bool reminderSent;

  _InstallmentItem({
    required this.id,
    required this.amount,
    required this.dueDate,
    required this.status,
    required this.daysOverdue,
    required this.customerName,
    this.customerPhone,
    required this.invoiceNo,
    required this.invoiceId,
    required this.reminderSent,
  });

  factory _InstallmentItem.fromJson(Map<String, dynamic> j) => _InstallmentItem(
    id: j['id'] as String,
    amount: (j['amount'] as num).toDouble(),
    dueDate: DateTime.parse(j['dueDate'] as String),
    status: j['status'] as String,
    daysOverdue: j['daysOverdue'] as int? ?? 0,
    customerName: j['customerName'] as String? ?? '',
    customerPhone: j['customerPhone'] as String?,
    invoiceNo: j['invoiceNo'] as String? ?? '',
    invoiceId: j['invoiceId'] as String? ?? '',
    reminderSent: j['reminderSent'] as bool? ?? false,
  );
}

class InstallmentsScreen extends StatefulWidget {
  const InstallmentsScreen({super.key});

  @override
  State<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends State<InstallmentsScreen> {
  // State
  final RxList<_InstallmentItem> items = <_InstallmentItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxString activeFilter = 'all'.obs; // 'all' | 'overdue' | 'dueSoon'
  final RxMap<String, dynamic> summary = <String, dynamic>{}.obs;

  // Summary totals
  double get overdueTotal => (summary['overdueTotal'] as num?)?.toDouble() ?? 0;
  int get overdueCount => summary['overdueCount'] as int? ?? 0;
  double get pendingTotal => (summary['pendingTotal'] as num?)?.toDouble() ?? 0;
  double get paidTotal => (summary['paidTotal'] as num?)?.toDouble() ?? 0;
  int get dueSoonCount => summary['dueSoonCount'] as int? ?? 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    isLoading.value = true;
    try {
      final filter = activeFilter.value == 'all' ? '' : '?filter=${activeFilter.value}';
      final results = await Future.wait([
        ApiService.get('installments$filter'),
        ApiService.get('installments/summary'),
      ]);
      final data = results[0] as Map<String, dynamic>;
      items.assignAll(
        ((data['data'] as List?) ?? []).map((e) => _InstallmentItem.fromJson(e as Map<String, dynamic>)).toList(),
      );
      summary.assignAll(results[1] as Map<String, dynamic>);
    } catch (_) {} finally {
      isLoading.value = false;
    }
  }

  Future<void> _payInstallment(_InstallmentItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الدفع'),
        content: Text('هل تريد تأكيد دفع قسط بقيمة ${AppFormatters.currency(item.amount)} للعميل ${item.customerName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد الدفع')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.post('installments/${item.id}/pay', {'amountPaid': item.amount});
      Get.snackbar('✓ تم', 'تم تسجيل دفعة ${item.customerName}', backgroundColor: Colors.green.withAlpha(200), colorText: Colors.white);
      await _loadData();
    } catch (e) {
      Get.snackbar('خطأ', e.toString(), backgroundColor: Colors.red.withAlpha(200), colorText: Colors.white);
    }
  }

  Future<void> _sendReminder(_InstallmentItem item) async {
    try {
      final res = await ApiService.post('installments/${item.id}/send-reminder', {}) as Map<String, dynamic>;
      Get.snackbar('📱 تذكير', res['message'] as String? ?? 'تم الإرسال',
          backgroundColor: Colors.indigo.withAlpha(200), colorText: Colors.white);
      await _loadData();
    } catch (e) {
      Get.snackbar('خطأ', e.toString(), backgroundColor: Colors.red.withAlpha(200), colorText: Colors.white);
    }
  }

  Future<void> _exportCsv() async {
    try {
      final filter = activeFilter.value == 'all' ? '' : '?filter=${activeFilter.value}';
      // Open the export URL in the system browser/downloader
      const baseUrl = ApiService.baseUrl; // e.g. http://localhost:5000/api
      Get.snackbar('📥 تصدير', 'جارٍ تنزيل الملف...', backgroundColor: Colors.blue.withAlpha(200), colorText: Colors.white);
      await ApiService.get('installments/export-csv$filter');
    } catch (_) {
      Get.snackbar('📥 CSV', 'سيُفتح الملف في المتصفح. تأكد من الوصول للـ API', duration: const Duration(seconds: 4));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(isDark),
              const SizedBox(height: 20),
              // Summary KPI cards
              Obx(() => _buildSummaryCards(isDark)),
              const SizedBox(height: 16),
              // Filter chips + export button
              _buildFilterRow(),
              const SizedBox(height: 16),
              // Table
              Expanded(
                child: Obx(() {
                  if (isLoading.value) return const Center(child: CircularProgressIndicator());
                  if (items.isEmpty) return _buildEmpty();
                  return _buildTable(isDark);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الأقساط والمتأخرات', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('تتبع وإدارة أقساط العملاء', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ]).animate().fade().slideX(begin: 0.1),
        Row(children: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData, tooltip: 'تحديث'),
          const SizedBox(width: 8),
          Tooltip(
            message: 'تصدير CSV لـ Excel',
            child: FilledButton.icon(
              onPressed: () => _openCsvInBrowser(),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('تصدير CSV'),
              style: FilledButton.styleFrom(backgroundColor: Colors.green),
            ),
          ),
        ]).animate().fade().slideX(begin: -0.1),
      ],
    );
  }

  void _openCsvInBrowser() {
    final filter = activeFilter.value == 'all' ? '' : '?filter=${activeFilter.value}';
    final url = '${ApiService.baseUrl}/installments/export-csv$filter';
    Get.snackbar('📥 تصدير', 'افتح الرابط في المتصفح:\n$url',
        duration: const Duration(seconds: 6),
        backgroundColor: Colors.green.withAlpha(220), colorText: Colors.white);
  }

  Widget _buildSummaryCards(bool isDark) {
    return Row(children: [
      _kpiCard('متأخرة', '$overdueCount قسط\n${AppFormatters.currency(overdueTotal)}', Icons.warning_amber_rounded, Colors.red, isDark),
      const SizedBox(width: 12),
      _kpiCard('قادمة هذا الأسبوع', '$dueSoonCount قسط', Icons.schedule_rounded, Colors.orange, isDark),
      const SizedBox(width: 12),
      _kpiCard('إجمالي المعلقة', AppFormatters.currency(pendingTotal), Icons.pending_rounded, Colors.blue, isDark),
      const SizedBox(width: 12),
      _kpiCard('إجمالي المدفوعة', AppFormatters.currency(paidTotal), Icons.check_circle_outline_rounded, Colors.green, isDark),
    ]);
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(200),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withAlpha(40)),
            ),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withAlpha(25), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color), maxLines: 2),
              ])),
            ]),
          ),
        ),
      ).animate().fadeIn().slideY(begin: 0.1),
    );
  }

  Widget _buildFilterRow() {
    return Obx(() => Row(children: [
      _chip('الكل', 'all'),
      const SizedBox(width: 8),
      _chip('المتأخرة', 'overdue', badgeCount: overdueCount, badgeColor: Colors.red),
      const SizedBox(width: 8),
      _chip('هذا الأسبوع', 'dueSoon', badgeCount: dueSoonCount, badgeColor: Colors.orange),
    ]));
  }

  Widget _chip(String label, String value, {int badgeCount = 0, Color badgeColor = Colors.grey}) {
    final isActive = activeFilter.value == value;
    return GestureDetector(
      onTap: () { activeFilter.value = value; _loadData(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppTheme.primaryColor : Colors.grey.withAlpha(80)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(color: isActive ? Colors.white : null, fontWeight: isActive ? FontWeight.bold : null, fontSize: 13)),
          if (badgeCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)),
              child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.payments_outlined, size: 80, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text('لا توجد أقساط في هذه الفئة', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
    ]));
  }

  Widget _buildTable(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(5) : Colors.white.withAlpha(200),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(isDark ? 20 : 60)),
          ),
          child: SingleChildScrollView(
            child: DataTable(
              columnSpacing: 16,
              headingRowColor: WidgetStateProperty.all(AppTheme.primaryColor.withAlpha(20)),
              columns: const [
                DataColumn(label: Text('العميل', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('رقم الفاتورة', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('المبلغ', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('تاريخ الاستحقاق', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('إجراءات', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: items.asMap().entries.map((e) {
                final i = e.value;
                final isOverdue = i.status == 'Pending' && i.daysOverdue > 0;
                final isPaid = i.status == 'Paid';
                final statusColor = isPaid ? Colors.green : isOverdue ? Colors.red : Colors.orange;
                final statusLabel = isPaid ? 'مدفوع' : isOverdue ? 'متأخر ${i.daysOverdue}ي' : 'معلق';

                return DataRow(
                  color: WidgetStateProperty.all(
                    isOverdue ? Colors.red.withAlpha(8) : e.key.isEven ? Colors.transparent : Colors.black.withAlpha(5),
                  ),
                  cells: [
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        if (i.customerPhone != null)
                          Text(i.customerPhone!, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      ],
                    )),
                    DataCell(Text(i.invoiceNo, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(AppFormatters.currency(i.amount), style: TextStyle(fontWeight: FontWeight.bold, color: statusColor))),
                    DataCell(Text(AppFormatters.date(i.dueDate), style: TextStyle(color: isOverdue ? Colors.red : null, fontSize: 13))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                      child: Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    )),
                    DataCell(isPaid
                      ? Icon(Icons.check_circle_rounded, color: Colors.green, size: 22)
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          Tooltip(
                            message: 'تسجيل الدفع',
                            child: IconButton(
                              icon: const Icon(Icons.payments_rounded, color: Colors.green, size: 20),
                              onPressed: () => _payInstallment(i),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (i.customerPhone != null)
                            Tooltip(
                              message: i.reminderSent ? 'تم إرسال تذكير' : 'إرسال تذكير',
                              child: IconButton(
                                icon: Icon(Icons.sms_rounded, color: i.reminderSent ? Colors.grey : Colors.indigo, size: 20),
                                onPressed: i.reminderSent ? null : () => _sendReminder(i),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                        ]),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }
}
