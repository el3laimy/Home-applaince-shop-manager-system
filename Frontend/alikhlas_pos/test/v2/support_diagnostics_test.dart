import 'package:alikhlas_pos/v2/application/v2_support_diagnostics.dart';
import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'support diagnostics report contains runtime state without private paths',
    () {
      const diagnostics = V2SupportDiagnostics(
        appVersion: '9.4.2+7',
        schemaVersion: 42,
      );

      final report = diagnostics.create(
        backupStatus: const BackupStatus(
          directory: '/home/owner/Private Backups',
          latestBackupPath: '/home/owner/Private Backups/alikhlas-v2.db',
          lastDate: '2026-09-11',
          backupCount: 3,
          retentionCopies: 30,
          warning: 'تعذر الوصول إلى القرص /media/private-usb',
        ),
        operatingSystem: 'linux',
        createdAt: DateTime.utc(2026, 9, 11, 10, 0),
      );

      expect(report, contains('نسخة التطبيق: 9.4.2+7'));
      expect(report, contains('إصدار قاعدة البيانات: 42'));
      expect(report, contains('النظام: linux'));
      expect(report, contains('وجهة النسخ: تم اختيارها'));
      expect(report, contains('عدد النسخ المتاحة: 3 من 30'));
      expect(report, contains('تاريخ آخر نسخة تلقائية ناجحة: 2026-09-11'));
      expect(report, contains('تحذير النسخ: موجود'));
      expect(report, contains('لا يحتوي هذا التقرير على قاعدة البيانات'));
      expect(report, isNot(contains('/home/owner')));
      expect(report, isNot(contains('private-usb')));
    },
  );

  test('support report never echoes malformed persisted backup dates', () {
    for (final value in [
      '/home/private/customer.db',
      '2026-09-11\nرقم العميل: 01012345678',
      '2026-02-31',
    ]) {
      final report =
          const V2SupportDiagnostics(
            appVersion: '1.2.3+4',
            schemaVersion: 5,
          ).create(
            backupStatus: BackupStatus(lastDate: value),
            operatingSystem: 'linux',
            createdAt: DateTime.utc(2026),
          );
      expect(report, isNot(contains(value)));
      expect(report, contains('تاريخ آخر نسخة تلقائية ناجحة: غير متاح'));
    }
    expect(V2SupportDiagnostics.backupDate(null), 'لا يوجد');
  });
}
