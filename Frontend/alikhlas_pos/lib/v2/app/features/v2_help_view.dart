part of '../v2_app.dart';

class _HelpView extends ConsumerStatefulWidget {
  const _HelpView({required this.snapshot});

  final WorkbenchSnapshot snapshot;

  @override
  ConsumerState<_HelpView> createState() => _HelpViewState();
}

class _HelpViewState extends ConsumerState<_HelpView> {
  bool _savingReport = false;
  bool _printingTest = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final backup = widget.snapshot.backupStatus;
    final version = ref.watch(appVersionProvider);
    return _Screen(
      title: 'المساعدة وحالة التطبيق',
      subtitle: 'راجع الحالة أولًا، ثم احفظ تقريرًا آمنًا إذا احتجت مساعدة',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _QuickStartGuide(),
            const SizedBox(height: 14),
            _GlassPane(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'قبل طلب المساعدة',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _InfoLine(
                    'نسخة التطبيق',
                    version.when(
                      data: (value) => value,
                      loading: () => 'جارٍ القراءة...',
                      error: (_, _) => 'غير متاح',
                    ),
                  ),
                  const _HelpStep(
                    number: '1',
                    text:
                        'إذا لم تكن متأكدًا هل سُجلت عملية، افتح الفاتورة أو كشف الحساب أولًا. لا تسجلها مرة ثانية.',
                  ),
                  const _HelpStep(
                    number: '2',
                    text:
                        'أنشئ نسخة احتياطية من شاشة النسخ قبل أي استرجاع أو تعديل مهم.',
                  ),
                  const _HelpStep(
                    number: '3',
                    text:
                        'إذا تعذر الطباعة بعد الحفظ، ابحث عن الفاتورة وأعد طباعتها؛ لا تحتاج لتسجيل بيع جديد.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _GlassPane(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'حالة النسخ الاحتياطي',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _InfoLine(
                    'وجهة النسخ',
                    backup.directory == null
                        ? 'لم يتم اختيارها'
                        : 'تم اختيارها',
                  ),
                  _InfoLine(
                    'تاريخ آخر نسخة تلقائية ناجحة',
                    V2SupportDiagnostics.backupDate(backup.lastDate),
                  ),
                  _InfoLine(
                    'عدد النسخ',
                    '${backup.backupCount} من ${backup.retentionCopies}',
                  ),
                  if (backup.warning != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      backup.warning!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            _GlassPane(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'اختبار الطابعة',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'اختر طابعتك من نافذة النظام لتجربة صفحة عربية بحجم A4. جرّب الإيصالات والباركود بحجمهما الفعلي أيضًا قبل بدء العمل. يمكنك إجراء الاختبار لاحقًا دون تسجيل أي عملية.',
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _printingTest ? null : _printTestPage,
                      icon: _printingTest
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print_outlined),
                      label: Text(
                        _printingTest
                            ? 'جارٍ فتح الطباعة...'
                            : 'اختبار الطابعة',
                      ),
                    ),
                  ),
                  const Divider(height: 28),
                  Text(
                    'تقرير للدعم',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ستراجع محتوى التقرير قبل حفظه: نسخة التطبيق وإصدار قاعدة البيانات والنظام وحالة النسخ. لا يتضمن قاعدة البيانات أو الفواتير أو العملاء أو كلمات المرور، ولا يُرسل تلقائيًا.',
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _savingReport ? null : _exportDiagnostics,
                      icon: const Icon(Icons.save_alt),
                      label: Text(
                        _savingReport
                            ? 'جارٍ حفظ التقرير...'
                            : 'حفظ تقرير للدعم',
                      ),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(_message!),
                  ],
                  const Divider(height: 28),
                  Text(
                    'التراخيص والحقوق',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'يعرض التطبيق تراخيص Flutter والمكتبات مفتوحة المصدر المضمّنة في هذه النسخة.',
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => showLicensePage(
                        context: context,
                        applicationName: 'إخلاص POS',
                        applicationVersion: version.asData?.value,
                        applicationIcon: const Icon(
                          Icons.storefront_outlined,
                          size: 42,
                        ),
                      ),
                      icon: const Icon(Icons.policy_outlined),
                      label: const Text('تراخيص البرامج المستخدمة'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printTestPage() async {
    setState(() {
      _printingTest = true;
      _message = null;
    });
    try {
      final accepted = await ref.read(printerTestPageProvider)(
        widget.snapshot.shopSettings,
      );
      if (!mounted) return;
      setState(
        () => _message = accepted
            ? 'أُرسل طلب الطباعة. تأكد بنفسك من خروج الصفحة ووضوح العربية؛ نجاح الطلب لا يؤكد خروج الورق.'
            : 'لم تكتمل الطباعة. يمكنك إعادة الاختبار عندما تكون الطابعة جاهزة.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message =
            'تعذر فتح نافذة الطباعة. تأكد من توصيل الطابعة ثم حاول مرة أخرى.',
      );
    } finally {
      if (mounted) setState(() => _printingTest = false);
    }
  }

  Future<void> _exportDiagnostics() async {
    setState(() {
      _savingReport = true;
      _message = null;
    });
    try {
      final saveReport = ref.read(supportReportSaverProvider);
      final schemaVersion = ref.read(databaseProvider).schemaVersion;
      final backupStatus = widget.snapshot.backupStatus;
      final createdAt = ref.read(appClockProvider)();
      final version = await ref.read(appVersionProvider.future);
      if (!mounted) return;
      final report =
          V2SupportDiagnostics(
            appVersion: version,
            schemaVersion: schemaVersion,
          ).create(
            backupStatus: backupStatus,
            operatingSystem: Platform.operatingSystem,
            createdAt: createdAt,
          );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('معاينة تقرير الدعم'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(child: SelectableText(report)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('اختيار مكان الحفظ'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final saved = await saveReport(report);
      if (!saved) return;
      if (!mounted) return;
      setState(
        () => _message =
            'تم حفظ تقرير الدعم. راجعه ثم أرسله لجهة الدعم التي تتعامل معها.',
      );
    } on FileSystemException {
      if (!mounted) return;
      setState(
        () => _message =
            'تعذر حفظ التقرير في هذا المكان. اختر مجلدًا تملك صلاحية الكتابة فيه.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message =
            'تعذر تجهيز تقرير الدعم الآن. أغلق النافذة وحاول مرة أخرى.',
      );
    } finally {
      if (mounted) setState(() => _savingReport = false);
    }
  }
}

class _QuickStartGuide extends StatelessWidget {
  const _QuickStartGuide();

  static const _steps = <_GuideStep>[
    _GuideStep(
      number: '١',
      icon: Icons.storefront_outlined,
      title: 'جهّز المحل',
      text: 'راجع اسم المحل وبيانات الفاتورة، ثم اختر مكان النسخ الاحتياطي.',
      destination: 'الإعدادات',
    ),
    _GuideStep(
      number: '٢',
      icon: Icons.lock_open_outlined,
      title: 'افتح اليومية',
      text: 'سجّل المبلغ الموجود في الدرج قبل أول بيع نقدي.',
      destination: 'اليومية',
    ),
    _GuideStep(
      number: '٣',
      icon: Icons.point_of_sale_outlined,
      title: 'سجّل البيع',
      text: 'اختر الأصناف وطريقة الدفع، وراجع الإجمالي قبل الحفظ.',
      destination: 'البيع',
    ),
    _GuideStep(
      number: '٤',
      icon: Icons.receipt_long_outlined,
      title: 'تابع ما بعد البيع',
      text: 'حصّل الدفعات من الأقساط، وابدأ أي مرتجع من الفاتورة الأصلية.',
      destination: 'الأقساط والمرتجعات',
    ),
    _GuideStep(
      number: '٥',
      icon: Icons.verified_user_outlined,
      title: 'احمِ بياناتك',
      text: 'تأكد من تاريخ آخر نسخة ناجحة، وأنشئ نسخة قبل أي استرجاع.',
      destination: 'النسخ',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _GlassPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'دليل يوم العمل في ٥ خطوات',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'اتبع المسار بالترتيب في أول يوم، ثم ارجع إلى الخطوة التي تحتاجها.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1400
                  ? 5
                  : constraints.maxWidth >= 620
                  ? 3
                  : 1;
              const gap = 12.0;
              final cardWidth =
                  (constraints.maxWidth - (columns - 1) * gap) / columns;
              final cardHeight = columns == 5
                  ? 190.0
                  : columns == 3
                  ? (constraints.maxWidth < 800 ? 245.0 : 220.0)
                  : 230.0;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final step in _steps)
                    SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: _QuickStartCard(step: step),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickStartCard extends StatelessWidget {
  const _QuickStartCard({required this.step});

  final _GuideStep step;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'الخطوة ${step.number}: ${step.title}. ${step.text}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 178),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(step.icon, color: colors.onPrimaryContainer),
                ),
                const Spacer(),
                Text(
                  step.number,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              step.title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(step.text, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            const SizedBox(height: 10),
            Text(
              'من شاشة: ${step.destination}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep {
  const _GuideStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.text,
    required this.destination,
  });

  final String number;
  final IconData icon;
  final String title;
  final String text;
  final String destination;
}

class _HelpStep extends StatelessWidget {
  const _HelpStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            child: Text(number, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
