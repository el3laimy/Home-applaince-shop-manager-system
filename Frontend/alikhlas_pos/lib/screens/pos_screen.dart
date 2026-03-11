import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/pos_controller.dart';
import '../controllers/shift_controller.dart';
import '../controllers/notifications_controller.dart';
import '../models/invoice_model.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/z_report_dialog.dart';
import '../core/widgets/pos_header.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../services/receipt_service.dart';
import '../core/theme/design_tokens.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class _OpenShiftOverlay extends StatefulWidget {
  final ShiftController shiftCtrl;
  const _OpenShiftOverlay({required this.shiftCtrl});

  @override
  State<_OpenShiftOverlay> createState() => _OpenShiftOverlayState();
}

class _OpenShiftOverlayState extends State<_OpenShiftOverlay> {
  final TextEditingController _cashCtrl = TextEditingController();

  void _submit() async {
    final amount = double.tryParse(_cashCtrl.text) ?? 0.0;
    if (amount < 0) {
      Get.snackbar('تنبيه', 'الرجاء إدخال مبلغ صحيح', backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    
    await widget.shiftCtrl.openShift(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.primaryColor.withAlpha(20), shape: BoxShape.circle),
            child: Icon(Icons.point_of_sale_rounded, color: AppTheme.primaryColor, size: 48),
          ),
          const SizedBox(height: 16),
          Text('فتح وردية جديدة', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('يرجى إدخال عهدة الدرج المبدئية لبدء المبيعات', style: TextStyle(color: Colors.grey[500]), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          TextField(
            controller: _cashCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            decoration: InputDecoration(
              labelText: 'مبلغ الدرج الفعلي (الافتتاحي)',
              prefixIcon: const Icon(Icons.attach_money_rounded),
              suffixText: 'ج.م',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Obx(() => ElevatedButton(
              onPressed: widget.shiftCtrl.isLoading.value ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: widget.shiftCtrl.isLoading.value 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('فتح الوردية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            )),
          )
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }
}


class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final PosController _ctrl = Get.put(PosController());
  final TextEditingController _barcodeController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_barcodeFocusNode);
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  void _scanBarcode(String value) {
    if (value.trim().isEmpty) return;
    _ctrl.onBarcodeScanned(value.trim());
    _barcodeController.clear();
    FocusScope.of(context).requestFocus(_barcodeFocusNode);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shiftCtrl = Get.put(ShiftController());

    return Obx(() {
      if (shiftCtrl.isLoading.value && !shiftCtrl.hasActiveShift.value && shiftCtrl.currentShift.value == null) {
        return const Center(child: CircularProgressIndicator());
      }

      final posContent = Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            // F12 = confirm checkout (Pay)
            if (event.logicalKey == LogicalKeyboardKey.f12) {
              if (_ctrl.cartItems.isNotEmpty) _ctrl.confirmCheckout();
              return KeyEventResult.handled;
            }
            // F2 = Focus barcode scanner (Search)
            if (event.logicalKey == LogicalKeyboardKey.f2) {
              FocusScope.of(context).requestFocus(_barcodeFocusNode);
              return KeyEventResult.handled;
            }
            // F4 = Discount
            if (event.logicalKey == LogicalKeyboardKey.f4) {
              if (_ctrl.cartItems.isNotEmpty) _showDiscountDialog();
              return KeyEventResult.handled;
            }
            // Escape = clear cart
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              if (_ctrl.cartItems.isNotEmpty) _showClearCartDialog();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          body: Column(
            children: [
              PosHeader(
                searchController: _barcodeController,
                onSettingsPressed: () => Get.toNamed('/settings'),
                onNotificationsPressed: () => _showNotificationsOverlay(context),
                onBarcodeSubmitted: _scanBarcode,
                isLoading: _ctrl.isLoading.value,
                errorMessage: _ctrl.errorMessage.value,
                lastScannedProduct: _ctrl.lastScannedProduct.value,
              ),
              Expanded(
                child: Row(
                  children: [
                    // ===== LEFT: Cart Panel =====
                    Expanded(
                      flex: 3,
                      child: _buildCartPanel(isDark),
                    ),
                    // ===== RIGHT: Product Grid =====
                    Expanded(
                      flex: 5,
                      child: _buildProductPanel(isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      if (!shiftCtrl.hasActiveShift.value) {
        return Stack(
          children: [
            // Blurred background
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: IgnorePointer(child: posContent),
            ),
            // Overlay Dialog
            Container(color: Colors.black54),
            Center(
              child: _OpenShiftOverlay(shiftCtrl: shiftCtrl),
            ),
          ],
        );
      }

      return posContent;
    });
  }

  Widget _buildCartPanel(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Cart Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'سلة المشتريات',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                TextButton.icon(
                  onPressed: _showClearCartDialog,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.redAccent),
                  label: const Text('مسح', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              ],
            ),
          ),

          // UX-02: Visual badge confirming product was added
          Obx(() {
            final name = _ctrl.lastAddedProductName.value;
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: name.isEmpty
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(name),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27AE60).withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF27AE60).withAlpha(80)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline,
                            color: Color(0xFF27AE60), size: 16),
                        const SizedBox(width: 8),
                        Flexible(child: Text(
                          '✓ $name — أُضيف للسلة',
                          style: const TextStyle(
                            color: Color(0xFF27AE60),
                            fontWeight: FontWeight.bold, fontSize: 12),
                        )),
                      ]),
                    ),
            );
          }),

          // Customer Selection
          const _CustomerSelector(),

          // Cart Items List
          Expanded(
            child: Obx(() {
               if (_ctrl.cartItems.isEmpty) {
                return _buildEmptyCart(isDark);
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _ctrl.cartItems.length,
                itemBuilder: (context, index) {
                  return _CartItemCard(
                    item: _ctrl.cartItems[index],
                    index: index,
                    onEditPrice: () => _showEditPriceDialog(index, _ctrl.cartItems[index]),
                  );
                },
              );
            }),
          ),

          // Summary & Checkout
          _buildCartSummary(isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'سلة المشتريات فارغة',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary(bool isDark) {
    return Obx(() {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(5) : Colors.grey[50],
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          border: Border(top: BorderSide(color: isDark ? Colors.white.withAlpha(10) : Colors.grey[200]!)),
        ),
        child: Column(
          children: [
            _buildSummaryRow('المجموع الفرعي', _ctrl.subtotal),
            // BUG-01/02: Use real VAT from API (not hardcoded 15%)
            if (_ctrl.vatAmount.value > 0)
              _buildSummaryRow(
                'ضريبة (${_ctrl.vatRate.value.toStringAsFixed(0)}٪)',
                _ctrl.vatAmount.value,
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الخصم', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                TextButton(
                  onPressed: _showDiscountDialog,
                  child: Text(
                     _ctrl.globalDiscount.value > 0 
                      ? '- ${_ctrl.globalDiscount.value.toStringAsFixed(2)} ج.م' 
                      : 'إضافة خصم',
                    style: TextStyle(color: _ctrl.globalDiscount.value > 0 ? Colors.redAccent : AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                // BUG-01: Use ج.م consistently
                Text(
                  '${_ctrl.total.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: AppTheme.primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // ── Print & Utility Actions ──────────────────────────────
            Obx(() => Row(
              children: [
                if (_ctrl.hasLastReceipt) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _ctrl.reprintLastReceipt();
                        if (mounted) {
                          Get.snackbar('طباعة', 'تم إرسال الفاتورة ${_ctrl.lastInvoiceNo.value ?? ''} للطابعة',
                            backgroundColor: Colors.green.withAlpha(200), colorText: Colors.white,
                            snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
                        }
                      },
                      icon: Icon(Icons.receipt_long_rounded, size: 16, color: DesignTokens.neonCyan),
                      label: Text('إعادة طباعة', style: TextStyle(fontSize: 11, color: DesignTokens.neonCyan)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: DesignTokens.neonCyan.withAlpha(80)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _ctrl.cartItems.isEmpty ? null : _showClearCartDialog,
                    icon: Icon(Icons.remove_shopping_cart_rounded, size: 16, color: _ctrl.cartItems.isEmpty ? Colors.grey : DesignTokens.neonRed),
                    label: Text('مسح السلة', style: TextStyle(fontSize: 11, color: _ctrl.cartItems.isEmpty ? Colors.grey : DesignTokens.neonRed)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: (_ctrl.cartItems.isEmpty ? Colors.grey : DesignTokens.neonRed).withAlpha(80)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ReceiptService.printTestPage(),
                    icon: Icon(Icons.print_rounded, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    label: Text('طباعة تجريبية', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: (isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CheckoutButton(
                    label: 'دفع نقدي',
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF27AE60),
                    onPressed: () => _ctrl.confirmCheckout(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CheckoutButton(
                    label: 'خطة تقسيط',
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppTheme.primaryColor,
                    // BUG-06: Open installment dialog
                    onPressed: _ctrl.cartItems.isEmpty ? null : () => _showInstallmentDialog(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CheckoutButton(
                    label: 'دفع بالفيزا',
                    icon: Icons.credit_card_outlined,
                    color: const Color(0xFF2980B9),
                    onPressed: () {
                      _ctrl.selectedPaymentType.value = PaymentType.visa;
                      _showPaymentReferenceDialog('دفع بالفيزا');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CheckoutButton(
                    label: 'تحويل بنكي',
                    icon: Icons.account_balance_outlined,
                    color: const Color(0xFF8E44AD),
                    onPressed: () {
                      _ctrl.selectedPaymentType.value = PaymentType.bankTransfer;
                      _showPaymentReferenceDialog('تحويل بنكي');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _CheckoutButton(
                    label: 'دفع مقسم',
                    icon: Icons.pie_chart_outline,
                    color: Colors.orange.shade700,
                    onPressed: () {
                      _ctrl.selectedPaymentType.value = PaymentType.cash; // Defaults to cash as base
                      _showSplitPaymentDialog();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSummaryRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          // BUG-01: Use ج.م
          Text('${value.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildProductPanel(bool isDark) {
    return Column(
      children: [
        // Category Selector
        Container(
          height: 100,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Obx(() {
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _ctrl.categories.length,
              itemBuilder: (context, index) {
                final cat = _ctrl.categories[index];
                final isSelected = _ctrl.selectedCategory.value == cat;
                return _CategoryChip(
                  label: cat.isEmpty ? 'الكل' : cat,
                  icon: _getCategoryIcon(cat),
                  isSelected: isSelected,
                  onSelected: () => _ctrl.onCategorySelected(cat),
                );
              },
            );
          }),
        ),

        // Product Grid
        Expanded(
          child: Obx(() {
            if (_ctrl.isLoadingProducts.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_ctrl.quickAccessProducts.isEmpty) {
              return _buildEmptyProducts();
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _ctrl.quickAccessProducts.length,
              itemBuilder: (context, index) {
                return _ProductCard(
                  product: _ctrl.quickAccessProducts[index],
                  onTap: () => _ctrl.addProductToCart(_ctrl.quickAccessProducts[index]),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEmptyProducts() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('لا يوجد منتجات في هذا التصنيف'),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    return switch (cat) {
      'ثلاجات' => Icons.kitchen_outlined,
      'غسالات' => Icons.local_laundry_service_outlined,
      'مكيفات' => Icons.ac_unit_outlined,
      'أفران' => Icons.flatware_outlined,
      'شاشات' => Icons.tv_outlined,
       _ => Icons.category_outlined,
    };
  }

  // Helper Dialogs
  void _showDiscountDialog() {
    final TextEditingController dCtrl = TextEditingController(text: _ctrl.globalDiscount.value > 0 ? _ctrl.globalDiscount.value.toStringAsFixed(2) : '');
    Get.dialog(
      AlertDialog(
        title: const Text('خصم الفاتورة'),
        content: TextField(
          controller: dCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'مبلغ الخصم (ج.م)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              // BUG-09: Validate discount does not exceed subtotal
              final discountVal = double.tryParse(dCtrl.text) ?? 0.0;
              if (discountVal > _ctrl.subtotal) {
                Get.snackbar('تنبيه', 'الخصم لا يمكن أن يتجاوز المجموع الفرعي (${_ctrl.subtotal.toStringAsFixed(2)} ج.م)',
                    backgroundColor: Colors.orange, colorText: Colors.white);
                return;
              }
              _ctrl.globalDiscount.value = discountVal;
              Get.back();
              // UX-03: Restore barcode focus
              FocusScope.of(context).requestFocus(_barcodeFocusNode);
            },
            child: const Text('تطبيق الخصم'),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('تفريغ السلة'),
        content: const Text('هل أنت متأكد من مسح جميع المنتجات من السلة؟'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              _ctrl.clearCart();
              Get.back();
              // UX-03: Restore barcode focus
              FocusScope.of(context).requestFocus(_barcodeFocusNode);
            },
            child: const Text('مسح الكل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditPriceDialog(int index, CartItemModel item) {
    final TextEditingController pCtrl = TextEditingController(text: (item.customPrice ?? item.unitPrice).toString());
    Get.dialog(
      AlertDialog(
        title: const Text('تعديل سعر الصنف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: pCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر الجديد (ج.م)'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () {
            _ctrl.updateCustomPrice(index, null); // Reset to original price
            Get.back();
          }, child: const Text('استعادة السعر الأصلي')),
          const Spacer(),
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              _ctrl.updateCustomPrice(index, double.tryParse(pCtrl.text));
              Get.back();
            },
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }

  void _showNotificationsOverlay(BuildContext context) {
    showDialog(context: context, builder: (_) => ZReportDialog(shiftCtrl: Get.find<ShiftController>()));
  }

  // حاسبة التقسيط المتطورة: فائدة + نوع القسط + حساب تلقائي
  void _showInstallmentDialog() {
    if (_ctrl.selectedCustomerId.value == null) {
      Get.snackbar('تنبيه', 'يجب اختيار عميل أولاً لإنشاء خطة تقسيط',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }
    final downCtrl = TextEditingController();
    final interestCtrl = TextEditingController(text: '10');
    final installmentsCtrl = TextEditingController(text: '6');
    int selectedPeriod = 0; // 0=شهري 1=ربع 2=نصف 3=سنوي
    final periodLabels = ['شهري', 'ربع سنوي', 'نصف سنوي', 'سنوي'];

    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setState) {
          final down = double.tryParse(downCtrl.text) ?? 0.0;
          final interestRate = double.tryParse(interestCtrl.text) ?? 0.0;
          final installmentCount = int.tryParse(installmentsCtrl.text) ?? 0;
          final total = _ctrl.total;
          final remaining = (total - down).clamp(0.0, double.infinity);
          final interest = remaining * (interestRate / 100);
          final totalWithInterest = remaining + interest;
          final perInstallment = installmentCount > 0 ? totalWithInterest / installmentCount : 0.0;

          return AlertDialog(
            title: const Row(children: [
              Icon(Icons.calculate, color: Colors.deepPurple, size: 22),
              SizedBox(width: 8),
              Text('حاسبة التقسيط', style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Total
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.deepPurple.withAlpha(40)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('إجمالي الفاتورة', style: TextStyle(color: Colors.grey)),
                      Text('${total.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  // Down payment
                  TextField(
                    controller: downCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'العربون / الدفعة المقدمة (ج.م)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Interest rate
                  TextField(
                    controller: interestCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'نسبة الفائدة على المتبقي (%)',
                      prefixIcon: Icon(Icons.percent),
                      suffixText: '%',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Period selector
                  Align(alignment: Alignment.centerRight,
                    child: Text('نوع القسط', style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, children: List.generate(4, (i) => FilterChip(
                    label: Text(periodLabels[i]),
                    selected: selectedPeriod == i,
                    selectedColor: Colors.deepPurple.withAlpha(40),
                    onSelected: (_) => setState(() => selectedPeriod = i),
                  ))),
                  const SizedBox(height: 12),
                  // Number of installments
                  TextField(
                    controller: installmentsCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'عدد الأقساط',
                      prefixIcon: const Icon(Icons.format_list_numbered),
                      helperText: 'مثال: 12 قسط ${periodLabels[selectedPeriod]}',
                    ),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                onPressed: () async {
                  final down = double.tryParse(downCtrl.text) ?? 0.0;
                  final months = int.tryParse(installmentsCtrl.text) ?? 0;
                  final rate = double.tryParse(interestCtrl.text) ?? 0.0;
                  if (months <= 0) {
                    Get.snackbar('خطأ', 'أدخل عدد أقساط صحيح', backgroundColor: Colors.red, colorText: Colors.white);
                    return;
                  }
                  if (down >= _ctrl.total) {
                    Get.snackbar('خطأ', 'المقدم لا يمكن أن يساوي أو يتجاوز الإجمالي',
                        backgroundColor: Colors.red, colorText: Colors.white);
                    return;
                  }
                  Get.back();
                  _ctrl.selectedPaymentType.value = PaymentType.installment;
                  await _ctrl.confirmCheckout(
                    downPayment: down,
                    numberOfMonths: months,
                    interestRate: rate,
                    installmentPeriod: selectedPeriod,
                    firstInstallmentDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  FocusScope.of(context).requestFocus(_barcodeFocusNode);
                },
                child: const Text('تأكيد وإصدار الفاتورة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPaymentReferenceDialog(String title) {
    if (_ctrl.cartItems.isEmpty) return;
    final refCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('برجاء إدخال رقم العملية (المرجع) للتوثيق المحاسبي:'),
            const SizedBox(height: 12),
            TextField(
              controller: refCtrl,
              decoration: const InputDecoration(labelText: 'رقم العملية (اختياري)', prefixIcon: Icon(Icons.receipt_long)),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _ctrl.confirmCheckout(paymentReference: refCtrl.text);
            },
            child: const Text('تأكيد الدفع'),
          ),
        ],
      ),
    );
  }

  void _showSplitPaymentDialog() {
    if (_ctrl.cartItems.isEmpty) return;
    final cashCtrl = TextEditingController(text: _ctrl.total.toStringAsFixed(2));
    final visaCtrl = TextEditingController(text: '0.00');

    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.pie_chart_outline, color: Colors.orange),
                SizedBox(width: 8),
                Text('دفع مقسم (كاش + فيزا)'),
              ],
            ),
            content: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المبلغ الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_ctrl.total.toStringAsFixed(2)} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: cashCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'مبلغ الكاش (ج.م)', prefixIcon: Icon(Icons.money)),
                    onChanged: (val) {
                      final cash = double.tryParse(val) ?? 0.0;
                      final visa = (_ctrl.total - cash).clamp(0.0, _ctrl.total);
                      visaCtrl.text = visa.toStringAsFixed(2);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: visaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'مبلغ الفيزا (ج.م)', prefixIcon: Icon(Icons.credit_card)),
                    onChanged: (val) {
                      final visa = double.tryParse(val) ?? 0.0;
                      final cash = (_ctrl.total - visa).clamp(0.0, _ctrl.total);
                      cashCtrl.text = cash.toStringAsFixed(2);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                onPressed: () {
                  final cash = double.tryParse(cashCtrl.text) ?? 0.0;
                  final visa = double.tryParse(visaCtrl.text) ?? 0.0;
                  
                  // Allow a small epsilon for floating point issues
                  if ((cash + visa - _ctrl.total).abs() > 0.1) {
                    Get.snackbar('خطأ', 'مجموع المبلغين يجب أن يساوي الفاتورة', backgroundColor: Colors.red, colorText: Colors.white);
                    return;
                  }

                  Get.back();
                  _ctrl.confirmCheckout(splitCashAmount: cash, splitVisaAmount: visa);
                  FocusScope.of(context).requestFocus(_barcodeFocusNode);
                },
                child: const Text('تأكيد الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _installCalcRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        Text(value, style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          fontSize: bold ? 14 : 12,
          color: color,
        )),
      ]),
    );
  }
} // end of _PosScreenState

// ───── Private Sub-Widgets ─────

// BUG-04: Customer selector with real search dialog
class _CustomerSelector extends StatelessWidget {
  const _CustomerSelector();

  Future<void> _showPickerDialog(BuildContext context, PosController ctrl) async {
    final searchCtrl = TextEditingController();
    final RxList<Map<String, dynamic>> results = <Map<String, dynamic>>[].obs;
    final RxBool searching = false.obs;

    Future<void> search(String q) async {
      searching.value = true;
      try {
        final url = q.isNotEmpty ? 'customers?search=${Uri.encodeComponent(q)}' : 'customers?pageSize=20';
        final data = await ApiService.get(url);
        final list = (data is Map && data['data'] != null)
            ? (data['data'] as List).cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];
        results.assignAll(list);
      } catch (_) {
        results.clear();
      } finally {
        searching.value = false;
      }
    }

    await search('');

    await Get.dialog(
      AlertDialog(
        title: const Text('اختر عميلاً', style: TextStyle(fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        content: SizedBox(
          width: 420,
          height: 400,
          child: Column(
            children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'بحث بالاسم أو الهاتف',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => search(v),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Obx(() {
                  if (searching.value) return const Center(child: CircularProgressIndicator());
                  if (results.isEmpty) {
                    return const Center(child: Text('لا يوجد عملاء', style: TextStyle(color: Colors.grey)));
                  }
                  return ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = results[i];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
                        title: Text(c['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: c['phone'] != null ? Text(c['phone'] as String) : null,
                        onTap: () {
                          ctrl.selectedCustomerId.value = c['id'] as String?;
                          ctrl.selectedCustomerName.value = c['name'] as String?;
                          Get.back();
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ctrl.selectedCustomerId.value = null;
              ctrl.selectedCustomerName.value = null;
              Get.back();
            },
            child: const Text('عميل مباشر', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<PosController>();
    return Obx(() {
      final hasCustomer = ctrl.selectedCustomerName.value != null;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasCustomer
              ? AppTheme.primaryColor.withAlpha(20)
              : AppTheme.primaryColor.withAlpha(10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasCustomer
                ? AppTheme.primaryColor.withAlpha(80)
                : AppTheme.primaryColor.withAlpha(30),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showPickerDialog(context, ctrl),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasCustomer ? AppTheme.primaryColor : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasCustomer ? Icons.person_rounded : Icons.person_outline,
                  color: hasCustomer ? Colors.white : AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ctrl.selectedCustomerName.value ?? 'عميل مباشر',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      hasCustomer ? 'اضغط لتغيير العميل' : 'اضغط لاختيار عميل',
                      style: TextStyle(color: AppTheme.primaryColor, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (hasCustomer)
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                  onPressed: () {
                    ctrl.selectedCustomerId.value = null;
                    ctrl.selectedCustomerName.value = null;
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else
                const Icon(Icons.chevron_left, color: AppTheme.primaryColor, size: 18),
            ],
          ),
        ),
      );
    });
  }
}


class _CartItemCard extends StatelessWidget {
  final CartItemModel item;
  final int index;
  final VoidCallback onEditPrice;

  const _CartItemCard({required this.item, required this.index, required this.onEditPrice});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<PosController>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product Name & Price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${item.effectivePrice.toStringAsFixed(2)} ج.م',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onEditPrice,
                        child: const Icon(Icons.edit_outlined, size: 14, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Quantity Controls
            Row(
              children: [
                _buildQtyBtn(Icons.remove, () => ctrl.updateQuantity(index, item.quantity - 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                _buildQtyBtn(Icons.add, () => ctrl.updateQuantity(index, item.quantity + 1)),
              ],
            ),

            const SizedBox(width: 12),

            // Total Price for item
            SizedBox(
              width: 80,
              child: Text(
                '${item.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onSelected;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: DesignTokens.kAnimDuration,
        margin: const EdgeInsets.only(left: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withAlpha(15) : Colors.black87)
              : (isDark ? DesignTokens.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(DesignTokens.kChipRadius),
          border: isSelected
              ? Border.all(color: DesignTokens.neonPurple.withAlpha(80))
              : Border.all(color: isDark ? Colors.white.withAlpha(10) : Colors.grey.withAlpha(20)),
          boxShadow: isSelected ? DesignTokens.glowShadow(DesignTokens.neonPurple, blur: 10) : [],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? (isDark ? DesignTokens.neonPurple : Colors.white) : Colors.grey[500], size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? (isDark ? Colors.white : Colors.white) : (isDark ? Colors.grey[400] : Colors.grey[700]),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageBaseUrl = (dotenv.env['API_BASE_URL'] ?? 'http://localhost:5290/api').replaceAll('/api', '');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? DesignTokens.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(DesignTokens.kCardRadius),
          border: Border.all(color: isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 8),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image & Badge
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.kCardRadius)),
                    child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? Image.network('$imageBaseUrl${product.imageUrl!}',
                            fit: BoxFit.cover, width: double.infinity,
                            errorBuilder: (_, __, ___) => _placeholder(isDark))
                        : _placeholder(isDark),
                  ),
                  if (product.isLowStock)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: DesignTokens.neonRed.withAlpha(200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('محدود',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            // Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    if (product.internalBarcode != null)
                      Text(product.internalBarcode!,
                          style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'monospace'),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      children: [
                        if (product.wholesalePrice > 0 && product.wholesalePrice != product.price)
                          Text('${product.wholesalePrice.toStringAsFixed(0)} ',
                              style: TextStyle(color: Colors.grey[500], fontSize: 10,
                                  decoration: TextDecoration.lineThrough, decorationColor: Colors.grey[500])),
                        Expanded(
                          child: Text('${product.price.toStringAsFixed(2)} ج.م',
                            style: TextStyle(fontWeight: FontWeight.bold,
                                color: isDark ? DesignTokens.neonCyan : AppTheme.primaryColor, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: DesignTokens.neonGreen.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add_rounded, color: DesignTokens.neonGreen, size: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(bool isDark) {
    return Container(
      color: isDark ? Colors.white.withAlpha(5) : Colors.grey[50],
      child: Center(child: Icon(Icons.image_outlined,
          color: isDark ? Colors.grey[700] : Colors.grey[300], size: 40)),
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  // Nullable to allow disabling (e.g. installment button when cart is empty)
  final VoidCallback? onPressed;

  const _CheckoutButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return color.withAlpha(200);
          return color;
        }),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
