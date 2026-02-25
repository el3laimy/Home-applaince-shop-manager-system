import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/main_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'controllers/auth_controller.dart';
import 'controllers/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  ApiService.initialize();

  // Setup Window Manager for Desktop Apps
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(1024, 768),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'ALIkhlasPOS',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Inject root-level controllers
  Get.put(AuthController());
  Get.put(ThemeController());

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = Get.find<ThemeController>();

    return Obx(() => GetMaterialApp(
      title: 'ALIkhlasPOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeCtrl.themeMode.value,

      home: Obx(() {
        final authCtrl = Get.find<AuthController>();
        if (authCtrl.isAuthenticated.value) {
          return const MainShell();
        } else {
          return const LoginScreen();
        }
      }),

      locale: const Locale('ar', 'EG'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        );
      },
    ));
  }
}


