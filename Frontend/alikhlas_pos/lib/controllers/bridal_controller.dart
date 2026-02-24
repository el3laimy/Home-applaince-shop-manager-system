import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/installment_model.dart';
import '../models/customer_model.dart';
import '../models/invoice_model.dart';
import '../services/api_service.dart';

class BridalController extends GetxController {
  final RxList<CustomerModel> bridalCustomers = <CustomerModel>[].obs;
  final RxList<InvoiceModel> selectedCustomerInvoices = <InvoiceModel>[].obs;
  final RxList<InstallmentModel> selectedCustomerInstallments = <InstallmentModel>[].obs;
  final Rx<CustomerModel?> selectedCustomer = Rx<CustomerModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;

  double get totalDue => selectedCustomerInvoices.fold(0, (s, i) => s + i.totalAmount);
  double get totalPaid => selectedCustomerInstallments.where((i) => i.isPaid).fold(0, (s, i) => s + i.amount);
  double get remainingBalance => totalDue - totalPaid;
  double get completionPct => totalDue > 0 ? (totalPaid / totalDue * 100).clamp(0, 100) : 0;

  @override
  void onInit() {
    super.onInit();
    fetchBridalCustomers();
  }

  Future<void> fetchBridalCustomers() async {
    isLoading.value = true;
    try {
      final data = await ApiService.get('customers${searchQuery.value.isNotEmpty ? "?search=${Uri.encodeComponent(searchQuery.value)}" : ""}');
      final rawList = data['data'] as List<dynamic>? ?? <dynamic>[];
      final list = rawList.map((c) => CustomerModel.fromJson(c as Map<String, dynamic>)).toList();
      bridalCustomers.assignAll(list);
    } catch (_) {} finally {
      isLoading.value = false;
    }
  }

  Future<void> selectCustomer(CustomerModel customer) async {
    selectedCustomer.value = customer;
    isLoading.value = true;
    try {
      final data = await ApiService.get('customers/${customer.id}/statement');
      selectedCustomerInvoices.assignAll(
        (data['invoices'] as List<dynamic>? ?? []).map((i) => InvoiceModel.fromJson(i as Map<String, dynamic>)).toList()
      );
      selectedCustomerInstallments.assignAll(
        (data['installments'] as List<dynamic>? ?? []).map((i) => InstallmentModel.fromJson(i as Map<String, dynamic>)).toList()
      );
    } catch (_) {} finally {
      isLoading.value = false;
    }
  }

  Future<bool> addPayment(String invoiceId, double amount, BuildContext context) async {
    try {
      await ApiService.post('installments', {'invoiceId': invoiceId, 'amount': amount, 'isPaid': true});
      if (selectedCustomer.value != null) await selectCustomer(selectedCustomer.value!);
      _snap(context, 'تم تسجيل الدفعة بنجاح', Colors.green);
      return true;
    } on ApiException catch (e) {
      _snap(context, e.message, Colors.red);
      return false;
    }
  }

  Future<bool> createBridalCustomer(String name, String? phone, BuildContext context) async {
    try {
      await ApiService.post('customers', {'name': name, 'phone': phone});
      await fetchBridalCustomers();
      _snap(context, 'تم فتح ملف العروسة بنجاح', Colors.green);
      return true;
    } on ApiException catch (e) {
      _snap(context, e.message, Colors.red);
      return false;
    }
  }

  void _snap(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating,
    ));
  }
}
