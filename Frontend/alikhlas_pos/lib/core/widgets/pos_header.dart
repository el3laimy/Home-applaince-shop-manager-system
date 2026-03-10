import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/notifications_controller.dart';
import '../../models/product_model.dart';
import '../theme/app_theme.dart';

class PosHeader extends StatelessWidget {
  final TextEditingController searchController;
  final VoidCallback onSettingsPressed;
  final VoidCallback onNotificationsPressed;
  final Function(String) onBarcodeSubmitted;
  final bool isLoading;
  final String errorMessage;
  final ProductModel? lastScannedProduct;

  const PosHeader({
    super.key,
    required this.searchController,
    required this.onSettingsPressed,
    required this.onNotificationsPressed,
    required this.onBarcodeSubmitted,
    required this.isLoading,
    required this.errorMessage,
    this.lastScannedProduct,
  });

  @override
  Widget build(BuildContext context) {
    final authCtrl = Get.find<AuthController>();
    final notifCtrl = Get.find<NotificationsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authCtrl.currentUser.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                // User Profile
                _buildUserProfile(user, isDark),
                const SizedBox(width: 12),
                _buildActionButton(Icons.settings_outlined, onSettingsPressed, isDark),
                const SizedBox(width: 12),
                _buildNotificationButton(notifCtrl, onNotificationsPressed, isDark),

                const Spacer(),

                // Search Bar
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(10) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: searchController,
                      onSubmitted: onBarcodeSubmitted,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن منتج، باركود، أو رمز SKU...',
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                        prefixIcon: isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : Icon(Icons.search, color: Colors.grey[500], size: 20),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Title & Icon
                Row(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                         const Text(
                          'نقطة البيع بالتجزئة',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'الفرع الرئيسي - وسط المدينة',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ],
            ),
            
            // Scanner Feedback
            if (errorMessage.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold))),
                  ],
                ),
              ).animate().shake(),
              
            if (lastScannedProduct != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lastScannedProduct!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('تمت الإضافة بنجاح - ${lastScannedProduct!.price.toStringAsFixed(2)} ر.س', 
                            style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fade().slideY(begin: -0.2),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfile(user, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(5) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withAlpha(10) : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.fullName ?? 'كاشير',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'مدير المبيعات',
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor,
            child: Icon(Icons.person, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onPressed, bool isDark) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(5) : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white.withAlpha(10) : Colors.grey[200]!),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black87),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildNotificationButton(NotificationsController ctrl, VoidCallback onPressed, bool isDark) {
    return Obx(() {
      final count = ctrl.unreadCount.value;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          _buildActionButton(Icons.notifications_active_outlined, onPressed, isDark),
          if (count > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      );
    });
  }
}
