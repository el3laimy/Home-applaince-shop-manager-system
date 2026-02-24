import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';

class ReturnsController extends GetxController {
  final RxBool isLoading = false.obs;
  
  // Search state
  final RxString invoiceNoQuery = ''.obs;
  final Rxn<Map<String, dynamic>> searchedInvoice = Rxn<Map<String, dynamic>>();
  
  // Return processing state
  final RxMap<String, int> returnQuantities = <String, int>{}.obs; // productId -> returnQty
  final RxDouble customRefundAmount = 0.0.obs;
  final RxString returnReason = ''.obs;
  final RxBool returnToStock = true.obs;

  Future<void> searchInvoice(String invoiceNo, BuildContext context) async {
    if (invoiceNo.trim().isEmpty) return;
    isLoading.value = true;
    searchedInvoice.value = null;
    returnQuantities.clear();
    customRefundAmount.value = 0.0;
    
    try {
      final data = await ApiService.get('invoices/$invoiceNo');
      searchedInvoice.value = data as Map<String, dynamic>;
      
      // Initialize return quantities to 0
      final items = data['items'] as List<dynamic>? ?? [];
      for (var item in items) {
        returnQuantities[item['productId']] = 0;
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        _snap(context, 'لم يتم العثور على الفاتورة. تأكد من الرقم.', Colors.orange);
      } else {
        _snap(context, e.message, Colors.red);
      }
    } catch (_) {
      _snap(context, 'خطأ في الاتصال بالسيرفر', Colors.red);
    } finally {
      isLoading.value = false;
    }
  }

  void incrementReturnQty(String productId, int maxQty) {
    int current = returnQuantities[productId] ?? 0;
    if (current < maxQty) {
      returnQuantities[productId] = current + 1;
      _calculateCustomRefund();
    }
  }

  void decrementReturnQty(String productId) {
    int current = returnQuantities[productId] ?? 0;
    if (current > 0) {
      returnQuantities[productId] = current - 1;
      _calculateCustomRefund();
    }
  }

  void _calculateCustomRefund() {
    if (searchedInvoice.value == null) return;
    double refund = 0;
    final items = searchedInvoice.value!['items'] as List<dynamic>? ?? [];
    
    for (var item in items) {
      final pid = item['productId'];
      final price = (item['unitPrice'] as num).toDouble();
      final qtyToReturn = returnQuantities[pid] ?? 0;
      refund += (price * qtyToReturn);
    }
    customRefundAmount.value = refund;
  }

  Future<bool> processReturn(BuildContext context) async {
    if (searchedInvoice.value == null) return false;
    
    final itemsToReturn = returnQuantities.entries
        .where((e) => e.value > 0)
        .map((e) => {'productId': e.key, 'quantity': e.value})
        .toList();

    if (itemsToReturn.isEmpty) {
      _snap(context, 'يجب تحديد صنف واحد على الأقل للاسترجاع', Colors.orange);
      return false;
    }

    isLoading.value = true;
    try {
      final body = {
        'originalInvoiceId': searchedInvoice.value!['id'],
        'reason': 3, // mapped to Other enum
        'notes': returnReason.value.isEmpty ? 'استرجاع عام' : returnReason.value,
        'items': itemsToReturn
      };

      await ApiService.post('returninvoices', body);
      
      _snap(context, 'تم معالجة الاسترجاع بنجاح', Colors.green);
      searchedInvoice.value = null; // Clear forms
      returnQuantities.clear();
      return true;
    } on ApiException catch (e) {
      _snap(context, e.message, Colors.red);
      return false;
    } catch (_) {
      _snap(context, 'خطأ في الاتصال', Colors.red);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  void _snap(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
