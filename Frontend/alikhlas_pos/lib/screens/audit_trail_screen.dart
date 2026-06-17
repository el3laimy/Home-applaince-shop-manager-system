import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../core/theme/design_tokens.dart';
import '../core/widgets/neo_button.dart';

class AuditTrailScreen extends StatefulWidget {
  const AuditTrailScreen({super.key});

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  final _logs = <Map<String, dynamic>>[].obs;
  final _isLoading = true.obs;
  final _page = 1.obs;
  final _totalPages = 1.obs;
  final _totalCount = 0.obs;
  final _searchCtrl = TextEditingController();
  final _selectedTable = ''.obs;
  final _selectedAction = ''.obs;
  final _tables = <String>[].obs;
  final _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _fetchTables();
    _fetchLogs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTables() async {
    try {
      final data = await ApiService.get('auditlogs/tables');
      if (data is List) {
        _tables.assignAll(data.cast<String>());
      }
    } catch (_) {}
  }

  Future<void> _fetchLogs() async {
    _isLoading.value = true;
    try {
      final params = <String, String>{
        'page': _page.value.toString(),
        'pageSize': _pageSize.toString(),
      };
      if (_searchCtrl.text.isNotEmpty) params['search'] = _searchCtrl.text;
      if (_selectedTable.value.isNotEmpty) params['table'] = _selectedTable.value;
      if (_selectedAction.value.isNotEmpty) params['action'] = _selectedAction.value;

      final queryStr = params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final data = await ApiService.get('auditlogs?$queryStr');
      
      _logs.assignAll((data['items'] as List).cast<Map<String, dynamic>>());
      _totalCount.value = data['totalCount'] as int? ?? 0;
      _totalPages.value = data['totalPages'] as int? ?? 1;
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحميل سجل المراجعة: $e',
          backgroundColor: Colors.red.withAlpha(220), colorText: Colors.white);
    } finally {
      _isLoading.value = false;
    }
  }

  void _search() {
    _page.value = 1;
    _fetchLogs();
  }

  @override
  Widget build(BuildContext context) {
    return DesignTokens.neoPageBackgroundWidget(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.kPagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildFilters(),
              const SizedBox(height: 16),
              Expanded(child: _buildLogTable()),
              _buildPagination(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DesignTokens.holographicText(
              text: 'سجل المراجعة (Audit Trail)',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Obx(() => Text(
              'إجمالي: ${_totalCount.value} سجل',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            )),
          ],
        ),
      ],
    ).animate().fade().slideX(begin: 0.05);
  }

  Widget _buildFilters() {
    return DesignTokens.neoGlassBox(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Search
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'بحث بالمستخدم أو الجدول أو القيمة...',
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () { _searchCtrl.clear(); _search(); },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white.withAlpha(10),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          // Table filter
          Expanded(
            flex: 2,
            child: Obx(() => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTable.value.isEmpty ? null : _selectedTable.value,
                  hint: Text('كل الجداول', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1D2E),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('الكل', style: TextStyle(color: Colors.white))),
                    ..._tables.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))),
                  ],
                  onChanged: (v) {
                    _selectedTable.value = v ?? '';
                    _search();
                  },
                ),
              ),
            )),
          ),
          const SizedBox(width: 12),
          // Action filter
          Expanded(
            flex: 1,
            child: Obx(() => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedAction.value.isEmpty ? null : _selectedAction.value,
                  hint: Text('كل العمليات', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1D2E),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('الكل', style: TextStyle(color: Colors.white))),
                    const DropdownMenuItem(value: 'Create', child: Text('إنشاء', style: TextStyle(color: Colors.greenAccent))),
                    const DropdownMenuItem(value: 'Update', child: Text('تعديل', style: TextStyle(color: Colors.orangeAccent))),
                    const DropdownMenuItem(value: 'Delete', child: Text('حذف', style: TextStyle(color: Colors.redAccent))),
                  ],
                  onChanged: (v) {
                    _selectedAction.value = v ?? '';
                    _search();
                  },
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTable() {
    return Obx(() {
      if (_isLoading.value && _logs.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: DesignTokens.neonCyan));
      }
      if (_logs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 48, color: Colors.white.withAlpha(30)),
              const SizedBox(height: 12),
              Text('لا توجد سجلات مراجعة', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ],
          ),
        );
      }
      return DesignTokens.neoGlassBox(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.white.withAlpha(5)),
            dataRowMinHeight: 44,
            dataRowMaxHeight: 80,
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12))),
              DataColumn(label: Text('العملية', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12))),
              DataColumn(label: Text('الجدول', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12))),
              DataColumn(label: Text('المعرف', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12))),
              DataColumn(label: Text('المستخدم', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12))),
              DataColumn(label: Text('التفاصيل', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12))),
            ],
            rows: _logs.map((log) {
              final action = log['action'] as String? ?? '';
              final actionColor = action == 'Create' ? Colors.greenAccent
                  : action == 'Delete' ? Colors.redAccent
                  : Colors.orangeAccent;
              final actionLabel = action == 'Create' ? 'إنشاء'
                  : action == 'Delete' ? 'حذف'
                  : 'تعديل';
              final dateStr = _formatDate(log['createdAt'] as String? ?? '');

              return DataRow(cells: [
                DataCell(Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.white70))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: actionColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(actionLabel, style: TextStyle(color: actionColor, fontSize: 11, fontWeight: FontWeight.bold)),
                )),
                DataCell(Text(log['tableName'] as String? ?? '', style: const TextStyle(fontSize: 12, color: Colors.white))),
                DataCell(SelectableText(
                  (log['recordId'] as String? ?? '').length > 8
                      ? '${(log['recordId'] as String).substring(0, 8)}...'
                      : log['recordId'] as String? ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                )),
                DataCell(Text(log['createdBy'] as String? ?? '', style: const TextStyle(fontSize: 12, color: DesignTokens.neonCyan))),
                DataCell(
                  SizedBox(
                    width: 300,
                    child: Text(
                      _summarizeChanges(log),
                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      );
    });
  }

  Widget _buildPagination() {
    return Obx(() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          NeoButton.outlined(
            label: 'السابق',
            icon: Icons.arrow_forward,
            color: DesignTokens.neonCyan,
            onPressed: _page.value > 1 ? () { _page.value--; _fetchLogs(); } : null,
          ),
          const SizedBox(width: 16),
          Text(
            'صفحة ${_page.value} من ${_totalPages.value}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(width: 16),
          NeoButton.outlined(
            label: 'التالي',
            icon: Icons.arrow_back,
            color: DesignTokens.neonCyan,
            onPressed: _page.value < _totalPages.value ? () { _page.value++; _fetchLogs(); } : null,
          ),
        ],
      ),
    ));
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return isoDate;
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _summarizeChanges(Map<String, dynamic> log) {
    final action = log['action'] as String? ?? '';
    final newValues = log['newValues'] as String? ?? '';
    final oldValues = log['oldValues'] as String? ?? '';
    
    if (action == 'Create' && newValues.isNotEmpty) {
      return 'إنشاء: $newValues';
    } else if (action == 'Delete' && oldValues.isNotEmpty) {
      return 'حذف: $oldValues';
    } else if (action == 'Update') {
      if (oldValues.isNotEmpty && newValues.isNotEmpty) {
        return 'قبل: $oldValues\nبعد: $newValues';
      }
      return newValues.isNotEmpty ? newValues : oldValues;
    }
    return '';
  }
}
