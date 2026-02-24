import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/returns_controller.dart';
import '../core/theme/app_theme.dart';

class ReturnsScreen extends StatelessWidget {
  const ReturnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ReturnsController());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchInputCtrl = TextEditingController(text: ctrl.invoiceNoQuery.value);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
              : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إدارة المرتجعات', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('إنشاء إيصالات الاسترجاع واسترداد المخزون', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ],
                  ).animate().fade().slideX(begin: 0.1),
                ],
              ),
              const SizedBox(height: 24),
              
              // Search Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(200),
                      border: Border.all(color: Colors.white.withAlpha(isDark ? 30 : 60)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchInputCtrl,
                            decoration: InputDecoration(
                              labelText: 'رقم الفاتورة الأصلية (مثال: INV-123456)',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          height: 52,
                          child: Obx(() => ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                            ),
                            icon: ctrl.isLoading.value ? const SizedBox.shrink() : const Icon(Icons.receipt_long),
                            label: ctrl.isLoading.value 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                              : const Text('بحث الفاتورة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            onPressed: ctrl.isLoading.value ? null : () => ctrl.searchInvoice(searchInputCtrl.text, context),
                          )),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.1),
              
              const SizedBox(height: 24),
              
              // Main content
              Expanded(
                child: Obx(() {
                  if (ctrl.searchedInvoice.value == null) {
                    if (ctrl.isLoading.value) return const Center(child: CircularProgressIndicator());
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.withAlpha(70)),
                          const SizedBox(height: 16),
                          Text('ابحث عن فاتورة للبدء في الاسترجاع', style: TextStyle(color: Colors.grey[500], fontSize: 18)),
                        ],
                      ).animate().fade(),
                    );
                  }
                  
                  return _buildReturnProcessPanel(context, ctrl, isDark);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReturnProcessPanel(BuildContext context, ReturnsController ctrl, bool isDark) {
    final inv = ctrl.searchedInvoice.value!;
    final items = inv['items'] as List<dynamic>? ?? [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Items List
        Expanded(
          flex: 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(200),
                  border: Border.all(color: Colors.white.withAlpha(isDark ? 30 : 60)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(Icons.receipt, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text('أصناف الفاتورة: ${inv['invoiceNo']}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('طريقة الدفع: ${inv['paymentType']}', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (ctx, i) {
                          final item = items[i];
                          final maxQty = (item['quantity'] as num).toInt();
                          final pid = item['productId'];
                          
                          return Container(
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(20)))),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              title: Text(item['productName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('الكمية المباعة: $maxQty — السعر: ${item['unitPrice']} ج.م', style: TextStyle(color: Colors.grey[500])),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('مرتجع:', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 12),
                                  Obx(() {
                                    final retQty = ctrl.returnQuantities[pid] ?? 0;
                                    return Row(
                                      children: [
                                        IconButton(
                                          icon: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(color: Colors.red.withAlpha(30), shape: BoxShape.circle),
                                            child: const Icon(Icons.remove, color: Colors.red, size: 16),
                                          ),
                                          onPressed: () => ctrl.decrementReturnQty(pid),
                                        ),
                                        SizedBox(width: 24, child: Center(child: Text('$retQty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
                                        IconButton(
                                          icon: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(color: Colors.green.withAlpha(30), shape: BoxShape.circle),
                                            child: const Icon(Icons.add, color: Colors.green, size: 16),
                                          ),
                                          onPressed: () => ctrl.incrementReturnQty(pid, maxQty),
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn().slideX(begin: 0.1),
        
        const SizedBox(width: 20),
        
        // Summary & Submit Panel
        Expanded(
          flex: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(200),
                  border: Border.all(color: Colors.white.withAlpha(isDark ? 30 : 60)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('ملخص الاسترجاع', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    
                    Text('سبب الاسترجاع (اختياري)', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'مثال: عيب مصنعي...',
                        filled: true, fillColor: isDark ? Colors.black.withAlpha(40) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => ctrl.returnReason.value = v,
                    ),
                    const SizedBox(height: 20),
                    
                    Obx(() => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('إعادة المنتجات للمخزون'),
                      subtitle: const Text('إرجاع الكميات المرتجعة فوراً للمخزن'),
                      value: ctrl.returnToStock.value,
                      onChanged: (v) => ctrl.returnToStock.value = v,
                      activeColor: Colors.green,
                    )),
                    
                    const Spacer(),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    const Text('المبلغ المسترد للعميل', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Obx(() => Text(
                      '${ctrl.customRefundAmount.value.toStringAsFixed(2)} ج.م',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.redAccent.shade200),
                    )),
                    
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      height: 54,
                      child: Obx(() => ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: ctrl.isLoading.value
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.keyboard_return), SizedBox(width: 8),
                              Text('تأكيد الاسترجاع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ]),
                        onPressed: ctrl.isLoading.value ? null : () => ctrl.processReturn(context),
                      )),
                    )
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.1),
      ],
    );
  }
}
