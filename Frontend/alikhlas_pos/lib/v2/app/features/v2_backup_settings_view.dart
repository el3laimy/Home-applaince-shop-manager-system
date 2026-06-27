part of '../v2_app.dart';

class _BackupView extends ConsumerWidget {
  const _BackupView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupStatus = snapshot.backupStatus;
    return _Screen(
      title: 'النسخ الاحتياطي',
      subtitle: 'نسخة يدوية ويومية تلقائية عند اختيار مجلد',
      child: _GlassPane(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoLine('مجلد النسخ', backupStatus.directory ?? 'لم يتم اختياره'),
            _InfoLine('آخر نسخة يومية', backupStatus.lastDate ?? 'لا يوجد'),
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
                  onPressed: () => _chooseBackupDirectory(context, ref),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('اختيار المجلد'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _restoreBackup(context, ref),
                  icon: const Icon(Icons.restore),
                  label: const Text('استرجاع نسخة'),
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
      allowedExtensions: ['db'],
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
          'سيتم استبدال قاعدة البيانات الحالية بالملف ${_fileName(backupPath)}. تأكد أن لديك نسخة حديثة قبل المتابعة، ثم أعد تشغيل التطبيق بعد الاسترجاع.',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(useCasesProvider).restoreFromBackup(File(backupPath));
      if (!context.mounted) return;
      _showSnack(
        context,
        'تم الاسترجاع. أعد تشغيل التطبيق لفتح الملف المسترجع.',
      );
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'تعذر الاسترجاع: $error');
    }
  }
}

class _SettingsView extends ConsumerStatefulWidget {
  const _SettingsView({required this.snapshot});
  final WorkbenchSnapshot snapshot;

  @override
  ConsumerState<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<_SettingsView> {
  late final _shopName = TextEditingController(
    text: widget.snapshot.shopSettings.shopName,
  );
  late final _phone = TextEditingController(
    text: widget.snapshot.shopSettings.phone ?? '',
  );
  late final _address = TextEditingController(
    text: widget.snapshot.shopSettings.address ?? '',
  );
  late final _footer = TextEditingController(
    text: widget.snapshot.shopSettings.receiptFooter ?? '',
  );
  late String _backgroundPreset = widget.snapshot.uiBackground.preset;
  late String? _backgroundImagePath = widget.snapshot.uiBackground.imagePath;
  bool _saving = false;

  @override
  void dispose() {
    _shopName.dispose();
    _phone.dispose();
    _address.dispose();
    _footer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Screen(
      title: 'الإعدادات',
      subtitle: 'بيانات المحل والفاتورة والنسخ الاحتياطي',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final form = _GlassPane(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'بيانات المحل',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _shopName,
                    decoration: const InputDecoration(labelText: 'اسم المحل'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'الهاتف'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _footer,
                    decoration: const InputDecoration(
                      labelText: 'تذييل الفاتورة',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'خلفية التطبيق',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _backgroundPreset,
                    decoration: const InputDecoration(labelText: 'النمط'),
                    items: const [
                      DropdownMenuItem(
                        value: 'aurora',
                        child: Text('Aurora زجاجي'),
                      ),
                      DropdownMenuItem(value: 'sky', child: Text('سماء هادئة')),
                      DropdownMenuItem(
                        value: 'blush',
                        child: Text('وردي ناعم'),
                      ),
                      DropdownMenuItem(
                        value: 'graphite',
                        child: Text('رمادي احترافي'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _backgroundPreset = value ?? 'aurora'),
                  ),
                  const SizedBox(height: 10),
                  _BackgroundImagePicker(
                    imagePath: _backgroundImagePath,
                    onPick: _pickBackgroundImage,
                    onClear: () => setState(() => _backgroundImagePath = null),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save),
                      label: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
                    ),
                  ),
                ],
              ),
            ),
          );
          final summary = _GlassPane(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'ملخص التشغيل',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _InfoLine('اسم المحل', widget.snapshot.shopSettings.shopName),
                _InfoLine(
                  'الهاتف',
                  widget.snapshot.shopSettings.phone ?? 'غير مسجل',
                ),
                _InfoLine(
                  'العنوان',
                  widget.snapshot.shopSettings.address ?? 'غير مسجل',
                ),
                _InfoLine(
                  'الخلفية',
                  _backgroundLabel(widget.snapshot.uiBackground.preset),
                ),
                _InfoLine(
                  'صورة الخلفية',
                  widget.snapshot.uiBackground.imagePath == null
                      ? 'لا توجد'
                      : _fileName(widget.snapshot.uiBackground.imagePath!),
                ),
                const Divider(height: 24),
                _InfoLine(
                  'مجلد النسخ',
                  widget.snapshot.backupStatus.directory ?? 'لم يتم اختياره',
                ),
                _InfoLine(
                  'آخر نسخة يومية',
                  widget.snapshot.backupStatus.lastDate ?? 'لا يوجد',
                ),
                _InfoLine(
                  'آخر ملف',
                  widget.snapshot.backupStatus.latestBackupPath == null
                      ? 'لا يوجد'
                      : _fileName(
                          widget.snapshot.backupStatus.latestBackupPath!,
                        ),
                ),
                _InfoLine(
                  'الاحتفاظ',
                  '${widget.snapshot.backupStatus.backupCount}/${widget.snapshot.backupStatus.retentionCopies} نسخة',
                ),
              ],
            ),
          );

          if (constraints.maxWidth < 860) {
            return SingleChildScrollView(
              child: Column(
                children: [form, const SizedBox(height: 14), summary],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: form),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: summary),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await ref
        .read(useCasesProvider)
        .updateShopSettings(
          shopName: _shopName.text,
          phone: _phone.text,
          address: _address.text,
          receiptFooter: _footer.text,
        );
    if (result is AppSuccess<ShopSettingsSnapshot>) {
      await ref
          .read(useCasesProvider)
          .updateUiBackground(
            preset: _backgroundPreset,
            imagePath: _backgroundImagePath,
          );
    }
    if (!mounted) return;
    _showResult(context, result, success: 'تم حفظ الإعدادات');
    setState(() => _saving = false);
    _refresh(ref);
  }

  Future<void> _pickBackgroundImage() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'اختر صورة خلفية التطبيق',
      type: FileType.image,
    );
    if (!mounted || picked == null || picked.files.single.path == null) return;
    try {
      final localPath = await LocalImageStore.copyBackgroundImage(
        picked.files.single.path!,
      );
      if (!mounted) return;
      setState(() => _backgroundImagePath = localPath);
    } on FileSystemException {
      if (!context.mounted) return;
      _showSnack(
        context,
        'تعذر حفظ صورة الخلفية. اختر ملف صورة PNG أو JPG أو WEBP',
      );
    } on ArgumentError {
      if (!context.mounted) return;
      _showSnack(
        context,
        'تعذر حفظ صورة الخلفية. اختر ملف صورة PNG أو JPG أو WEBP',
      );
    }
  }
}
