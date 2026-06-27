part of '../v2_app.dart';

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _FatalScreen extends StatelessWidget {
  const _FatalScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'تعذر تشغيل قاعدة البيانات\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _LoginScreen extends ConsumerStatefulWidget {
  const _LoginScreen();

  @override
  ConsumerState<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<_LoginScreen> {
  final _username = TextEditingController(text: 'owner');
  final _password = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassStage(
      child: Center(
        child: _GlassPane(
          width: 440,
          padding: const EdgeInsets.all(28),
          enableBlur: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'إخلاص POS',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text('نسخة أوفلاين واحدة للمالك'),
              const SizedBox(height: 24),
              TextField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'اسم المستخدم'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _login,
                child: Text(_loading ? 'جاري الدخول...' : 'دخول'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(useCasesProvider)
        .login(_username.text, _password.text);
    if (!mounted) return;
    switch (result) {
      case AppSuccess<User>(value: final owner):
        ref.read(currentOwnerProvider.notifier).setOwner(owner);
      case AppFailure<User>(message: final message):
        setState(() => _error = message);
    }
    if (mounted) setState(() => _loading = false);
  }
}

class _ChangePasswordScreen extends ConsumerStatefulWidget {
  const _ChangePasswordScreen();

  @override
  ConsumerState<_ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<_ChangePasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تغيير كلمة المرور',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('لا يمكن استخدام التطبيق بكلمة المرور الافتراضية.'),
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
        .changePassword(owner.id, _password.text);
    if (!mounted) return;
    switch (result) {
      case AppSuccess<User>(value: final updatedOwner):
        ref.read(currentOwnerProvider.notifier).setOwner(updatedOwner);
      case AppFailure<User>(message: final message):
        setState(() => _error = message);
    }
    if (mounted) setState(() => _loading = false);
  }
}
