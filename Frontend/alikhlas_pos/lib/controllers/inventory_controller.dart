import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../core/utils/toast_service.dart';

class InventoryController extends GetxController {
  final RxList<ProductModel> products = <ProductModel>[].obs;
  final RxList<String> categories = <String>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Next auto-generated barcode
  final RxString nextBarcode = ''.obs;
  final RxBool isBarcodeLoading = false.obs;

  // Filters
  final RxString searchQuery = ''.obs;
  final RxString selectedCategory = ''.obs;
  final RxBool showLowStockOnly = false.obs;

  // Pagination
  final RxInt currentPage = 1.obs;
  final RxInt totalCount = 0.obs;
  static const int pageSize = 50;

  @override
  void onInit() {
    super.onInit();
    fetchProducts();
    fetchCategories();
    fetchNextBarcode();
  }

  Future<void> fetchProducts({bool reset = false}) async {
    if (reset) {
      currentPage.value = 1;
      products.clear();
    }
    isLoading.value = true;
    errorMessage.value = '';

    try {
      String endpoint = 'products?page=${currentPage.value}&pageSize=$pageSize';
      if (searchQuery.value.isNotEmpty) endpoint += '&search=${Uri.encodeComponent(searchQuery.value)}';
      if (selectedCategory.value.isNotEmpty) endpoint += '&category=${Uri.encodeComponent(selectedCategory.value)}';
      if (showLowStockOnly.value) endpoint += '&lowStock=true';

      final data = await ApiService.get(endpoint);
      totalCount.value = (data['total'] as num? ?? 0).toInt();

      final list = (data['data'] as List<dynamic>? ?? [])
          .map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
          .toList();

      if (reset || currentPage.value == 1) {
        products.assignAll(list);
      } else {
        products.addAll(list);
      }
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'خطأ في الاتصال بالخادم';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchCategories() async {
    try {
      final list = await ApiService.getList('products/categories');
      categories.assignAll(list.cast<String>());
    } catch (_) {}
  }

  /// Fetches the next auto-generated barcode (200-YYYY-NNNNN)
  Future<void> fetchNextBarcode() async {
    isBarcodeLoading.value = true;
    try {
      final data = await ApiService.get('products/next-barcode');
      nextBarcode.value = data['barcode'] as String? ?? '';
    } catch (_) {
      nextBarcode.value = '';
    } finally {
      isBarcodeLoading.value = false;
    }
  }

  Future<bool> addProduct(Map<String, dynamic> productData, BuildContext context) async {
    if (isLoading.value) return false;
    isLoading.value = true;
    try {
      await ApiService.post('products', productData);
      await fetchProducts(reset: true);
      await fetchCategories();
      await fetchNextBarcode();
      _snap(context, 'تم إضافة المنتج بنجاح ✅', Colors.green);
      return true;
    } on ApiException catch (e) {
      _snap(context, e.message, Colors.red);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Picks an image file and uploads it for the product, returning the imageUrl
  Future<String?> pickAndUploadImage(String productId, BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final filePath = result.files.single.path;
    if (filePath == null) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      final uri = Uri.parse('${dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5000/api'}/products/$productId/image');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        contentType: MediaType('image', filePath.split('.').last),
      ));

      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        _snap(context, 'تم رفع الصورة بنجاح 📷', Colors.green);
        await fetchProducts(reset: true);
        return body;
      } else {
        _snap(context, 'فشل رفع الصورة', Colors.red);
      }
    } catch (e) {
      _snap(context, 'خطأ في رفع الصورة', Colors.red);
    }
    return null;
  }

  Future<bool> updateProduct(String id, Map<String, dynamic> data, BuildContext context) async {
    isLoading.value = true;
    try {
      await ApiService.put('products/$id', data);
      await fetchProducts(reset: true);
      _snap(context, 'تم تحديث المنتج بنجاح', Colors.green);
      return true;
    } on ApiException catch (e) {
      _snap(context, e.message, Colors.red);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> deleteProduct(String id, BuildContext context) async {
    try {
      await ApiService.delete('products/$id');
      products.removeWhere((p) => p.id == id);
      _snap(context, 'تم حذف المنتج', Colors.orange);
      return true;
    } on ApiException catch (e) {
      _snap(context, e.message, Colors.red);
      return false;
    }
  }

  Future<bool> adjustStock(String id, double adjustment, String reason, BuildContext context) async {
    try {
      await ApiService.patch('products/$id/stock', {'adjustmentAmount': adjustment, 'reason': reason});
      await fetchProducts(reset: true);
      _snap(context, 'تم تعديل الرصيد بنجاح', Colors.green);
      return true;
    } on ApiException catch (e) {
      _snap(context, e.message, Colors.red);
      return false;
    }
  }

  void onSearchChanged(String query) {
    searchQuery.value = query;
    fetchProducts(reset: true);
  }

  List<ProductModel> get lowStockProducts => products.where((p) => p.isLowStock).toList();

  void _snap(BuildContext $1, String msg, Color color) {
    if (color == Colors.red || color == Colors.redAccent) { ToastService.showError(msg); }
    else if (color == Colors.green || color == Colors.greenAccent) { ToastService.showSuccess(msg); }
    else if (color == Colors.orange || color == Colors.orangeAccent) { ToastService.showWarning(msg); }
    else { ToastService.showInfo(msg); }
  }

}
