import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'v2/app/v2_app.dart';
import 'v2/data/app_database.dart';
import 'v2/data/application_lock.dart';
import 'v2/application/v2_diagnostic_logger.dart';

void main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  await V2DiagnosticLogger.shared();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    recordV2DiagnosticError(
      module: 'flutter',
      event: 'framework_error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    recordV2DiagnosticError(
      module: 'dart',
      event: 'uncaught_async_error',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  };
  if (arguments.length == 1 && arguments.single == '--installer-smoke-check') {
    try {
      await _runInstallerSmokeCheck();
      exit(0);
    } on Object catch (error, stackTrace) {
      stderr.writeln('Installer smoke check failed: $error');
      stderr.writeln(stackTrace);
      exit(1);
    }
  }
  await ensureArabicFormatting();

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(1024, 720),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.normal,
    title: 'ALIkhlasPOS v2',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: ALIkhlasV2App()));
}

/// Opens the installed application's real data path and exits without creating
/// shop data. Release CI uses this to prove that an installer can launch its
/// packaged runtime and open or migrate SQLite successfully.
Future<void> _runInstallerSmokeCheck() async {
  final database = AppDatabase();
  try {
    final quickCheck = await database.customSelect('PRAGMA quick_check').get();
    if (quickCheck.length != 1 ||
        quickCheck.single.data.values.single != 'ok') {
      throw StateError('SQLite quick_check failed after installation.');
    }
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    if (version.data['user_version'] != kAppDatabaseSchemaVersion) {
      throw StateError('Installed database schema is not current.');
    }
  } finally {
    await database.close();
    await ApplicationLock.release();
  }
}
