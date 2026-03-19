import 'package:get/get.dart';
import '../models/shift_model.dart';
import '../services/api_service.dart';
import 'package:flutter/material.dart';

class ShiftController extends GetxController {
  var isLoading = false.obs;
  var hasActiveShift = false.obs;
  var hasError = false.obs; // Tracks if the API check failed
  var currentShift = Rxn<Shift>();
  var shiftHistory = <Shift>[].obs;

  @override
  void onInit() {
    super.onInit();
    checkCurrentShift();
  }

  Future<void> retryCheckShift() async {
    hasError.value = false;
    await checkCurrentShift();
  }

  Future<void> checkCurrentShift() async {
    try {
      isLoading.value = true;
      hasError.value = false;
      final response = await ApiService.get('shifts/current');
      
      hasActiveShift.value = response['hasActiveShift'] ?? false;
      
      if (hasActiveShift.value && response['shift'] != null) {
        currentShift.value = Shift.fromJson(response['shift']);
      } else {
        currentShift.value = null;
      }
    } catch (e) {
      debugPrint('Error checking shift: $e');
      hasError.value = true; // Mark as error instead of assuming no shift!
      hasActiveShift.value = false;
      currentShift.value = null;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> openShift(double openingCash) async {
    try {
      isLoading.value = true;
      final response = await ApiService.post('shifts/open', {
        'openingCash': openingCash,
      });

      if (response['shift'] != null) {
        currentShift.value = Shift.fromJson(response['shift']);
        hasActiveShift.value = true;
        Get.snackbar('نجاح', 'تم فتح الوردية بنجاح', backgroundColor: Colors.green, colorText: Colors.white);
        return true;
      }
      return false;
    } catch (e) {
       Get.snackbar('خطأ', 'فشل فتح الوردية: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
       return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> closeShift(double actualCash, String? notes) async {
    try {
      isLoading.value = true;
      final response = await ApiService.post('shifts/close', {
        'actualCash': actualCash,
        'notes': notes ?? '',
      });

      if (response['shift'] != null) {
        // Shift closed
        currentShift.value = null;
        hasActiveShift.value = false;
        
        final closedShift = Shift.fromJson(response['shift']);
        // You could print the Z-Report here using the closedShift data
        
        Get.snackbar('تم الإقفال', 'تم إغلاق الوردية وإصدار تقرير Z', backgroundColor: Colors.green, colorText: Colors.white);
        return true;
      }
      return false;
    } catch (e) {
       Get.snackbar('خطأ', 'فشل إغلاق الوردية: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
       return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadShiftHistory({DateTime? from, DateTime? to}) async {
    try {
      isLoading.value = true;
      String query = '';
      if (from != null) query += '?fromDate=${from.toIso8601String()}';
      if (to != null) {
        query += query.isEmpty ? '?' : '&';
        query += 'toDate=${to.toIso8601String()}';
      }

      final response = await ApiService.get('shifts/history$query');
      shiftHistory.value = (response as List).map((json) => Shift.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
