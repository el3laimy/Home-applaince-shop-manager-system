part of '../v2_app.dart';

class _ChangePasswordScreen extends ConsumerStatefulWidget {
  const _ChangePasswordScreen();

  @override
  ConsumerState<_ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<_ChangePasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  OwnerRecovery? _recovery;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassStage(
      child: Center(
        child: _GlassPane(
          width: 460,
          padding: const EdgeInsets.all(28),
          enableBlur: true,
          child: _recovery == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'تغيير كلمة المرور',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'لا يمكن استخدام التطبيق بكلمة المرور الافتراضية.',
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirm,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                      ),
                      onSubmitted: (_) => _changePassword(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _changePassword,
                      child: Text(_loading ? 'جاري الحفظ...' : 'حفظ ومتابعة'),
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
                      _recovery!.recoveryCode,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _finish,
                      child: const Text('حفظت الرمز، ابدأ العمل'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = 'تأكيد كلمة المرور غير مطابق');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final owner = ref.read(currentOwnerProvider)!;
    final result = await ref
        .read(useCasesProvider)
        .changePasswordAndIssueRecoveryCode(owner.id, _password.text);
    if (!mounted) return;
    switch (result) {
      case AppSuccess<OwnerRecovery>(value: final recovery):
        setState(() => _recovery = recovery);
      case AppFailure<OwnerRecovery>(message: final message):
        setState(() => _error = message);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _finish() {
    final recovery = _recovery;
    if (recovery == null) return;
    ref.read(currentOwnerProvider.notifier).setOwner(recovery.owner);
  }
}
