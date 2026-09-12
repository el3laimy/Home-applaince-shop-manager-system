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

class _IntegrityAuditDialog extends StatelessWidget {
  const _IntegrityAuditDialog({required this.audit});

  final Future<DataIntegrityAudit> audit;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('فحص اتساق البيانات'),
      content: SizedBox(
        width: 640,
        child: FutureBuilder<DataIntegrityAudit>(
          future: audit,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 96,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const Text(
                'تعذر إكمال الفحص الآن. لم تُعدّل أي بيانات؛ أعد المحاولة بعد حفظ نسخة احتياطية.',
              );
            }
            final result = snapshot.data!;
            if (result.isConsistent) {
              return const Text(
                'لا توجد تعارضات في القيود أو المخزون أو خطط الأقساط. الفحص للقراءة فقط ولم يغير أي بيانات.',
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'وجد الفحص ${result.issues.length} ملاحظة. لا تعدّل السجلات يدويًا؛ أنشئ نسخة احتياطية ثم راجع الدعم أو قيد تصحيح موثق.',
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: result.issues.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final issue = result.issues[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.warning_amber_rounded),
                        title: Text(issue.record),
                        subtitle: Text(issue.message),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
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
  late final _barcodeWidth = TextEditingController(
    text: widget.snapshot.barcodeLabelSettings.widthMm.toString(),
  );
  late final _barcodeHeight = TextEditingController(
    text: widget.snapshot.barcodeLabelSettings.heightMm.toString(),
  );
  late String _backgroundPreset = widget.snapshot.uiBackground.preset;
  late String? _backgroundImagePath = widget.snapshot.uiBackground.imagePath;
  bool _saving = false;
  bool _openingBalanceSubmitting = false;
  bool _financialCorrectionSubmitting = false;
  bool _financialCorrectionReversalSubmitting = false;

  @override
  void dispose() {
    _shopName.dispose();
    _phone.dispose();
    _address.dispose();
    _footer.dispose();
    _barcodeWidth.dispose();
    _barcodeHeight.dispose();
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
                    'طباعة الباركود',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _barcodeWidth,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'عرض الملصق mm',
                            prefixIcon: Icon(Icons.width_normal),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _barcodeHeight,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ارتفاع الملصق mm',
                            prefixIcon: Icon(Icons.height),
                          ),
                        ),
                      ),
                    ],
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
            child: SingleChildScrollView(
              key: const ValueKey('settings-summary-scroll'),
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
                  _InfoLine(
                    'ملصق الباركود',
                    '${widget.snapshot.barcodeLabelSettings.widthMm} × ${widget.snapshot.barcodeLabelSettings.heightMm} mm',
                  ),
                  const Divider(height: 24),
                  _InfoLine(
                    'مجلد النسخ',
                    widget.snapshot.backupStatus.directory ?? 'لم يتم اختياره',
                  ),
                  _InfoLine(
                    'آخر نسخة تلقائية',
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
                  const Divider(height: 24),
                  Text(
                    'تهيئة محل قائم',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'أدخل أرصدة دفاترك القديمة قبل بدء العمل على الحساب. يرفض التطبيق الرصيد المكرر أو الحساب الذي عليه نشاط سابق.',
                    style: TextStyle(color: _mutedInk),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openingBalanceSubmitting
                        ? null
                        : _openOpeningBalance,
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: Text(
                      _openingBalanceSubmitting
                          ? 'جاري التسجيل...'
                          : 'إدخال رصيد افتتاحي',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'فرق ظهر بعد بدء العمل؟ سجّله كمستند مستقل للخزينة أو المحفظة مع سببه. لا تستخدمه لتعديل فاتورة أو مخزون أو مديونية طرف.',
                    style: TextStyle(color: _mutedInk),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _financialCorrectionSubmitting
                        ? null
                        : _openFinancialCorrection,
                    icon: const Icon(Icons.rule_folder_outlined),
                    label: Text(
                      _financialCorrectionSubmitting
                          ? 'جاري تسجيل التصحيح...'
                          : 'تصحيح خزينة أو محفظة',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _financialCorrectionReversalSubmitting
                        ? null
                        : _openFinancialCorrectionReversal,
                    icon: const Icon(Icons.undo_outlined),
                    label: Text(
                      _financialCorrectionReversalSubmitting
                          ? 'جاري تسجيل العكس...'
                          : 'عكس تصحيح مالي',
                    ),
                  ),
                ],
              ),
            ),
          );

