import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/api_service.dart';
import '../models/product_model.dart';
import '../core/utils/toast_service.dart';

class StockAdjustmentController extends GetxController {
  final RxList<dynamic> adjustments = <dynamic>[].obs;
  final RxList<ProductModel> searchResults = <ProductModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSearching = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAdjustments();
  }

  Future<void> fetchAdjustments() async {
    isLoading.value = true;
    try {
      final response = await ApiService.get('erp/stockadjustments');
      adjustments.assignAll(response as List);
    } catch (e) {
      if (e is ApiException) {
        ToastService.showError(e.message);
      } else {
        ToastService.showError('تعذر جلب التسويات');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> searchProducts(String query) async {
    isSearching.value = true;
    try {
      final response = await ApiService.get('products/search?query=$query');
      searchResults.assignAll((response as List).map((x) => ProductModel.fromJson(x)).toList());
    } catch (_) {
      searchResults.clear();
    } finally {
      isSearching.value = false;
    }
  }

  Future<bool> createAdjustment(String productId, int type, int qty, String reason) async {
    isLoading.value = true;
    try {
      final body = {
        'productId': productId,
        'type': type,
        'quantityAdjusted': qty,
        'reason': reason
      };
      await ApiService.post('erp/stockadjustments', body);
      await fetchAdjustments();
      ToastService.showSuccess('تم تسجيل التسوية بنجاح');
      return true;
    } catch (e) {
      if (e is ApiException) {
        ToastService.showError(e.message);
      } else {
        ToastService.showError('تعذر تسجيل التسوية');
      }
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
