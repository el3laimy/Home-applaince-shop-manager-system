part of '../v2_app.dart';

class _BackupView extends ConsumerWidget {
  const _BackupView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupStatus = snapshot.backupStatus;
    return _Screen(
      title: 'النسخ الاحتياطي',
      subtitle:
          'نسخ تلقائي كل 30 دقيقة أثناء التشغيل، مع إعادة المحاولة عند تعذر النسخ',
      child: _GlassPane(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (backupStatus.warning != null)
              Text(
                backupStatus.warning!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            _InfoLine('مجلد النسخ', backupStatus.directory ?? 'لم يتم اختياره'),
            _InfoLine('آخر نسخة تلقائية', backupStatus.lastDate ?? 'لا يوجد'),
            _InfoLine(
              'آخر ملف',
              backupStatus.latestBackupPath == null
                  ? 'لا يوجد'
                  : _fileName(backupStatus.latestBackupPath!),
            ),
            _InfoLine(
              'الاحتفاظ',
              '${backupStatus.backupCount}/${backupStatus.retentionCopies} نسخة',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => _manualBackup(context, ref),
                  icon: const Icon(Icons.backup),
                  label: const Text('نسخ الآن'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _portableBackup(context, ref),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('حزمة نقل تشمل الصور'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _chooseBackupDirectory(context, ref),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('اختيار المجلد'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _restoreBackup(context, ref),
                  icon: const Icon(Icons.restore),
                  label: const Text('استرجاع نسخة'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _auditData(context, ref),
                  icon: const Icon(Icons.fact_check),
                  label: const Text('فحص اتساق البيانات'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseBackupDirectory(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'اختر مجلد النسخ الاحتياطي',
    );
    if (!context.mounted || directoryPath == null) return;
    await ref.read(useCasesProvider).setBackupDirectory(directoryPath);
    if (!context.mounted) return;
    _showSnack(context, 'تم اختيار مجلد النسخ الاحتياطي');
    _refresh(ref);
  }

  Future<void> _manualBackup(BuildContext context, WidgetRef ref) async {
    var directoryPath = snapshot.backupStatus.directory;
    if (directoryPath == null || directoryPath.trim().isEmpty) {
      directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مجلد النسخ الاحتياطي',
      );
      if (!context.mounted || directoryPath == null) return;
      await ref.read(useCasesProvider).setBackupDirectory(directoryPath);
    }
    try {
      final useCases = ref.read(useCasesProvider);
      final backup = await useCases.backupToDirectory(Directory(directoryPath));
      if (!context.mounted) return;
      _showSnack(context, 'تم إنشاء النسخة: ${_fileName(backup.path)}');
      _refresh(ref);
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'تعذر إنشاء النسخة: $error');
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'اختر ملف النسخة الاحتياطية',
      type: FileType.custom,
      allowedExtensions: ['db', 'zip'],
    );
    if (!context.mounted ||
        picked == null ||
        picked.files.single.path == null) {
      return;
    }
    final backupPath = picked.files.single.path!;
    final confirmed = await _confirm(
      context,
      title: 'استرجاع نسخة احتياطية',
      message:
          'سيتم استبدال البيانات الحالية بالنسخة ${_fileName(backupPath)}، وستفقد التغييرات التي تمت بعد تاريخها. سنفحص الملف أولًا ونحتفظ بنسخة رجوع. حزمة ZIP تعيد صور المنتجات أيضًا. بعد الاسترجاع ستعود إلى تسجيل الدخول.',
    );
    if (!confirmed || !context.mounted) return;
    final useCases = ref.read(useCasesProvider);
    final navigator = Navigator.of(context);
    final busyRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(
                child: Text('جارٍ فحص النسخة واسترجاعها. يرجى الانتظار.'),
              ),
            ],
          ),
        ),
      ),
    );
    unawaited(navigator.push(busyRoute));
    try {
      final backup = File(backupPath);
      if (backupPath.toLowerCase().endsWith('.zip')) {
        await useCases.restoreFromPortableBackup(backup);
      } else {
        await useCases.restoreFromBackup(backup);
      }
      if (!context.mounted) return;
      _showSnack(context, 'تم الاسترجاع. سجل الدخول لفتح بيانات النسخة.');
    } on FormatException catch (error) {
      if (!context.mounted) return;
      _showSnack(context, error.message);
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'تعذر الاسترجاع: $error');
    } finally {
      if (busyRoute.isActive) navigator.removeRoute(busyRoute);
      if (context.mounted && useCases.databaseClosedForRestore) {
        ref.read(currentOwnerProvider.notifier).setOwner(null);
        ref.invalidate(databaseProvider);
        ref.invalidate(bootstrapProvider);
      }
    }
  }

  Future<void> _portableBackup(BuildContext context, WidgetRef ref) async {
    var directoryPath = snapshot.backupStatus.directory;
    if (directoryPath == null || directoryPath.trim().isEmpty) {
      directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'اختر مجلد حفظ حزمة النقل',
      );
      if (!context.mounted || directoryPath == null) return;
      await ref.read(useCasesProvider).setBackupDirectory(directoryPath);
    }
    try {
      final bundle = await ref
          .read(useCasesProvider)
          .createPortableBackup(Directory(directoryPath));
      if (!context.mounted) return;
      _showSnack(context, 'تم إنشاء حزمة النقل: ${_fileName(bundle.path)}');
      _refresh(ref);
    } on FormatException catch (error) {
      if (!context.mounted) return;
      _showSnack(context, error.message);
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'تعذر إنشاء حزمة النقل: $error');
    }
  }

  Future<void> _auditData(BuildContext context, WidgetRef ref) {
    final audit = ref.read(useCasesProvider).dataIntegrityAudit();
    return showDialog<void>(
      context: context,
      builder: (_) => _IntegrityAuditDialog(audit: audit),
    );
  }
}