          if (constraints.maxWidth < 860) {
            return SingleChildScrollView(
              key: const ValueKey('settings-page-scroll'),
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
    final barcodeWidth = _barcodeDimension(_barcodeWidth.text);
    final barcodeHeight = _barcodeDimension(_barcodeHeight.text);
    if (barcodeWidth == null || barcodeHeight == null) {
      _showSnack(context, 'أدخل أبعاد باركود صحيحة بالأرقام');
      return;
    }
    if (!_isBarcodeDimensionAllowed(barcodeWidth, barcodeHeight)) {
      _showSnack(
        context,
        'أبعاد ملصق الباركود يجب أن تكون ضمن الحدود المسموحة',
      );
      return;
    }
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
      final barcodeResult = await ref
          .read(useCasesProvider)
          .updateBarcodeLabelSettings(
            widthMm: barcodeWidth,
            heightMm: barcodeHeight,
          );
      if (barcodeResult is AppFailure<BarcodeLabelSettingsSnapshot>) {
        if (!mounted) return;
        _showSnack(context, barcodeResult.message);
        setState(() => _saving = false);
        return;
      }
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

  Future<void> _openOpeningBalance() async {
    final data = await showDialog<_OpeningBalanceFormData>(
      context: context,
      builder: (_) => _OpeningBalanceDialog(
        customers: widget.snapshot.customers,
        suppliers: widget.snapshot.suppliers,
      ),
    );
    if (!mounted || data == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الرصيد الافتتاحي'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoLine('النوع', data.type.label),
              if (data.partyName != null) _InfoLine('الطرف', data.partyName!),
              _InfoLine('القيمة', Money(data.amountMinor).format()),
              if (data.dueDate != null)
                _InfoLine('الاستحقاق', _date(data.dueDate!)),
              if (data.note != null) _InfoLine('التوضيح', data.note!),
              const SizedBox(height: 8),
              const Text(
                'بعد الاعتماد لا يمكن إدخال رصيد افتتاحي آخر لنفس الحساب. راجع القيمة والطرف من دفاترك القديمة.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('العودة للتعديل'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('اعتماد الرصيد'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _openingBalanceSubmitting = true);
    final useCases = ref.read(useCasesProvider);
    try {
      final result = await _submitPendingFinancialOperation(
        useCases,
        PendingFinancialOperation.openingBalance(
          operationKey: useCases.newOpeningBalanceOperationKey(),
          type: data.type,
          partyId: data.partyId,
          amountMinor: data.amountMinor,
          dueDate: data.dueDate,
          note: data.note,
        ),
        allowNegativeBalance: false,
      );
      if (!mounted) return;
      _showResult(context, result, success: 'تم تسجيل الرصيد الافتتاحي');
      _refresh(ref);
    } on Object {
      if (!mounted) return;
      _showSnack(
        context,
        'تعذر تسجيل الرصيد. لم نكرر العملية؛ أعد فتح التطبيق للتحقق من الطلب السابق.',
      );
    } finally {
      if (mounted) setState(() => _openingBalanceSubmitting = false);
    }
  }

  Future<void> _openFinancialCorrection() async {
    final data = await showDialog<_FinancialCorrectionFormData>(
      context: context,
      builder: (_) => const _FinancialCorrectionDialog(),
    );
    if (!mounted || data == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد التصحيح المالي'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoLine('الحساب', data.target.label),
              _InfoLine(
                'النتيجة',
                data.increasesBalance ? 'زيادة فعلية' : 'عجز فعلي',
              ),
              _InfoLine('القيمة', Money(data.amountMinor).format()),
              _InfoLine('السبب', data.reason),
              if (data.note != null) _InfoLine('التوضيح', data.note!),
              const SizedBox(height: 8),
              const Text(
                'سيسجل التطبيق مستندًا وقيدًا محاسبيًا متزنًا. لا يمكن لهذا التصحيح تغيير فواتير البيع أو الشراء أو المخزون أو أرصدة العملاء والموردين.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('العودة للتعديل'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('اعتماد التصحيح'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _financialCorrectionSubmitting = true);
    final useCases = ref.read(useCasesProvider);
    final request = PendingFinancialOperation.financialCorrection(
      operationKey: useCases.newFinancialCorrectionOperationKey(),
      target: data.target,
      amountMinor: data.amountMinor,
      increasesBalance: data.increasesBalance,
      reason: data.reason,
      note: data.note,
    );
    try {
      final result = await _runWithNegativeBalanceApproval(
        context,
        action: (allowNegativeBalance) => _submitPendingFinancialOperation(
          useCases,
          request,
          allowNegativeBalance: allowNegativeBalance,
        ),
        onConfirmationDeclined: () => useCases
            .discardUncommittedPendingFinancialOperation(request.operationKey)
            .then((_) {}),
      );
      if (!mounted) return;
      _showResult(context, result, success: 'تم تسجيل التصحيح المالي');
      _refresh(ref);
    } on Object {
      if (!mounted) return;
      _showSnack(
        context,
        'تعذر تسجيل التصحيح. لم نكرر العملية؛ أعد فتح التطبيق للتحقق من الطلب السابق.',
      );
    } finally {
      if (mounted) setState(() => _financialCorrectionSubmitting = false);
    }
  }

  Future<void> _openFinancialCorrectionReversal() async {
    final useCases = ref.read(useCasesProvider);
    final corrections = await useCases.reversibleFinancialCorrections();
    if (!mounted) return;
    if (corrections.isEmpty) {
      _showSnack(context, 'لا توجد تصحيحات مالية متاحة للعكس');
      return;
    }
    final data = await showDialog<_FinancialCorrectionReversalFormData>(
      context: context,
      builder: (_) =>
          _FinancialCorrectionReversalDialog(corrections: corrections),
    );
    if (!mounted || data == null) return;
    final target = FinancialCorrectionTarget.values.byName(
      data.correction.target,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد عكس التصحيح المالي'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoLine('المستند الأصلي', '#${data.correction.id}'),
              _InfoLine('الحساب', target.label),
              _InfoLine(
                'القيمة',
                Money(data.correction.deltaMinor.abs()).format(),
              ),
              _InfoLine('سبب العكس', data.reason),
              if (data.note != null) _InfoLine('التوضيح', data.note!),
              const SizedBox(height: 8),
              const Text(
                'سيُحفظ المستند الأصلي ويُضاف قيد معاكس مستقل. لا يمكن عكس التصحيح نفسه مرة ثانية.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('العودة للتعديل'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('اعتماد العكس'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _financialCorrectionReversalSubmitting = true);
    final request = PendingFinancialOperation.financialCorrectionReversal(
      operationKey: useCases.newFinancialCorrectionReversalOperationKey(),
      correctionId: data.correction.id,
      reason: data.reason,
      note: data.note,
    );
    try {
      final result = await _runWithNegativeBalanceApproval(
        context,
        action: (allowNegativeBalance) => _submitPendingFinancialOperation(
          useCases,
          request,
          allowNegativeBalance: allowNegativeBalance,
        ),
        onConfirmationDeclined: () => useCases
            .discardUncommittedPendingFinancialOperation(request.operationKey)
            .then((_) {}),
      );
      if (!mounted) return;
      _showResult(context, result, success: 'تم تسجيل عكس التصحيح المالي');
      _refresh(ref);
    } on Object {
      if (!mounted) return;
      _showSnack(
        context,
        'تعذر تسجيل العكس. لم نكرر العملية؛ أعد فتح التطبيق للتحقق من الطلب السابق.',
      );
    } finally {
      if (mounted) {
        setState(() => _financialCorrectionReversalSubmitting = false);
      }
    }
  }

  int? _barcodeDimension(String value) {
    final dimension = int.tryParse(value.trim());
    return dimension == null || dimension <= 0 ? null : dimension;
  }

  bool _isBarcodeDimensionAllowed(int widthMm, int heightMm) {
    return widthMm >= BarcodeLabelSettingsSnapshot.minWidthMm &&
        widthMm <= BarcodeLabelSettingsSnapshot.maxWidthMm &&
        heightMm >= BarcodeLabelSettingsSnapshot.minHeightMm &&
        heightMm <= BarcodeLabelSettingsSnapshot.maxHeightMm;
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
