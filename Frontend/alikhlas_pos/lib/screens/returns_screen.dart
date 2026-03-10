import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/returns_controller.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../services/pdf_service.dart';

class ReturnsScreen extends StatelessWidget {
  final ReturnsController controller = Get.put(ReturnsController());
  final TextEditingController invoiceSearchController = TextEditingController();

  ReturnsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('إدارة المرتجعات'),
          backgroundColor: AppColors.surface,
          bottom: TabBar(
            tabs: const [
              Tab(icon: Icon(Icons.undo), text: 'إرجاع فاتورة'),
              Tab(icon: Icon(Icons.history), text: 'سجل المرتجعات'),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          children: [
            _buildNewReturnTab(context),
            _buildReturnsHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildNewReturnTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchBox(context),
          const SizedBox(height: 24),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.searchedInvoice.value == null) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (controller.searchedInvoice.value == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('ابحث برقم الفاتورة لإجراء عملية استرجاع', style: TextStyle(color: Colors.grey, fontSize: 18)),
                    ],
                  ),
                );
              }
              
              return _buildInvoiceDetails(context);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: invoiceSearchController,
              decoration: InputDecoration(
                hintText: 'أدخل رقم الفاتورة (مثال: INV-2023...)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (val) => controller.searchInvoice(val, context),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => controller.searchInvoice(invoiceSearchController.text, context),
            icon: const Icon(Icons.search),
            label: const Text('بحث'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInvoiceDetails(BuildContext context) {
    final invoice = controller.searchedInvoice.value!;
    final items = invoice['items'] as List<dynamic>? ?? [];
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Side: Items
        Expanded(
          flex: 2,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أصناف الفاتورة: ${invoice['invoiceNo']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final productId = item['productId'];
                        final returnableQty = item['returnableQuantity'];
                        final originalQty = item['originalQuantity'];
                        final isBundle = item['isBundle'] == true;

                        if (isBundle) {
                          final bundleItems = item['bundleItems'] as List<dynamic>? ?? [];
                          return ExpansionTile(
                            title: Text('${item['productName']} (عرض مجمع)', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('الكمية الأصلية للعرض: $originalQty | السعر: ${AppFormatters.currency(item['unitPrice'])}'),
                            children: bundleItems.map((bi) {
                              final subId = bi['subProductId'];
                              final uniqueKey = '${productId}_$subId';
                              final subReturnable = controller.returnableQuantities[uniqueKey] ?? 0;
                              
                              return Obx(() {
                                final currentReturnQty = controller.returnQuantities[uniqueKey] ?? 0;
                                final originalSubQty = bi['totalSubQuantity'] ?? 0;
                                
                                return Padding(
                                  padding: const EdgeInsets.only(right: 32.0, left: 16.0, top: 8, bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(bi['subProductName'] ?? 'مكون', style: const TextStyle(fontSize: 14)),
                                            Text('إجمالي المباع: $originalSubQty', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      // Custom Price Input
                                      if (currentReturnQty > 0)
                                        SizedBox(
                                          width: 100,
                                          height: 40,
                                          child: TextFormField(
                                            initialValue: controller.returnCustomPrices[uniqueKey]?.toString() ?? '',
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: const InputDecoration(
                                              labelText: 'سعر الاسترداد',
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                              border: OutlineInputBorder(),
                                            ),
                                            onChanged: (val) {
                                              final price = double.tryParse(val) ?? 0.0;
                                              controller.updateCustomPrice(uniqueKey, price);
                                            },
                                          ),
                                        ),
                                      const SizedBox(width: 16),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('مرتجع', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text('$currentReturnQty / $subReturnable', 
                                            style: TextStyle(
                                              fontSize: 16, 
                                              fontWeight: FontWeight.bold,
                                              color: currentReturnQty > 0 ? AppColors.error : Colors.black87
                                            )
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                        onPressed: currentReturnQty > 0 
                                            ? () => controller.decrementReturnQty(uniqueKey)
                                            : null,
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.add_circle, color: currentReturnQty < subReturnable ? AppColors.primary : Colors.grey),
                                        onPressed: currentReturnQty < subReturnable 
                                            ? () => controller.incrementReturnQty(uniqueKey)
                                            : null,
                                      ),
                                    ],
                                  ),
                                );
                              });
                            }).toList(),
                          );
                        }

                        // Normal Product (Not a bundle)
                        return Obx(() {
                          final currentReturnQty = controller.returnQuantities[productId] ?? 0;
                          
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item['productName']),
                            subtitle: Text('الكمية الأصلية: $originalQty | السعر: ${AppFormatters.currency(item['unitPrice'])}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('مرتجع', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text('$currentReturnQty / $returnableQty', 
                                      style: TextStyle(
                                        fontSize: 16, 
                                        fontWeight: FontWeight.bold,
                                        color: currentReturnQty > 0 ? AppColors.error : Colors.black87
                                      )
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: currentReturnQty > 0 
                                      ? () => controller.decrementReturnQty(productId)
                                      : null,
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_circle, color: currentReturnQty < returnableQty ? AppColors.primary : Colors.grey),
                                  onPressed: currentReturnQty < returnableQty 
                                      ? () => controller.incrementReturnQty(productId)
                                      : null,
                                ),
                              ],
                            ),
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 24),
        
        // Right Side: Summary & Actions
        Expanded(
          flex: 1,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ملخص الفاتورة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildSummaryRow('العميل', invoice['customerName'] ?? 'غير معروف'),
                  _buildSummaryRow('تاريخ الفاتورة', AppFormatters.dateTime(DateTime.tryParse(invoice['createdAt']?.toString() ?? '') ?? DateTime.now())),
                  _buildSummaryRow('الإجمالي الأصلي', AppFormatters.currency(invoice['totalAmount'])),
                  _buildSummaryRow('المدفوع', AppFormatters.currency(invoice['paidAmount'])),
                  
                  const Divider(height: 32),
                  
                  const Text('إعدادات المرتجع', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'سبب الإرجاع', border: OutlineInputBorder()),
                    value: 3, // mapped to Other
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('تالف/عيب مصنعي')),
                      DropdownMenuItem(value: 1, child: Text('تراجع العميل')),
                      DropdownMenuItem(value: 2, child: Text('منتج خطأ')),
                      DropdownMenuItem(value: 3, child: Text('أخرى')),
                    ],
                    onChanged: (val) {
                       // We can map this to state later if needed, default is handled in controller
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => controller.returnReason.value = v,
                  ),
                  
                  const Spacer(),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text('قيمة الاسترداد المستحقة للعميل', style: TextStyle(color: AppColors.error)),
                        const SizedBox(height: 8),
                        Obx(() => Text(
                          AppFormatters.currency(controller.customRefundAmount.value),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.error),
                        )),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Obx(() => SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: controller.isLoading.value || controller.customRefundAmount.value == 0
                          ? null 
                          : () => controller.processReturn(context),
                      child: controller.isLoading.value 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('تأكيد الإرجاع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  )),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.blueGrey),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('تحميل الفاتورة الأصلية (PDF)'),
                      onPressed: () => PdfService.downloadAndOpenInvoicePdf(invoice['id']),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReturnsHistoryTab() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'بحث برقم المرتجع، رقم الفاتورة أو اسم العميل...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              fillColor: AppColors.surface,
              filled: true,
            ),
            onChanged: (v) {
              controller.searchHistoryQuery.value = v;
              controller.fetchReturnHistory();
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.returnHistory.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (controller.returnHistory.isEmpty) {
                return const Center(child: Text('لا توجد سجلات مرتجعات.'));
              }
              
              return Card(
                elevation: 2,
                child: ListView.separated(
                  itemCount: controller.returnHistory.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final ret = controller.returnHistory[index];
                    return ExpansionTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.error,
                        child: Icon(Icons.undo, color: Colors.white, size: 20),
                      ),
                      title: Text(ret['returnNo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('الفاتورة الأصلية: ${ret['originalInvoiceNo']} | ${ret['customerName']}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(AppFormatters.currency(ret['refundAmount']), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                          Text(AppFormatters.date(DateTime.tryParse(ret['createdAt']?.toString() ?? '') ?? DateTime.now()), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.grey.withOpacity(0.05),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('السبب: ${ret['reason']} - ملاحظات: ${ret['notes'] ?? '-'}', style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 8),
                              const Text('الأصناف المسترجعة:', style: TextStyle(fontWeight: FontWeight.bold)),
                              ...(ret['items'] as List<dynamic>).map((item) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('- ${item['productName']} (x${item['quantity']})'),
                                      Text(AppFormatters.currency(item['totalPrice'])),
                                    ],
                                  ),
                                );
                              }).toList()
                            ],
                          ),
                        )
                      ],
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
