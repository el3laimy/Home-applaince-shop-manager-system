import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../controllers/settings_controller.dart';
import '../core/theme/app_theme.dart';
import '../services/receipt_service.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(SettingsController());
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              _buildHeader(context, isDark),
              const SizedBox(height: 24),
              Expanded(
                child: Obx(() {
                  if (ctrl.isLoading.value) return const Center(child: CircularProgressIndicator());

                  return SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (Shop Settings & Printing)
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              _buildShopSettings(context, isDark),
                              const SizedBox(height: 20),
                              _buildPrinterSettings(context, ctrl, isDark),
                              const SizedBox(height: 20),
                              _buildBackupSettings(context, isDark),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Right Column (UI & Behavior)
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              _buildBehaviorSettings(context, ctrl, isDark),
                              const SizedBox(height: 20),
                              _buildAboutApp(context, isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إعدادات النظام', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('تخصيص سلوك التطبيق والطباعة', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ],
        ),
      ],
    ).animate().fade().slideX(begin: 0.1);
  }

  Widget _buildShopSettings(BuildContext context, bool isDark) {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final footerCtrl = TextEditingController();
    final vatEnabled = false.obs;
    final isLoadingSave = false.obs;

    // Load current settings
    Future.microtask(() async {
      try {
        final data = await ApiService.get('shopsettings');
        nameCtrl.text = data['shopName'] as String? ?? '';
        addrCtrl.text = data['address'] as String? ?? '';
        phoneCtrl.text = data['phone'] as String? ?? '';
        footerCtrl.text = data['receiptFooter'] as String? ?? '';
        vatEnabled.value = data['vatEnabled'] as bool? ?? false;
        ReceiptService.clearCache();
      } catch (_) {}
    });

    return _panelBox(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.store_rounded, color: Color(0xFF6C63FF)),
            const SizedBox(width: 8),
            Text('بيانات المحل', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 20),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المحل *', prefixIcon: Icon(Icons.storefront))),
          const SizedBox(height: 12),
          TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'العنوان', prefixIcon: Icon(Icons.location_on))),
          const SizedBox(height: 12),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone))),
          const SizedBox(height: 12),
          TextField(controller: footerCtrl, decoration: const InputDecoration(labelText: 'تذييل الإيصال', prefixIcon: Icon(Icons.receipt_long)), maxLines: 2),
          const SizedBox(height: 16),
          Obx(() => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('تفعيل ضريبة القيمة المضافة'),
            value: vatEnabled.value,
            onChanged: (v) => vatEnabled.value = v,
            activeColor: AppTheme.primaryColor,
          )),
          const SizedBox(height: 16),
          Obx(() => SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isLoadingSave.value ? null : () async {
                isLoadingSave.value = true;
                try {
                  await ApiService.put('shopsettings', {
                    'shopName': nameCtrl.text.trim(),
                    'address': addrCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'receiptFooter': footerCtrl.text.trim(),
                    'vatEnabled': vatEnabled.value,
                  });
                  ReceiptService.clearCache();
                  Get.snackbar('نجاح', 'تم حفظ بيانات المحل', backgroundColor: Colors.green.withAlpha(220), colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
                } catch (e) {
                  Get.snackbar('خطأ', 'فشل الحفظ: $e', backgroundColor: Colors.red.withAlpha(220), colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
                } finally {
                  isLoadingSave.value = false;
                }
              },
              icon: isLoadingSave.value ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded),
              label: const Text('حفظ البيانات'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            ),
          )),
        ],
      ),
    ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1);
  }

  Widget _buildPrinterSettings(BuildContext context, SettingsController ctrl, bool isDark) {
    return _panelBox(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.print, color: Color(0xFFFA709A)),
              const SizedBox(width: 8),
              Text('إعدادات الطباعة والفواتير', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),

          const Text('الطابعة الافتراضية للكاشير'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withAlpha(40) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withAlpha(isDark ? 30 : 60)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: ctrl.selectedPrinter.value,
                isExpanded: true,
                items: ['Default Printer', 'XP-80 Printer', 'Bixolon SRP', 'PDF Export']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => ctrl.selectedPrinter.value = v!,
              ),
            ),
          ),

          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('طباعة الفاتورة تلقائياً'),
            subtitle: const Text('سيتم إرسال الأمر للطابعة فور الدفع', style: TextStyle(fontSize: 12)),
            value: ctrl.autoPrintReceipts.value,
            onChanged: (v) => ctrl.autoPrintReceipts.value = v,
            activeColor: AppTheme.primaryColor,
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('طباعة الباركود في الإيصال'),
            subtitle: const Text('لتسهيل عمليات الإرجاع مستقبلاً', style: TextStyle(fontSize: 12)),
            value: ctrl.printInvoiceBarcode.value,
            onChanged: (v) => ctrl.printInvoiceBarcode.value = v,
            activeColor: AppTheme.primaryColor,
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ReceiptService.printTestPage(),
              icon: const Icon(Icons.receipt_long),
              label: const Text('طباعة صفحة اختبار'),
            ),
          )
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _buildBehaviorSettings(BuildContext context, SettingsController ctrl, bool isDark) {
    return _panelBox(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app, color: Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              Text('سلوك الكاشير', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('تفعيل اختصارات لوحة المفاتيح'),
            subtitle: const Text('استخدام أزرار (F2 للدفع، Esc للإلغاء) لسرعة العمل', style: TextStyle(fontSize: 12)),
            value: ctrl.enableKeyboardShortcuts.value,
            onChanged: (v) => ctrl.enableKeyboardShortcuts.value = v,
            activeColor: const Color(0xFF00E5FF),
          ),
          
          const SizedBox(height: 16),
          const Text('لون شاشة نقطة البيع (POS)'),
          const SizedBox(height: 8),
          Row(
            children: ['Blue', 'Green', 'Red'].map((colorStr) {
              Color c;
              switch(colorStr) {
                case 'Green': c = Colors.green; break;
                case 'Red': c = Colors.redAccent; break;
                default: c = AppTheme.primaryColor;
              }
              return GestureDetector(
                onTap: () => ctrl.posThemeColor.value = colorStr,
                child: Container(
                  margin: const EdgeInsets.only(left: 12),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: c, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: ctrl.posThemeColor.value == colorStr ? 3 : 0),
                    boxShadow: ctrl.posThemeColor.value == colorStr ? [BoxShadow(color: c.withAlpha(100), blurRadius: 10)] : [],
                  ),
                  child: ctrl.posThemeColor.value == colorStr ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: ctrl.saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('حفظ التعديلات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildBackupSettings(BuildContext context, bool isDark) {
    final isTriggering = false.obs;
    final statsData = <String, dynamic>{}.obs;
    final lastBackupInfo = <String, dynamic>{}.obs;

    // Load DB stats on widget creation
    Future.microtask(() async {
      try {
        final s = await ApiService.get('backup/stats');
        statsData.assignAll(s as Map<String, dynamic>);
      } catch (_) {}
    });

    Future<void> triggerBackup() async {
      isTriggering.value = true;
      try {
        final result = await ApiService.post('backup/trigger', {}) as Map<String, dynamic>;
        lastBackupInfo.assignAll(result);
        Get.snackbar(
          '✅ تم النسخ الاحتياطي',
          result['message'] as String? ?? 'تم الحفظ',
          backgroundColor: Colors.green.withAlpha(220),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      } catch (e) {
        Get.snackbar('خطأ', e.toString(), backgroundColor: Colors.red.withAlpha(220), colorText: Colors.white);
      } finally {
        isTriggering.value = false;
      }
    }

    return _panelBox(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.backup_rounded, color: Color(0xFF43E97B)),
            const SizedBox(width: 8),
            Text('النسخ الاحتياطي والبيانات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),

          // DB Stats
          Obx(() {
            if (statsData.isEmpty) {
              return const LinearProgressIndicator();
            }
            final tables = statsData['tables'] as Map<String, dynamic>? ?? {};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إجمالي السجلات: ${statsData['totalRecords']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: tables.entries.map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryColor.withAlpha(40)),
                    ),
                    child: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  )).toList(),
                ),
              ],
            );
          }),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Backup trigger
          Obx(() => lastBackupInfo.isNotEmpty ? Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withAlpha(60)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('آخر نسخة: ${lastBackupInfo['fileName']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('الحجم: ${((lastBackupInfo['sizeBytes'] as int? ?? 0) / 1024).toStringAsFixed(1)} KB',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ])),
            ]),
          ) : const SizedBox()),

          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Obx(() => FilledButton.icon(
                onPressed: isTriggering.value ? null : triggerBackup,
                icon: isTriggering.value
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_download_rounded),
                label: Text(isTriggering.value ? 'جارٍ النسخ...' : 'نسخ احتياطي الآن'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF43E97B), foregroundColor: Colors.black87),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final url = '${ApiService.baseUrl}/excelexport/sales';
                  Get.snackbar('📊 تصدير Excel', 'افتح الرابط:\n$url',
                      duration: const Duration(seconds: 5),
                      backgroundColor: Colors.indigo.withAlpha(220), colorText: Colors.white);
                },
                icon: const Icon(Icons.table_chart_rounded),
                label: const Text('تصدير Excel'),
              ),
            ),
          ]),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1);
  }


  Widget _buildAboutApp(BuildContext context, bool isDark) {
    return _panelBox(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.primaryColor.withAlpha(20), shape: BoxShape.circle),
            child: Icon(Icons.diamond, color: AppTheme.primaryColor, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('نظام إخلاص كاشير - ALIkhlasPOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('الإصدار v1.0.0 (Beta)', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 16),
          Text('بدعم من Antigravity ERP Engine', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _panelBox(bool isDark, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withAlpha(5) : Colors.white.withAlpha(200),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(isDark ? 20 : 60)),
          ),
          child: child,
        ),
      ),
    );
  }
}
