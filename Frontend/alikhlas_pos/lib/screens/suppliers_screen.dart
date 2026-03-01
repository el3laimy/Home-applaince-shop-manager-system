import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../controllers/purchasing_controller.dart';
import 'package:toastification/toastification.dart';
import '../core/utils/toast_service.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final PurchasingController ctrl = Get.find<PurchasingController>();
  late PlutoGridStateManager stateManager;
  final TextEditingController searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ctrl.fetchSuppliersWithBalances();
  }

  @override
  Widget build(BuildContext context) {
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
              _buildHeader(context, isDark),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 50 : 10),
                        blurRadius: 10, offset: const Offset(0, 4)
                      )
                    ],
                  ),
                  child: Obx(() {
                    if (ctrl.isLoadingSuppliers.value && ctrl.suppliersWithBalances.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (ctrl.suppliersWithBalances.isEmpty) {
                      return _buildEmptyState();
                    }
                    return _buildGrid(context, isDark);
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سجل الموردين',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('إدارة ديون وحسابات الموردين المركزية',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.person_add),
          label: const Text('إضافة مورد', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => _showAddSupplierDialog(context, isDark),
        )
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.business_rounded, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('لا يوجد موردين في النظام', style: TextStyle(fontSize: 20, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, bool isDark) {
    final currencyFmt = NumberFormat.currency(symbol: 'ج.م ', decimalDigits: 2);
    
    List<PlutoColumn> columns = [
      PlutoColumn(
        title: 'الاسم',
        field: 'name',
        type: PlutoColumnType.text(),
        width: 250,
      ),
      PlutoColumn(
        title: 'الشركة',
        field: 'companyName',
        type: PlutoColumnType.text(),
        width: 150,
      ),
      PlutoColumn(
        title: 'التليفون',
        field: 'phone',
        type: PlutoColumnType.text(),
        width: 150,
      ),
      PlutoColumn(
        title: 'الرصيد الافتتاحي',
        field: 'openingBalance',
        type: PlutoColumnType.number(format: '#,##0.00'),
        width: 150,
      ),
      PlutoColumn(
        title: 'إجمالي المشتريات',
        field: 'totalPurchases',
        type: PlutoColumnType.number(format: '#,##0.00'),
        width: 150,
      ),
      PlutoColumn(
        title: 'المدفوعات للصندوق',
        field: 'totalPayments',
        type: PlutoColumnType.number(format: '#,##0.00'),
        width: 150,
      ),
      PlutoColumn(
        title: 'المديونية الحالية',
        field: 'currentBalance',
        type: PlutoColumnType.number(format: '#,##0.00'),
        width: 150,
        renderer: (rendererContext) {
           final bal = (rendererContext.cell.value as num).toDouble();
           final hasDebt = bal > 0;
           return Text(currencyFmt.format(bal), style: TextStyle(color: hasDebt ? Colors.red : Colors.green, fontWeight: FontWeight.bold));
        }
      ),
      PlutoColumn(
        title: 'إجراءات',
        field: 'actions',
        type: PlutoColumnType.text(),
        width: 150,
        enableSorting: false,
        enableEditingMode: false,
        renderer: (rendererContext) {
          final s = rendererContext.row.cells['raw_supplier']!.value as Map<String, dynamic>;
          final bal = (s['currentBalance'] as num).toDouble();

          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               IconButton(
                 icon: const Icon(Icons.payment, color: Colors.green, size: 20),
                 tooltip: 'تسجيل دفعة',
                 onPressed: () => _showPaymentDialog(context, s['id'], s['name'], bal),
               ),
               IconButton(
                 icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                 tooltip: 'تعديل',
                 onPressed: () => _showEditSupplierDialog(context, s),
               ),
               IconButton(
                 icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                 tooltip: 'حذف',
                 onPressed: () => _showDeleteSupplierDialog(context, s),
               ),
            ],
          );
        },
      ),
      PlutoColumn(
        title: 'raw_supplier',
        field: 'raw_supplier',
        type: PlutoColumnType.text(),
        hide: true,
      ),
    ];

    List<PlutoRow> rows = ctrl.suppliersWithBalances.map((s) {
       return PlutoRow(cells: {
          'name': PlutoCell(value: s.name),
          'companyName': PlutoCell(value: s.companyName ?? '-'),
          'phone': PlutoCell(value: s.phone ?? '-'),
          'openingBalance': PlutoCell(value: s.openingBalance ?? 0),
          'totalPurchases': PlutoCell(value: s.totalPurchases ?? 0),
          'totalPayments': PlutoCell(value: s.totalPayments ?? 0),
          'currentBalance': PlutoCell(value: s.currentBalance ?? 0),
          'actions': PlutoCell(value: ''),
          'raw_supplier': PlutoCell(value: s.toJson()..['id'] = s.id..['currentBalance'] = s.currentBalance..['totalPurchases'] = s.totalPurchases..['totalPayments'] = s.totalPayments),
       });
    }).toList();

    return PlutoGrid(
      key: ValueKey('suppliers_grid_${ctrl.suppliersWithBalances.length}_${ctrl.suppliersWithBalances.hashCode}'),
      columns: columns,
      rows: rows,
      onLoaded: (PlutoGridOnLoadedEvent event) {
        stateManager = event.stateManager;
        stateManager.setShowColumnFilter(true);
      },
      configuration: PlutoGridConfiguration(
         style: isDark ? const PlutoGridStyleConfig.dark() : const PlutoGridStyleConfig(),
      ),
    );
  }

  void _showAddSupplierDialog(BuildContext context, bool isDark) {
    _showSupplierFormDialog(context, null);
  }

  void _showEditSupplierDialog(BuildContext context, Map<String, dynamic> supplierData) {
    _showSupplierFormDialog(context, supplierData);
  }

  void _showSupplierFormDialog(BuildContext context, Map<String, dynamic>? s) {
    final isEdit = s != null;
    final nameCtrl = TextEditingController(text: isEdit ? s['name'] : '');
    final phoneCtrl = TextEditingController(text: isEdit ? s['phone'] : '');
    final companyCtrl = TextEditingController(text: isEdit ? s['companyName'] : '');
    final addressCtrl = TextEditingController(text: isEdit ? s['address'] : '');
    final openingBalanceCtrl = TextEditingController(text: isEdit ? (s['openingBalance']?.toString() ?? '0') : '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'تعديل بيانات المورد' : 'إضافة مورد جديد', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المورد *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: companyCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                 controller: openingBalanceCtrl,
                 keyboardType: TextInputType.number,
                 decoration: const InputDecoration(labelText: 'رصيد افتتاحي (مديونية سابقة)', border: OutlineInputBorder())
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) { ToastService.showError('برجاء كتابة اسم المورد'); return; }
              
              final payload = {
                 'name': nameCtrl.text, 'phone': phoneCtrl.text,
                 'companyName': companyCtrl.text, 'address': addressCtrl.text,
                 'openingBalance': double.tryParse(openingBalanceCtrl.text) ?? 0,
              };

              if (isEdit) {
                 bool ok = await ctrl.updateSupplier(s['id'], payload, context);
                 if (ok) Navigator.pop(context);
              } else {
                 String? newId = await ctrl.addSupplier(payload, context);
                 if (newId != null) Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showDeleteSupplierDialog(BuildContext context, Map<String, dynamic> s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.red)),
        content: Text('هل أنت متأكد من حذف المورد: ${s['name']}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
               bool ok = await ctrl.deleteSupplier(s['id'], context);
               if (ok) Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, String id, String name, double currentBalance) {
     final amountCtrl = TextEditingController(text: currentBalance > 0 ? currentBalance.toString() : '');
     final notesCtrl = TextEditingController(text: 'دفعة حساب للمورد');
     showDialog(context: context, builder: (ctx) {
        return AlertDialog(
           title: Text('تسجيل دفعة نقدية للمورد: $name'),
           content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text('المديونية الحالية: ${currentBalance.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 16),
                 TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المدفوع كاش (ج.م)', border: OutlineInputBorder())),
                 const SizedBox(height: 12),
                 TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات وتفاصيل الدفعة', border: OutlineInputBorder())),
              ],
           ),
           actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () async {
                   final amt = double.tryParse(amountCtrl.text) ?? 0;
                   if (amt <= 0) { ToastService.showError('أدخل مبلغاً صحيحاً'); return; }
                   bool ok = await ctrl.registerSupplierPayment(id, amt, notesCtrl.text, context);
                   if (ok) Navigator.pop(ctx);
                },
                child: const Text('تأكيد الدفع'),
              )
           ],
        );
     });
  }
}
