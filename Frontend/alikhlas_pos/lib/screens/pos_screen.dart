import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/pos_controller.dart';
import '../controllers/shift_controller.dart';
import '../models/invoice_model.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/widgets/z_report_dialog.dart';

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
              if (_ctrl.cartItems.isNotEmpty) _ctrl.confirmCheckout(context);
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
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0B0F19), const Color(0xFF1A1C29)]
                    : [Colors.grey.shade50, Colors.grey.shade200],
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // ===== LEFT: Cart Panel =====
                  Expanded(
                    flex: 3,
                    child: _buildCartPanel(isDark),
                  ),

                  // ===== RIGHT: Product Info + Quick Access =====
                  Expanded(
                    flex: 5,
                    child: _buildRightPanel(isDark),
                  ),
                ],
              ),
            ),
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
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 60 : 15), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Barcode Input
                _buildBarcodeInput(isDark),
                const SizedBox(height: 8),

                // Error message
                Obx(() => _ctrl.errorMessage.value.isNotEmpty
                    ? Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withAlpha(80)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_ctrl.errorMessage.value, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                          ],
                        ),
                      ).animate().shake()
                    : const SizedBox()),

                // Last scanned product
                Obx(() => _ctrl.lastScannedProduct.value != null
                    ? _buildLastScannedCard(_ctrl.lastScannedProduct.value!, isDark)
                    : const SizedBox()),

                const SizedBox(height: 8),

                // Cart list (Dynamic Table)
                Expanded(child: _buildCartTable(isDark)),

                const SizedBox(height: 12),

                // Checkout summary
                _buildCheckoutSummary(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarcodeInput(bool isDark) {
    return Obx(() => TextField(
      controller: _barcodeController,
      focusNode: _barcodeFocusNode,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: 'مسح الباركود (F2)',
        prefixIcon: _ctrl.isLoading.value
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryColor),
        filled: true,
        fillColor: isDark ? Colors.black.withAlpha(50) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.primaryColor.withAlpha(60)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
      onSubmitted: _scanBarcode,
    ));
  }

  Widget _buildLastScannedCard(dynamic product, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withAlpha(30),
            ),
            child: const Icon(Icons.check_circle, color: Colors.green, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('السعر: ${product.price.toStringAsFixed(2)} ج.م  |  الرصيد: ${product.stockQuantity.toStringAsFixed(0)} قطعة',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: -0.3);
  }

  Widget _buildCartTable(bool isDark) {
    return Obx(() {
      if (_ctrl.cartItems.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey.withAlpha(80)),
              const SizedBox(height: 16),
              Text('العربة فارغة\nامسح باركود لإضافة صنف', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.withAlpha(120), fontSize: 16)),
            ],
          ),
        ).animate().fade();
      }

      return Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(15) : Colors.grey[200],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Expanded(flex: 3, child: Text('الصنف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                const Expanded(flex: 2, child: Text('السعر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
                const Expanded(flex: 2, child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
                const Expanded(flex: 2, child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.end)),
              ],
            ),
          ),
          // Table Rows
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? Colors.white.withAlpha(15) : Colors.grey[300]!),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: ListView.separated(
                itemCount: _ctrl.cartItems.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.white.withAlpha(10) : Colors.grey[200]),
                itemBuilder: (context, index) {
                  final item = _ctrl.cartItems[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () => _showEditPriceDialog(index, item),
                            child: Tooltip(
                              message: 'تعديل السعر',
                              child: Text(
                                '${item.effectivePrice.toStringAsFixed(2)}', 
                                style: TextStyle(
                                  color: item.customPrice != null ? AppTheme.primaryColor : Colors.grey[600], 
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                  decorationStyle: TextDecorationStyle.dashed
                                ), 
                                textAlign: TextAlign.center
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () => _ctrl.updateQuantity(index, item.quantity - 1),
                                child: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.redAccent),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                              InkWell(
                                onTap: () => _ctrl.updateQuantity(index, item.quantity + 1),
                                child: Icon(Icons.add_circle_outline, size: 20, color: AppTheme.primaryColor),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('${item.totalPrice.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryColor, fontSize: 14), textAlign: TextAlign.end),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    });
  }

          // Checkout summary
          _buildCheckoutSummary(isDark),
        ],
      ),
    );
  }

  final TextEditingController _downPaymentCtrl = TextEditingController(text: '0');

  Widget _buildCheckoutSummary(bool isDark) {
    return Obx(() => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withAlpha(40), AppTheme.secondaryColor.withAlpha(40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withAlpha(60)),
      ),
      child: Column(
        children: [
          // Payment type selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPaymentChip('نقدي', PaymentType.cash, Icons.money, Colors.green),
              _buildPaymentChip('بطاقة', PaymentType.card, Icons.credit_card, Colors.blue),
              _buildPaymentChip('أقساط', PaymentType.installment, Icons.schedule, Colors.orange),
            ],
          ),
          const SizedBox(height: 16),

          if (_ctrl.selectedPaymentType.value == PaymentType.installment)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _downPaymentCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'المبلغ المقدم (Down Payment)',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  suffixText: 'ج.م',
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ).animate().fadeIn().slideY(begin: -0.1),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الأصناف: ${_ctrl.totalItems}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_ctrl.globalDiscount.value > 0)
                    Text('الخصم: ${_ctrl.globalDiscount.value.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  Text('الإجمالي:', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _showDiscountDialog(), 
                icon: const Icon(Icons.local_offer, size: 16), 
                label: const Text('خصم (F4)'),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
              ),
              Text(
                '${_ctrl.total.toStringAsFixed(2)} ج.م',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Checkout button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _ctrl.cartItems.isEmpty || _ctrl.isLoading.value
                  ? null
                  : () async {
                      final downPayment = double.tryParse(_downPaymentCtrl.text) ?? 0.0;
                      final success = await _ctrl.confirmCheckout(context, downPayment: downPayment);
                      if (success && _ctrl.selectedPaymentType.value == PaymentType.installment) {
                         // TODO: Auto-trigger installment scheduling UI if needed
                         _downPaymentCtrl.text = '0';
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: AppTheme.primaryColor.withAlpha(100),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _ctrl.isLoading.value
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment_rounded, size: 24),
                        SizedBox(width: 10),
                        Text('تأكيد الدفع (F12)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.2));
  }

  Widget _buildPaymentChip(String label, PaymentType type, IconData icon, Color color) {
    return Obx(() {
      final isSelected = _ctrl.selectedPaymentType.value == type;
      return GestureDetector(
        onTap: () => _ctrl.selectedPaymentType.value = type,
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withAlpha(40) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? color : Colors.grey.withAlpha(80)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: isSelected ? color : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildRightPanel(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header + Search ──
          Row(
            children: [
              Expanded(
                child: Text(
                  'المنتجات',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ).animate().fadeIn(delay: 100.ms),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _ctrl.loadQuickAccessProducts(category: _ctrl.selectedCategory.value.isEmpty ? null : _ctrl.selectedCategory.value),
                tooltip: 'تحديث',
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  final shiftCtrl = Get.find<ShiftController>();
                  showDialog(
                    context: context,
                    builder: (_) => ZReportDialog(shiftCtrl: shiftCtrl),
                  );
                },
                icon: const Icon(Icons.lock_clock_rounded, size: 18),
                label: const Text('إقفال الوردية'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withAlpha(20),
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Category Chips ──
          Obx(() => _ctrl.categories.isEmpty
              ? const SizedBox()
              : SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _ctrl.categories.length,
                    itemBuilder: (_, i) {
                      final cat = _ctrl.categories[i];
                      final label = cat.isEmpty ? 'الكل' : cat;
                      final isSelected = _ctrl.selectedCategory.value == cat;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryColor,
                          onSelected: (_) => _ctrl.onCategorySelected(cat),
                        ),
                      );
                    },
                  ),
                )),
          const SizedBox(height: 12),

          // ── Product Grid ──
          Expanded(child: _buildQuickAccessGrid(isDark)),
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid(bool isDark) {
    return Obx(() {
      if (_ctrl.isLoadingProducts.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final products = _ctrl.quickAccessProducts;

      if (products.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.withAlpha(80)),
              const SizedBox(height: 12),
              Text(
                'لا توجد منتجات\nاضغط على تحديث أو أضف منتجات من المخزون',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.withAlpha(120), fontSize: 14),
              ),
            ],
          ),
        );
      }

      return GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) => _buildProductCard(products[index], isDark, index),
      );
    });
  }

  Widget _buildProductCard(dynamic product, bool isDark, int index) {
    final colors = [
      const Color(0xFF6C63FF), const Color(0xFF00E5FF),
      const Color(0xFFFF6584), const Color(0xFFFFB800),
      const Color(0xFF43E97B), const Color(0xFFFA709A),
      const Color(0xFF4FACFE), const Color(0xFFF093FB),
    ];
    final color = colors[index % colors.length];
    final isLow = product.stockQuantity <= product.minStockAlert;

    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shadowColor: color.withAlpha(40),
      child: InkWell(
        splashColor: color.withAlpha(50),
        onTap: () => _ctrl.addProductToCart(product),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [color.withAlpha(60), color.withAlpha(20)]),
                    ),
                    child: Icon(Icons.inventory_2_rounded, color: color, size: 26),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.price.toStringAsFixed(2)} ج',
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'مخزون: ${product.stockQuantity.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            if (isLow)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  child: const Icon(Icons.warning_amber, color: Colors.white, size: 10),
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 30 * index)).scale(begin: const Offset(0.9, 0.9));
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مسح العربة'),
        content: const Text('هل تريد إلغاء الفاتورة الحالية ومسح جميع الأصناف؟'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('لا')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _ctrl.clearCart();
              Get.back();
            },
            child: const Text('نعم، امسح', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditPriceDialog(int index, CartItemModel item) {
    final TextEditingController priceCtrl = TextEditingController(text: item.effectivePrice.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تعديل السعر لـ ${item.productName}', style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'السعر الجديد (ج.م)',
            hintText: 'السعر الأساسي: ${item.unitPrice}',
            prefixIcon: const Icon(Icons.edit_note),
          ),
          autofocus: true,
          onSubmitted: (val) {
            final newPrice = double.tryParse(val);
            if (newPrice != null && newPrice >= 0) {
              _ctrl.updateCustomPrice(index, newPrice);
            }
            Get.back();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _ctrl.updateCustomPrice(index, null); // استعادة الأصلي
              Get.back();
            },
            child: const Text('استعادة الأصلي'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () {
              final newPrice = double.tryParse(priceCtrl.text);
              if (newPrice != null && newPrice >= 0) {
                _ctrl.updateCustomPrice(index, newPrice);
              }
              Get.back();
            },
            child: const Text('حفظ السعر', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog() {
    final TextEditingController discountCtrl = TextEditingController(text: _ctrl.globalDiscount.value > 0 ? _ctrl.globalDiscount.value.toString() : '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة خصم للفاتورة'),
        content: TextField(
          controller: discountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'قيمة الخصم إجمالاً (ج.م)',
            prefixIcon: Icon(Icons.money_off),
          ),
          autofocus: true,
          onSubmitted: (_) {
            _ctrl.globalDiscount.value = double.tryParse(discountCtrl.text) ?? 0.0;
            Get.back();
          },
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            onPressed: () {
              _ctrl.globalDiscount.value = double.tryParse(discountCtrl.text) ?? 0.0;
              Get.back();
            },
            child: const Text('تطبيق الخصم'),
          ),
        ],
      ),
    );
  }
}
