import 'package:get/get.dart';
import '../services/api_service.dart';
import 'package:flutter/material.dart';

class ExpensesController extends GetxController {
  final _expenses = <dynamic>[].obs;
  final _categories = <dynamic>[].obs;
  final _isLoading = false.obs;

  List<dynamic> get expenses => _expenses;
  List<dynamic> get categories => _categories;
  bool get isLoading => _isLoading.value;

  DateTime? filterStartDate;
  DateTime? filterEndDate;
  String? filterCategory;

  @override
  void onInit() {
    super.onInit();
    fetchCategories();
    fetchExpenses();
  }

  Future<void> fetchCategories() async {
    try {
      final response = await ApiService.get('ExpenseCategories');
      _categories.assignAll(response as List);
    } catch (e) {
    } catch (e) {
      debugPrint('Error fetching expense categories: $e');
    }
  }

  Future<void> fetchExpenses() async {
    _isLoading.value = true;
    
    // تأكد من جلب التصنيفات دائماً عند التحديث في حال فشلت المرة الأولى
    if (_categories.isEmpty) {
      await fetchCategories();
    }
    
    try {
      String query = '';
      if (filterStartDate != null) {
        query += '?startDate=${filterStartDate!.toIso8601String()}';
      }
      if (filterEndDate != null) {
        query += '${query.isEmpty ? '?' : '&'}endDate=${filterEndDate!.toIso8601String()}';
      }
      if (filterCategory != null && filterCategory!.isNotEmpty && filterCategory != 'الكل') {
        query += '${query.isEmpty ? '?' : '&'}categoryId=$filterCategory';
      }

      final response = await ApiService.get('expenses$query');
      _expenses.assignAll(response as List);
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في جلب المصروفات',
          backgroundColor: Colors.red.withAlpha(200), colorText: Colors.white);
      debugPrint('Error fetching expenses: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<bool> createExpense(double amount, String categoryId, String? description, {String? localReceiptPath}) async {
    try {
      String? serverReceiptPath;
      if (localReceiptPath != null && localReceiptPath.isNotEmpty) {
        _isLoading.value = true;
        try {
          final uploadRes = await ApiService.uploadFile('expenses/upload-receipt', localReceiptPath);
          serverReceiptPath = uploadRes['path'];
        } catch (e) {
          Get.snackbar('تحذير', 'فشل في رفع صورة الإيصال، سيتم تسجيل المصروف بدونه',
              backgroundColor: Colors.orange.withAlpha(200), colorText: Colors.white);
        }
      }

      final response = await ApiService.post('expenses', {
        'amount': amount,
        'categoryId': categoryId,
        'description': description ?? '',
        if (serverReceiptPath != null) 'receiptImagePath': serverReceiptPath,
      });
      _expenses.insert(0, response); // Add to top of list
      Get.snackbar('نجاح', 'تم تسجيل المصروف بنجاح',
          backgroundColor: Colors.green.withAlpha(200), colorText: Colors.white);
      return true;
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في تسجيل المصروف',
          backgroundColor: Colors.red.withAlpha(200), colorText: Colors.white);
      debugPrint('Error creating expense: $e');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<bool> deleteExpense(String id) async {
    try {
      await ApiService.delete('expenses/$id');
      _expenses.removeWhere((e) => e['id'] == id);
      Get.snackbar('نجاح', 'تم حذف المصروف بنجاح',
          backgroundColor: Colors.green.withAlpha(200), colorText: Colors.white);
      return true;
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في حذف المصروف',
          backgroundColor: Colors.red.withAlpha(200), colorText: Colors.white);
      debugPrint('Error deleting expense: $e');
      return false;
    }
  }

  Future<bool> createCategory(String name) async {
    try {
      final response = await ApiService.post('ExpenseCategories', {'name': name});
      _categories.add(response);
      Get.snackbar('نجاح', 'تمت إضافة التصنيف بنجاح',
          backgroundColor: Colors.green.withAlpha(200), colorText: Colors.white);
      return true;
    } catch (e) {
      Get.snackbar('خطأ', 'فشل في إضافة التصنيف أو أنه موجود بالفعل',
          backgroundColor: Colors.red.withAlpha(200), colorText: Colors.white);
      debugPrint('Error creating category: $e');
      return false;
    }
  }
}
