part of '../v2_app.dart';

class _InitialOwnerScreenState extends ConsumerState<_InitialOwnerScreen> {
  final _shopName = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  InitialOwnerSetup? _setup;
  String? _backupDirectory;
  String? _backupNotice;
  String? _printerNotice;
  String? _error;
  var _saving = false;
  var _restoring = false;
  var _testingPrinter = false;

  @override
  void dispose() {
    _shopName.dispose();
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _GlassStage(
    child: Center(
      child: _GlassPane(
        width: 460,
        padding: const EdgeInsets.all(28),
        enableBlur: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height - 112,
          ),
          child: SingleChildScrollView(
            child: _setup == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'إعداد المحل',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text('أنشئ كلمة مرور المالك قبل بدء العمل.'),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _shopName,
                        decoration: const InputDecoration(
                          labelText: 'اسم المحل',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'اسم المالك',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'كلمة المرور',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirm,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'تأكيد كلمة المرور',
                        ),
                        onSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'النسخ الاحتياطي (اختياري)',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _backupDirectory == null
                            ? 'يمكنك اختيار مجلد الآن أو ضبطه لاحقًا من شاشة النسخ الاحتياطي.'
                            : 'تم اختيار مجلد للنسخ الاحتياطي.',
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving || _restoring || _testingPrinter
                            ? null
                            : _pickBackupDirectory,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('اختيار مجلد النسخ'),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'الطابعة (اختياري)',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'اختبر صفحة عربية A4 الآن، أو أكمل واضبط الطابعة لاحقًا من شاشة المساعدة.',
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving || _restoring || _testingPrinter
                            ? null
                            : _testInitialPrinter,
                        icon: _testingPrinter
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.print_outlined),
                        label: Text(
                          _testingPrinter
                              ? 'جارٍ فتح الطباعة...'
                              : 'اختبار الطابعة الآن',
                        ),
                      ),
                      if (_printerNotice != null) ...[
                        const SizedBox(height: 6),
                        Text(_printerNotice!),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving || _restoring || _testingPrinter
                            ? null
                            : _save,
                        child: Text(_saving ? 'جارٍ الحفظ...' : 'ابدأ العمل'),
                      ),
                      TextButton.icon(
                        onPressed: _saving || _restoring || _testingPrinter
                            ? null
                            : _restoreExistingShop,
                        icon: const Icon(Icons.restore),
                        label: Text(
                          _restoring
                              ? 'جارٍ استرجاع النسخة...'
                              : 'لدي نسخة احتياطية سابقة',
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'احفظ رمز الاستعادة',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'احتفظ بهذا الرمز في مكان آمن. يظهر مرة واحدة ويستخدم عند نسيان كلمة المرور.',
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        _setup!.recoveryCode,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (_backupNotice != null) ...[
                        const SizedBox(height: 12),
                        Text(_backupNotice!),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _finishSetup,
                        child: const Text('حفظت الرمز، ابدأ العمل'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );

  Future<void> _save() async {
    if (_saving || _restoring || _testingPrinter) return;
    if (_password.text != _confirm.text) {
      setState(() => _error = 'تأكيد كلمة المرور غير مطابق');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(useCasesProvider)
        .setupInitialOwner(
          fullName: _name.text,
          password: _password.text,
          shopName: _shopName.text,
        );
    if (!mounted) return;
    switch (result) {
      case AppSuccess<InitialOwnerSetup>(value: final setup):
        final backupNotice = await _configureInitialBackup();
        if (!mounted) return;
        setState(() {
          _setup = setup;
          _backupNotice = backupNotice;
        });
      case AppFailure<InitialOwnerSetup>(message: final message):
        setState(() => _error = message);
    }
    if (mounted) setState(() => _saving = false);
  }

  void _finishSetup() {
    final setup = _setup;
    if (setup == null) return;
    ref.read(currentOwnerProvider.notifier).setOwner(setup.owner);
    ref.invalidate(initialOwnerRequiredProvider);
  }

  Future<void> _pickBackupDirectory() async {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'اختر مجلد النسخ الاحتياطي',
    );
    if (mounted && directory != null) {
      setState(() => _backupDirectory = directory);
    }
  }

  Future<void> _testInitialPrinter() async {
    if (_testingPrinter || _saving || _restoring) return;
    final shopName = _shopName.text.trim();
    if (shopName.isEmpty) {
      setState(
        () => _error = 'أدخل اسم المحل أولًا لاستخدامه في صفحة الاختبار.',
      );
      return;
    }
    final print = ref.read(printerTestPageProvider);
    setState(() {
      _testingPrinter = true;
      _printerNotice = null;
      _error = null;
    });
    try {
      final accepted = await print(ShopSettingsSnapshot(shopName: shopName));
      if (!mounted) return;
      setState(
        () => _printerNotice = accepted
            ? 'أُرسل طلب الطباعة. تأكد من خروج الصفحة ووضوح العربية، ثم جرّب الإيصال والباركود بالحجم الفعلي.'
            : 'لم تكتمل الطباعة. يمكنك إعادة الاختبار أو ضبط الطابعة لاحقًا من شاشة المساعدة.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _printerNotice =
            'تعذر فتح نافذة الطباعة. يمكنك إكمال الإعداد وضبط الطابعة لاحقًا.',
      );
    } finally {
      if (mounted) setState(() => _testingPrinter = false);
    }
  }

  Future<String> _configureInitialBackup() async {
    final directory = _backupDirectory;
    if (directory == null || directory.trim().isEmpty) {
      return 'لم يتم اختيار مجلد للنسخ. يمكنك ضبطه لاحقًا من شاشة النسخ الاحتياطي.';
    }

    final useCases = ref.read(useCasesProvider);
    try {
      await useCases.setBackupDirectory(directory);
      final backup = await useCases.tryAutomaticBackup();
      if (backup != null) {
        return 'تم إنشاء النسخة الاحتياطية الأولى في المجلد المختار.';
      }
      return useCases.backupWarning ??
          'تم حفظ المجلد. ستتم محاولة النسخ تلقائيًا عند تشغيل التطبيق.';
    } catch (_) {
      return 'تم إنشاء حساب المالك، لكن تعذر ضبط النسخ الآن. اضبطه من شاشة النسخ الاحتياطي.';
    }
  }

  Future<void> _restoreExistingShop() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'اختر النسخة الاحتياطية للمحل',
      type: FileType.custom,
      allowedExtensions: ['db', 'zip'],
    );
    if (!mounted || picked == null || picked.files.single.path == null) return;

    final backupPath = picked.files.single.path!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استرجاع محل سابق'),
        content: const Text(
          'سيستبدل هذا بيانات الإعداد الحالي ببيانات النسخة المختارة. سنفحص الملف أولًا ونحتفظ بنسخة رجوع قبل الاستبدال.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('استرجاع النسخة'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() {
      _restoring = true;
      _error = null;
    });
    final useCases = ref.read(useCasesProvider);
    try {
      final backup = File(backupPath);
      if (backupPath.toLowerCase().endsWith('.zip')) {
        await useCases.restoreFromPortableBackup(backup);
      } else {
        await useCases.restoreFromBackup(backup);
      }
      if (!mounted) return;
      ref.read(currentOwnerProvider.notifier).setOwner(null);
      ref.invalidate(databaseProvider);
      ref.invalidate(bootstrapProvider);
      ref.invalidate(initialOwnerRequiredProvider);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'تعذر استرجاع النسخة. تأكد من اختيار نسخة المحل السليمة.',
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }
}
