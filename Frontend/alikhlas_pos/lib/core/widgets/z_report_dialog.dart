import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../controllers/shift_controller.dart';
import '../theme/app_theme.dart';
import '../../core/utils/formatters.dart';

class ZReportDialog extends StatefulWidget {
  final ShiftController shiftCtrl;
  const ZReportDialog({super.key, required this.shiftCtrl});

  @override
  State<ZReportDialog> createState() => _ZReportDialogState();
}

class _ZReportDialogState extends State<ZReportDialog> {
  final TextEditingController _actualCashCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  void _submit() async {
    if (widget.shiftCtrl.currentShift.value == null) return;

    final actualCash = double.tryParse(_actualCashCtrl.text) ?? 0.0;

    final success = await widget.shiftCtrl.closeShift(
      actualCash,
      _notesCtrl.text,
    );
    if (success) {
      Get.back(); // close dialog
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = widget.shiftCtrl.currentShift.value;
    if (shift == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 800,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.redAccent,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تقرير الإقفال (Z-Report)',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'تصفية الوردية الحالية',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 32),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: System calculated amounts
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.withAlpha(isDark ? 30 : 50),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ملخص عمليات النظام',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _summaryRow(
                          'عهدة بداية الوردية',
                          shift.openingCash,
                          Colors.blue,
                        ),
                        const Divider(height: 32),
                        _summaryRow(
                          'إجمالي المبيعات والمقبوضات',
                          shift.totalCashIn,
                          Colors.green,
                        ),
                        const SizedBox(height: 12),
                        _summaryRow(
                          'المصروفات والمرتجعات (النقدية)',
                          shift.totalCashOut,
                          Colors.redAccent,
                        ),
                        const Divider(height: 32),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withAlpha(50),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'الرصيد المتوقع بالدرج:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                AppFormatters.currency(shift.expectedCash),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 32),

                // Right side: Actual counting & closing
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      const Text(
                        'تصفية النقدية بالدرج',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _actualCashCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: 'الرصيد الفعلي (الموجود بالدرج حالياً)',
                          prefixIcon: const Icon(
                            Icons.account_balance_wallet,
                            size: 28,
                          ),
                          suffixText: 'ج.م',
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withAlpha(10)
                              : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onChanged: (val) =>
                            setState(() {}), // trigger difference calculation
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'ملاحظات العجز/الزيادة (اختياري)',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),

                      // Difference preview
                      const SizedBox(height: 24),
                      Builder(
                        builder: (ctx) {
                          final actual =
                              double.tryParse(_actualCashCtrl.text) ?? 0.0;
                          final diff = actual - shift.expectedCash;
                          final color = diff == 0
                              ? Colors.green
                              : (diff > 0 ? Colors.blue : Colors.redAccent);
                          final label = diff == 0
                              ? 'الرصيد متطابق'
                              : (diff > 0
                                    ? 'يوجد زيادة نقدية'
                                    : 'يوجد عجز نقدي');

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: color.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withAlpha(50)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  diff == 0
                                      ? Icons.check_circle
                                      : Icons.warning_amber_rounded,
                                  color: color,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                if (diff != 0)
                                  Text(
                                    '${diff > 0 ? '+' : ''}${AppFormatters.currency(diff)}',
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: Obx(
                          () => ElevatedButton.icon(
                            onPressed: widget.shiftCtrl.isLoading.value
                                ? null
                                : _submit,
                            icon: widget.shiftCtrl.isLoading.value
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.print_rounded),
                            label: const Text(
                              'إغلاق الوردية وطباعة التقرير',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _summaryRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          AppFormatters.currency(amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
