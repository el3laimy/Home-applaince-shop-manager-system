part of '../v2_app.dart';

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _FatalScreen extends StatelessWidget {
  const _FatalScreen({required this.message, this.alreadyRunning = false});
  final bool alreadyRunning;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          alreadyRunning ? message : 'تعذر تشغيل قاعدة البيانات\n$message',
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

class _InitialOwnerScreen extends ConsumerStatefulWidget {
  const _InitialOwnerScreen();

  @override
  ConsumerState<_InitialOwnerScreen> createState() =>
      _InitialOwnerScreenState();
}
