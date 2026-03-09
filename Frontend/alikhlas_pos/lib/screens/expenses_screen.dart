import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../controllers/expenses_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_colors.dart';

class ExpensesScreen extends StatelessWidget {
  ExpensesScreen({super.key});

  final ExpensesController controller = Get.put(ExpensesController());

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('إدارة المصروفات'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildHeader(context, isDark),
            const SizedBox(height: 24),
            Expanded(
              child: _buildExpensesList(isDark),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('مصروف جديد'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('سجل المصروفات', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('إدارة جميع المصروفات وتصنيفاتها', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث البيانات',
            onPressed: () => controller.fetchExpenses(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesList(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Obx(() {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.expenses.isEmpty) {
          return const Center(
            child: Text('لا توجد مصروفات مسجلة', style: TextStyle(fontSize: 16, color: Colors.grey)),
          );
        }

        return ListView.separated(
          itemCount: controller.expenses.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final expense = controller.expenses[index];
            final date = DateTime.parse(expense['date']);
            final amount = expense['amount'] as double;
            final categoryName = expense['categoryName'] as String? ?? 'أخرى';
            final description = expense['description'] as String? ?? '';

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withAlpha(20),
                child: const Icon(Icons.attach_money, color: AppTheme.primaryColor),
              ),
              title: Text(categoryName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(description.isNotEmpty ? description : 'بدون تفاصيل', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(DateFormat('dd-MM-yyyy HH:mm a').format(date.toLocal()),
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (expense['receiptImagePath'] != null && (expense['receiptImagePath'] as String).isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.receipt, color: AppColors.primary),
                      tooltip: 'عرض الإيصال',
                      onPressed: () {
                        // For a real app, you can launch url or show a dialog with image from network
                        // Using baseUrl: baseUrl + expense['receiptImagePath']
                        Get.dialog(AlertDialog(
                          title: const Text('صورة الإيصال'),
                          content: Image.network(
                            'http://localhost:5290${expense['receiptImagePath']}', // Usually fetched from ApiService baseUrl ideally
                            errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 50),
                          ),
                          actions: [TextButton(onPressed: () => Get.back(), child: const Text('إغلاق'))],
                        ));
                      },
                    ),
                  Text(
                    '${amount.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    tooltip: 'حذف المصروف',
                    onPressed: () {
                      Get.defaultDialog(
                        title: 'تأكيد الحذف',
                        middleText: 'هل أنت متأكد من حذف مصروف "$categoryName" بقيمة $amount؟\nسيتم عكس التأثير المحاسبي تلقائياً.',
                        textConfirm: 'نعم، احذف',
                        textCancel: 'إلغاء',
                        confirmTextColor: Colors.white,
                        onConfirm: () {
                          Get.back();
                          controller.deleteExpense(expense['id']);
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final selectedCategory = RxnString();
    final selectedReceiptPath = ''.obs;
    final isSubmitting = false.obs;

    // Default to first category if available
    if (controller.categories.isNotEmpty) {
      selectedCategory.value = controller.categories.first['id'] as String;
    }

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.add_circle, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('تسجيل مصروف جديد'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ',
                    prefixIcon: Icon(Icons.money),
                    suffixText: 'ج.م',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'يرجى إدخال المبلغ';
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'يرجى إدخال مبلغ صحيح';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Obx(() => DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'التصنيف',
                          prefixIcon: Icon(Icons.category),
                        ),
                        value: controller.categories.any((c) => c['id'] == selectedCategory.value) ? selectedCategory.value : null,
                        items: controller.categories.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['id'] as String,
                            child: Text(c['name'] as String),
                          );
                        }).toList(),
                        onChanged: (val) {
                          selectedCategory.value = val;
                        },
                        validator: (value) => value == null ? 'يرجى اختيار التصنيف' : null,
                      )),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => _showAddCategoryDialog(context),
                      icon: const Icon(Icons.add),
                      tooltip: 'تصنيف جديد',
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor.withAlpha(20),
                        foregroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'البيان وملاحظات',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Obx(() => Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
                          if (result != null && result.files.single.path != null) {
                            selectedReceiptPath.value = result.files.single.path!;
                          }
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: Text(selectedReceiptPath.value.isEmpty 
                            ? 'إرفاق صورة الإيصال (اختياري)' 
                            : 'تم اختيار الإيصال: ${selectedReceiptPath.value.split('/').last}'),
                      ),
                    ),
                    if (selectedReceiptPath.value.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        onPressed: () => selectedReceiptPath.value = '',
                        tooltip: 'إزالة الإيصال',
                      )
                  ],
                )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          Obx(() => FilledButton.icon(
            onPressed: isSubmitting.value ? null : () async {
              if (formKey.currentState!.validate()) {
                isSubmitting.value = true;
                final success = await controller.createExpense(
                  double.parse(amountController.text),
                  selectedCategory.value!,
                  descriptionController.text,
                  localReceiptPath: selectedReceiptPath.value.isNotEmpty ? selectedReceiptPath.value : null,
                );
                isSubmitting.value = false;
                if (success && context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            icon: isSubmitting.value
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: const Text('حفظ المصروف'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          )),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final isSubmitting = false.obs;

    Get.dialog(
      AlertDialog(
        title: const Text('إضافة تصنيف مصروفات جديد', style: TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسم التصنيف',
                hintText: 'مثال: مصاريف صيانة',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          Obx(() => FilledButton(
            onPressed: isSubmitting.value ? null : () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                isSubmitting.value = true;
                final success = await controller.createCategory(name);
                isSubmitting.value = false;
                if (success && context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: isSubmitting.value 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('إضافة'),
          )),
        ],
      ),
    );
  }
}
