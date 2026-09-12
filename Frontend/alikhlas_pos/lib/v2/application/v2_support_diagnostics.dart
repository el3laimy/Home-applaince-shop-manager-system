import 'v2_use_cases.dart';
import 'v2_diagnostic_logger.dart';

/// Produces a small, shareable support report without customer or file data.
class V2SupportDiagnostics {
  const V2SupportDiagnostics({
    required this.appVersion,
    required this.schemaVersion,
  });

  final String appVersion;
  final int schemaVersion;

  String create({
    required BackupStatus backupStatus,
    required String operatingSystem,
    required DateTime createdAt,
    DiagnosticLogSummary? diagnosticLog,
  }) {
    final destination =
        backupStatus.directory == null || backupStatus.directory!.trim().isEmpty
        ? 'لم يتم اختيارها'
        : 'تم اختيارها';
    final warning = backupStatus.warning == null ? 'لا يوجد' : 'موجود';

    return [
      'تقرير دعم إخلاص POS',
      'وقت الإنشاء (UTC): ${createdAt.toUtc().toIso8601String()}',
      'نسخة التطبيق: $appVersion',
      'إصدار قاعدة البيانات: $schemaVersion',
      'النظام: $operatingSystem',
      'وجهة النسخ: $destination',
      'تاريخ آخر نسخة تلقائية ناجحة: ${backupDate(backupStatus.lastDate)}',
      'عدد النسخ المتاحة: ${backupStatus.backupCount} من ${backupStatus.retentionCopies}',
      'تحذير النسخ: $warning',
      'سجل الأعطال المحلي: ${diagnosticLog == null ? 'غير متاح' : '${diagnosticLog.recordCount} حدث'}',
      'وقت آخر عطل (UTC): ${diagnosticLog?.lastRecordedAt?.toUtc().toIso8601String() ?? 'لا يوجد'}',
      '',
      'لا يحتوي هذا التقرير على قاعدة البيانات أو المبيعات أو بيانات العملاء أو أرقام الهواتف أو كلمات المرور أو مسارات الملفات أو رسائل الأعطال.',
    ].join('\n');
  }

  /// Only export a validated calendar date, never raw persisted setting text.
  static String backupDate(String? value) {
    if (value == null || value.isEmpty) return 'لا يوجد';
    final match = RegExp(r'^\d{4}-\d{2}-\d{2}$').firstMatch(value);
    if (match == null) return 'غير متاح';
    final date = DateTime.tryParse(value);
    if (date == null || date.toIso8601String().substring(0, 10) != value) {
      return 'غير متاح';
    }
    return value;
  }
}
