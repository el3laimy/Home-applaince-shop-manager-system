import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:printing/printing.dart';
import '../controllers/settings_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/design_tokens.dart';
import '../services/receipt_service.dart';
import '../services/barcode_print_service.dart';
import '../services/api_service.dart';
import 'package:file_picker/file_picker.dart';

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
              ? [DesignTokens.bgDark, const Color(0xFF0F1629)]
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
                              const SizedBox(height: 20),
                              // BUG-07: SMS settings panel
                              _buildSmsSettings(context, isDark),
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('طابعة الفواتير (Thermal 80mm)'),
              IconButton(onPressed: ctrl.refreshPrinterList, icon: const Icon(Icons.refresh, size: 18), tooltip: 'تحديث قائمة الطابعات'),
            ],
          ),
          const SizedBox(height: 8),
          _printerDropdown(ctrl.receiptPrinterName, ctrl.availablePrinters, isDark),

          const SizedBox(height: 16),
          const Text('طابعة الباركود (Label 50x25mm)'),
          const SizedBox(height: 8),
          _printerDropdown(ctrl.labelPrinterName, ctrl.availablePrinters, isDark),

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

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text('أدوات المعايرة والاختبار', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ReceiptService.printTestPage(),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('اختبار الفاتورة', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCalibrationHelp(context),
                  icon: const Icon(Icons.straighten, size: 18),
                  label: const Text('معايرة الباركود', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          )
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _printerDropdown(RxString value, RxList<String> items, bool isDark) {
    return Obx(() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withAlpha(40) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withAlpha(isDark ? 30 : 60)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value.value) ? value.value : 'Default',
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => value.value = v!,
        ),
      ),
    ));
  }

  void _showCalibrationHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('معايرة طابعة الباركود'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سيتم طباعة ملصق تجريبي بمقاس 50x25 ملم مع إطار خارجي.'),
            SizedBox(height: 12),
            Text('• إذا ظهر الإطار مقطوعاً: تأكد من ضبط مقاس الورق في إعدادات الويندوز.', style: TextStyle(fontSize: 12)),
            Text('• إذا كان الباركود غير واضح: يرجى تنظيف رأس الطابعة أو تعديل الكثافة (Density).', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('طباعة ملصق المعايرة'),
            onPressed: () {
              BarcodePrintService.printCalibrationLabel();
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
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
    final isSavingPath = false.obs;
    final statsData = <String, dynamic>{}.obs;
    final lastBackupInfo = <String, dynamic>{}.obs;
    final customPath = ''.obs;

    // Load DB stats on widget creation
    Future.microtask(() async {
      try {
        final settings = await ApiService.get('shopsettings');
        customPath.value = settings['backupPath'] as String? ?? '';
        
        final s = await ApiService.get('backup/stats');
        statsData.assignAll(s as Map<String, dynamic>);
        if (s['lastBackup'] != null) {
          lastBackupInfo.assignAll(s['lastBackup'] as Map<String, dynamic>);
        }
      } catch (_) {}
    });

    Future<void> selectBackupDirectory() async {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مجلد الحفظ الاحتياطي السحابي',
      );

      if (selectedDirectory != null) {
        isSavingPath.value = true;
        try {
          await ApiService.post('backup/path', {'path': selectedDirectory});
          customPath.value = selectedDirectory;
          Get.snackbar('نجاح', 'تم حفظ مسار النسخ الاحتياطي المخصص ليتم التخزين فيه تلقائياً.', backgroundColor: Colors.green.withAlpha(220), colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        } catch (e) {
          Get.snackbar('خطأ', 'فشل حفظ المسار: $e', backgroundColor: Colors.red.withAlpha(220), colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        } finally {
          isSavingPath.value = false;
        }
      }
    }

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
            Text('النسخ الاحتياطي للبيانات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          
          // Custom Backup Path for Cloud Sync
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withAlpha(10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryColor.withAlpha(40)),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_sync_outlined, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('مسار الحفظ الاحتياطي (استخدم مجلد Google Drive للمزامنة التلقائية)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Obx(() => Text(
                        customPath.value.isEmpty ? 'المسار الافتراضي (محلي)' : customPath.value,
                        style: TextStyle(color: customPath.value.isEmpty ? Colors.grey : Colors.blueGrey, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )),
                    ],
                  ),
                ),
                Obx(() => OutlinedButton.icon(
                  onPressed: isSavingPath.value ? null : selectBackupDirectory,
                  icon: isSavingPath.value ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.folder_open, size: 18),
                  label: const Text('تغيير المسار'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor.withAlpha(80)),
                  ),
                )),
              ],
            ),
          ),
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
          Obx(() {
            final hasBackup = lastBackupInfo.isNotEmpty;
            final lastDateStr = hasBackup ? (lastBackupInfo['createdAt'] as String?) ?? '' : '';
            
            // Checking if backup is old
            bool old = false;
            if (lastDateStr.isNotEmpty) {
              final parsed = DateTime.tryParse(lastDateStr);
              if (parsed != null && DateTime.now().difference(parsed).inDays > 7) {
                old = true;
              }
            }
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasBackup)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withAlpha(60)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('تحذير: لم يتم عمل أي نسخة احتياطية من قبل!', style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.bold))),
                    ]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: old ? Colors.orange.withAlpha(20) : Colors.green.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: old ? Colors.orange.withAlpha(60) : Colors.green.withAlpha(60)),
                    ),
                    child: Row(children: [
                      Icon(old ? Icons.warning_amber_rounded : Icons.check_circle_rounded, color: old ? Colors.orange : Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('آخر نسخة: ${lastBackupInfo['fileName']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: old ? Colors.orange.shade800 : null)),
                        Text('الحجم: ${((lastBackupInfo['sizeBytes'] as int? ?? 0) / 1024).toStringAsFixed(1)} KB${lastDateStr.isNotEmpty ? ' - التاريخ: ${lastDateStr.split('T').first}' : ''}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        if (old)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text('مر أكثر من 7 أيام على آخر نسخة احتياطية!', style: TextStyle(color: Colors.orange.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                          )
                      ])),
                    ]),
                  ),
              ],
            );
          }),

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
                  final url = '${dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:5000/api'}/excelexport/sales';
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


  // ─────────────────────────────────────────────────────────────────────────
  // BUG-07: SMS Configuration panel
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSmsSettings(BuildContext context, bool isDark) {
    final providers = ['VictoryLink', 'Twilio', 'Unifonic'];
    final selectedProvider = 'VictoryLink'.obs;
    final apiKeyCtrl = TextEditingController();
    final senderIdCtrl = TextEditingController();
    final isSaving = false.obs;
    final testSending = false.obs;
    final testPhoneCtrl = TextEditingController();

    // Load current SMS settings
    Future.microtask(() async {
      try {
        final data = await ApiService.get('shopsettings');
        selectedProvider.value = (data['smsProvider'] as String?)?.isNotEmpty == true
            ? data['smsProvider'] as String
            : 'VictoryLink';
        apiKeyCtrl.text = data['smsApiKey'] as String? ?? '';
        senderIdCtrl.text = data['smsSenderId'] as String? ?? '';
      } catch (_) {}
    });

    return _panelBox(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.sms_outlined, color: Color(0xFFFF6B6B)),
            const SizedBox(width: 8),
            Text('إعدادات الرسائل القصيرة (SMS)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          Text('يُمكّن إرسال تذكيرات الأقساط للعملاء تلقائياً',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 20),

          // Provider dropdown
          const Text('مزود الرسائل', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Obx(() => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withAlpha(40) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withAlpha(isDark ? 30 : 60)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedProvider.value,
                isExpanded: true,
                items: providers
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => selectedProvider.value = v!,
              ),
            ),
          )),
          const SizedBox(height: 12),

          // API Key
          Obx(() {
            String hint;
            switch (selectedProvider.value) {
              case 'Twilio':   hint = 'AccountSID:AuthToken'; break;
              case 'Unifonic': hint = 'AppSid'; break;
              default:         hint = 'username:password';
            }
            return TextField(
              controller: apiKeyCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'API Key / بيانات الاعتماد',
                hintText: hint,
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                helperText: selectedProvider.value == 'VictoryLink'
                    ? 'صيغة VictoryLink: username:password'
                    : selectedProvider.value == 'Twilio'
                        ? 'صيغة Twilio: AccountSID:AuthToken'
                        : 'AppSid الخاص بـ Unifonic',
              ),
            );
          }),
          const SizedBox(height: 12),

          // Sender ID
          TextField(
            controller: senderIdCtrl,
            decoration: const InputDecoration(
              labelText: 'معرّف المرسل (Sender ID)',
              hintText: 'مثال: ALIkhlas أو +201234567890',
              prefixIcon: Icon(Icons.send_outlined),
              helperText: 'الاسم الذي يظهر للعميل في الرسالة (يجب تسجيله مسبقاً عند المزود)',
            ),
          ),
          const SizedBox(height: 20),

          // Save button
          Obx(() => SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isSaving.value ? null : () async {
                isSaving.value = true;
                try {
                  await ApiService.put('shopsettings', {
                    'smsProvider': selectedProvider.value,
                    'smsApiKey': apiKeyCtrl.text.trim(),
                    'smsSenderId': senderIdCtrl.text.trim(),
                  });
                  Get.snackbar('نجاح ✓', 'تم حفظ إعدادات SMS',
                      backgroundColor: Colors.green.withAlpha(220), colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM);
                } catch (e) {
                  Get.snackbar('خطأ', 'فشل الحفظ: $e',
                      backgroundColor: Colors.red.withAlpha(220), colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM);
                } finally {
                  isSaving.value = false;
                }
              },
              icon: isSaving.value
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: const Text('حفظ إعدادات SMS'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
            ),
          )),
          const SizedBox(height: 12),

          // Test SMS button
          const Divider(),
          const SizedBox(height: 8),
          TextField(
            controller: testPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم هاتف للاختبار',
              hintText: '01012345678',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 10),
          Obx(() => SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: testSending.value || testPhoneCtrl.text.isEmpty ? null : () async {
                testSending.value = true;
                try {
                  // Find first pending installment to test
                  await ApiService.post('installments/test-sms', {
                    'phone': testPhoneCtrl.text.trim(),
                    'provider': selectedProvider.value,
                    'apiKey': apiKeyCtrl.text.trim(),
                    'senderId': senderIdCtrl.text.trim(),
                  });
                  Get.snackbar('✓ اختبار', 'تم إرسال رسالة اختبار',
                      backgroundColor: Colors.green.withAlpha(220), colorText: Colors.white);
                } catch (e) {
                  Get.snackbar('خطأ', e.toString(),
                      backgroundColor: Colors.red.withAlpha(220), colorText: Colors.white);
                } finally {
                  testSending.value = false;
                }
              },
              icon: testSending.value
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_time_extension_outlined),
              label: const Text('إرسال رسالة اختبار'),
            ),
          )),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1);
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
