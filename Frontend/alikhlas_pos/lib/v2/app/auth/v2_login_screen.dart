part of '../v2_app.dart';

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
              TextButton(
                onPressed: _loading
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (_) => const _RecoveryAccessDialog(),
                      ),
                child: const Text('نسيت كلمة المرور؟'),
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
