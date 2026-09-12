part of '../v2_app.dart';

class _RecoveryAccessDialog extends ConsumerStatefulWidget {
  const _RecoveryAccessDialog();

  @override
  ConsumerState<_RecoveryAccessDialog> createState() =>
      _RecoveryAccessDialogState();
}

class _RecoveryAccessDialogState extends ConsumerState<_RecoveryAccessDialog> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  OwnerRecovery? _recovery;
  String? _error;
  var _saving = false;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_recovery == null ? 'استعادة الوصول' : 'رمز الاستعادة الجديد'),
    content: SizedBox(
      width: 380,
      child: _recovery == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('أدخل رمز الاستعادة الذي حفظته عند إعداد المحل.'),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'رمز الاستعادة'),
                ),
                const SizedBox(height: 12),
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
                  onSubmitted: (_) => _recover(),
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تم تغيير كلمة المرور. احفظ هذا الرمز الجديد؛ الرمز السابق لم يعد صالحًا.',
                ),
                const SizedBox(height: 16),
                SelectableText(
                  _recovery!.recoveryCode,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
    ),
    actions: _recovery == null
        ? [
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: _saving ? null : _recover,
              child: Text(_saving ? 'جارٍ الاستعادة...' : 'تأكيد'),
            ),
          ]
        : [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حفظت الرمز، عودة للدخول'),
            ),
          ],
  );

  Future<void> _recover() async {
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
        .recoverOwnerAccess(
          recoveryCode: _code.text,
          newPassword: _password.text,
        );
    if (!mounted) return;
    switch (result) {
      case AppSuccess<OwnerRecovery>(value: final recovery):
        setState(() => _recovery = recovery);
      case AppFailure<OwnerRecovery>(message: final message):
        setState(() => _error = message);
    }
    if (mounted) setState(() => _saving = false);
  }
}
