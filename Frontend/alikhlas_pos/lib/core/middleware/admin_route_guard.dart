// MISSING-06: Role-based Route Guard for admin-only pages
// Uses GetX GetMiddleware API correctly
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Middleware that redirects non-admin users away from admin-only routes.
/// Attach via: GetPage(name: '/settings', middlewares: [AdminRouteGuard()])
class AdminRouteGuard extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  GetPage? onPageCalled(GetPage? page) {
    final role = _cachedRole;
    if (page != null && _isAdminRoute(page.name)) {
      if (role != 'Admin' && role != 'Manager') {
        // Redirect non-admin users to POS screen
        Get.offAllNamed('/pos');
        return null;
      }
    }
    return page;
  }

  static String get _cachedRole => _roleCache ?? 'Cashier';
  static String? _roleCache;

  /// Call once after login to sync the role for sync access in middleware.
  static Future<void> cacheRole() async {
    final prefs = await SharedPreferences.getInstance();
    _roleCache = prefs.getString('user_role') ?? 'Cashier';
  }

  static bool _isAdminRoute(String? name) {
    const adminRoutes = ['/users', '/settings', '/reports', '/stock-adjustments'];
    return adminRoutes.any((r) => name?.startsWith(r) ?? false);
  }
}
