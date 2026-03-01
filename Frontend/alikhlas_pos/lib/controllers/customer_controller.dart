import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/customer_model.dart';
import '../services/api_service.dart';
import '../core/utils/toast_service.dart';

class CustomerController extends GetxController {
  final RxList<CustomerModel> customers = <CustomerModel>[].obs;
  final Rx<CustomerModel?> selected = Rx<CustomerModel?>(null);
  final RxBool isLoading = false.obs;
  final RxList<Map<String, dynamic>> statement = <Map<String, dynamic>>[].obs;
  final RxDouble totalDue = 0.0.obs;
  final RxDouble totalPaid = 0.0.obs;

  @override
  void onInit() { super.onInit(); fetch(); }

  Future<void> fetch({String? search}) async {
    isLoading.value = true;
    try {
      final url = search != null && search.isNotEmpty ? 'customers?search=${Uri.encodeComponent(search)}' : 'customers';
      final data = await ApiService.getList(url);
      customers.assignAll(data.map((c) => CustomerModel.fromJson(c as Map<String, dynamic>)).toList());
    } catch (_) {} finally { isLoading.value = false; }
  }

  Future<void> selectCustomer(CustomerModel c) async {
    selected.value = c;
    isLoading.value = true;
    try {
      final data = await ApiService.get('customers/${c.id}/statement');
      totalDue.value = (data['totalDue'] as num? ?? 0).toDouble();
      totalPaid.value = (data['totalPaid'] as num? ?? 0).toDouble();
      statement.assignAll((data['invoices'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>());
    } catch (_) {} finally { isLoading.value = false; }
  }

  Future<bool> addCustomer(String name, String? phone, BuildContext ctx) async {
    try {
      await ApiService.post('customers', {'name': name, 'phone': phone});
      await fetch();
      _snap(ctx, 'تم إضافة العميل بنجاح', Colors.green);
      return true;
    } on ApiException catch (e) { _snap(ctx, e.message, Colors.red); return false; }
  }

  Future<bool> deleteCustomer(String id, BuildContext ctx) async {
    try {
      await ApiService.delete('customers/$id');
      customers.removeWhere((c) => c.id == id);
      if (selected.value?.id == id) selected.value = null;
      _snap(ctx, 'تم حذف العميل', Colors.orange);
      return true;
    } on ApiException catch (e) { _snap(ctx, e.message, Colors.red); return false; }
  }

  void _snap(BuildContext $1, String msg, Color color) {
    if (color == Colors.red || color == Colors.redAccent) { ToastService.showError(msg); }
    else if (color == Colors.green || color == Colors.greenAccent) { ToastService.showSuccess(msg); }
    else if (color == Colors.orange || color == Colors.orangeAccent) { ToastService.showWarning(msg); }
    else { ToastService.showInfo(msg); }
  }
}
