import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import '../core/utils/toast_service.dart';

class ReturnsController extends GetxController {
  final RxBool isLoading = false.obs;
  
  // Return history
  final RxList<Map<String, dynamic>> returnHistory = <Map<String, dynamic>>[].obs;
  final RxString searchHistoryQuery = ''.obs;

  // Search state
  final RxString invoiceNoQuery = ''.obs;
  final Rxn<Map<String, dynamic>> searchedInvoice = Rxn<Map<String, dynamic>>();

  // Return processing state
  // key: productId OR parentId_subId (for bundle components)
  final RxMap<String, int> returnQuantities = <String, int>{}.obs; 
  final RxMap<String, int> returnableQuantities = <String, int>{}.obs; 
  final RxMap<String, double> returnCustomPrices = <String, double>{}.obs; 
  final RxDouble customRefundAmount = 0.0.obs;
  final RxString returnReason = ''.obs;
  final RxBool returnToStock = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchReturnHistory();
  }

  Future<void> fetchReturnHistory() async {
    isLoading.value = true;
    try {
      String endpoint = 'returninvoices';
      if (searchHistoryQuery.value.isNotEmpty) {
        endpoint += '?search=${Uri.encodeComponent(searchHistoryQuery.value)}';
      }
      final data = await ApiService.getList(endpoint);
      returnHistory.assignAll(data.cast<Map<String, dynamic>>());
    } catch (_) {
      // handle error silently for history or show small toast
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> searchInvoice(String invoiceNo, BuildContext context) async {
    if (invoiceNo.trim().isEmpty) return;
    isLoading.value = true;
    searchedInvoice.value = null;
    returnQuantities.clear();
    returnableQuantities.clear();
    customRefundAmount.value = 0.0;
    
    try {
      final data = await ApiService.get('invoices/by-no/${Uri.encodeComponent(invoiceNo.trim())}');
      searchedInvoice.value = data as Map<String, dynamic>;
      
      // Initialize return quantities
      final items = data['items'] as List<dynamic>? ?? [];
      for (var item in items) {
        final String pid = item['productId'];
        returnQuantities[pid] = 0;
        final returnable = (item['returnableQuantity'] as num?)?.toInt() ?? 0;
        returnableQuantities[pid] = returnable;
        returnCustomPrices[pid] = (item['unitPrice'] as num).toDouble();

        final isBundle = item['isBundle'] == true;
        if (isBundle) {
          final bundleItems = item['bundleItems'] as List<dynamic>? ?? [];
          for (var bi in bundleItems) {
            final String subId = bi['subProductId'];
            final uniqueKey = '${pid}_$subId';
            returnQuantities[uniqueKey] = 0;
            
            final totalSub = (bi['totalSubQuantity'] as num?)?.toInt() ?? 0;
            final prevRet = (bi['previouslyReturned'] as num?)?.toInt() ?? 0;
            final subReturnable = totalSub - prevRet;
            
            returnableQuantities[uniqueKey] = subReturnable > 0 ? subReturnable : 0;
            returnCustomPrices[uniqueKey] = (bi['suggestedRefundPrice'] as num?)?.toDouble() ?? 0.0;
          }
        }
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

  void incrementReturnQty(String uniqueKey) {
    int maxQty = returnableQuantities[uniqueKey] ?? 0;
    int current = returnQuantities[uniqueKey] ?? 0;
    if (current < maxQty) {
      returnQuantities[uniqueKey] = current + 1;
      _calculateCustomRefund();
    }
  }

  void decrementReturnQty(String uniqueKey) {
    int current = returnQuantities[uniqueKey] ?? 0;
    if (current > 0) {
      returnQuantities[uniqueKey] = current - 1;
      _calculateCustomRefund();
    }
  }

  void updateCustomPrice(String uniqueKey, double newPrice) {
    returnCustomPrices[uniqueKey] = newPrice;
    _calculateCustomRefund();
  }

  void _calculateCustomRefund() {
    double refund = 0;
    for (var entry in returnQuantities.entries) {
      final key = entry.key;
      final qty = entry.value;
      if (qty > 0) {
        final price = returnCustomPrices[key] ?? 0.0;
        refund += (price * qty);
      }
    }
    customRefundAmount.value = refund;
  }

  Future<bool> processReturn(BuildContext context) async {
    if (searchedInvoice.value == null) return false;
    
    final itemsToReturn = returnQuantities.entries
        .where((e) => e.value > 0)
        .map((e) {
          final isBundlePart = e.key.contains('_');
          return {
            'productId': isBundlePart ? e.key.split('_')[1] : e.key,
            'quantity': e.value,
            'parentBundleId': isBundlePart ? e.key.split('_')[0] : null,
            'customUnitPrice': returnCustomPrices[e.key]
          };
        })
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
        'notes': returnReason.value.isEmpty ? 'استرجاع عام / عرض' : returnReason.value,
        'items': itemsToReturn
      };

      await ApiService.post('returninvoices', body);
      
      _snap(context, 'تم معالجة الاسترجاع بنجاح', Colors.green);
      searchedInvoice.value = null; // Clear forms
      returnQuantities.clear();
      returnableQuantities.clear();
      returnCustomPrices.clear();
      fetchReturnHistory(); // refresh history table
      return true;
    } on ApiException catch (e) {
      _snap(context, e.message, Colors.red);
      return false;
    } catch (_) {
      _snap(context, 'خطأ في الاتصال بالسيرفر', Colors.red);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  void _snap(BuildContext $1, String msg, Color color) {
    if (color == Colors.red || color == Colors.redAccent) { ToastService.showError(msg); }
    else if (color == Colors.green || color == Colors.greenAccent) { ToastService.showSuccess(msg); }
    else if (color == Colors.orange || color == Colors.orangeAccent) { ToastService.showWarning(msg); }
    else { ToastService.showInfo(msg); }
  }

}
