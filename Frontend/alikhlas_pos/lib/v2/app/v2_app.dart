import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';

import '../application/v2_use_cases.dart';
import '../application/v2_support_diagnostics.dart';
import '../core/money.dart';
import '../core/result.dart';
import '../data/app_database.dart';
import '../data/application_lock.dart';
import '../printing/barcode_labels_pdf.dart';
import '../printing/party_statement_pdf.dart';
import '../printing/report_summary_pdf.dart';
import 'app_theme.dart';
import 'design_tokens.dart';
import 'local_image_store.dart';
import 'v2_providers.dart';

part 'auth/v2_auth.dart';
part 'shell/v2_shell.dart';
part 'features/v2_daily_view.dart';
part 'features/v2_pos_view.dart';
part 'features/v2_inventory_view.dart';
part 'features/v2_parties_view.dart';
part 'features/v2_purchase_view.dart';
part 'features/v2_installments_view.dart';
part 'features/v2_returns_view.dart';
part 'features/v2_reports_view.dart';
part 'features/v2_backup_settings_view.dart';
part 'features/v2_help_view.dart';
part 'shared/v2_visual.dart';
part 'shared/v2_cart_product_widgets.dart';
part 'shared/v2_party_widgets.dart';
part 'shared/v2_report_widgets.dart';
part 'shared/v2_daily_widgets.dart';
part 'shared/v2_statement_widgets.dart';
part 'shared/v2_dialogs.dart';
part 'shared/v2_product_dialogs.dart';
part 'shared/v2_inventory_adjustment_dialog.dart';
part 'shared/v2_opening_balance_dialog.dart';
part 'shared/v2_helpers.dart';

class ALIkhlasV2App extends ConsumerWidget {
  const ALIkhlasV2App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(bootstrapProvider);
    final owner = ref.watch(currentOwnerProvider);
    final initialOwnerRequired = ref.watch(initialOwnerRequiredProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ALIkhlasPOS v2',
      locale: const Locale('ar', 'EG'),
      theme: buildV2Theme(),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: bootstrap.when(
        loading: () => const _BootScreen(),
        error: (error, stackTrace) => _FatalScreen(
          message: error.toString(),
          alreadyRunning: error is ApplicationAlreadyRunning,
        ),
        data: (_) => owner == null
            ? initialOwnerRequired.when(
                loading: () => const _BootScreen(),
                error: (error, stackTrace) =>
                    _FatalScreen(message: error.toString()),
                data: (required) => required
                    ? const _InitialOwnerScreen()
                    : const _LoginScreen(),
              )
            : owner.mustChangePassword
            ? const _ChangePasswordScreen()
            : const _WorkbenchShell(),
      ),
    );
  }
}
