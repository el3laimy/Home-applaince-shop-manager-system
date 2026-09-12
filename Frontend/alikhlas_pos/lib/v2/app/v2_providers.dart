import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_build_info.dart';
import '../application/v2_use_cases.dart';
import '../data/app_database.dart';
import '../core/result.dart';
import '../printing/barcode_labels_pdf.dart';
import '../printing/printer_test_page_pdf.dart';
import '../printing/sale_receipt_pdf.dart';

typedef BarcodeLabelPrinter =
    Future<void> Function(
      List<BarcodeLabelItem> items,
      BarcodeLabelSettingsSnapshot settings,
    );

typedef PrinterTestPage = Future<bool> Function(ShopSettingsSnapshot settings);
typedef SupportReportSaver = Future<bool> Function(String report);
typedef ProductCsvFilePicker = Future<ProductCsvPickedFile?> Function();
typedef ProductCsvTemplateSaver = Future<bool> Function(String template);

class ProductCsvPickedFile {
  const ProductCsvPickedFile({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

class ProductCsvFileTooLarge implements Exception {
  const ProductCsvFileTooLarge();
}

final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isEmpty) return 'غير متاح';
    final version = info.buildNumber.isEmpty
        ? info.version
        : '${info.version}+${info.buildNumber}';
    return withBuildRevision(version);
  } catch (_) {
    return 'غير متاح';
  }
});

final supportReportSaverProvider = Provider<SupportReportSaver>((ref) {
  return (report) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'احفظ تقرير الدعم',
      fileName: 'alikhlas-support-report.txt',
      type: FileType.custom,
      allowedExtensions: const ['txt'],
    );
    if (path == null) return false;
    await File(path).writeAsString(report, flush: true);
    return true;
  };
});

final productCsvFilePickerProvider = Provider<ProductCsvFilePicker>((ref) {
  return () async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'اختر ملف منتجات CSV',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: false,
    );
    final file = picked?.files.single;
    if (file == null || file.path == null) return null;
    final source = File(file.path!);
    if (await source.length() > V2ProductCsvImportUseCases.productCsvMaxBytes) {
      throw const ProductCsvFileTooLarge();
    }
    return ProductCsvPickedFile(
      name: file.name,
      bytes: await source.readAsBytes(),
    );
  };
});

final productCsvTemplateSaverProvider = Provider<ProductCsvTemplateSaver>((
  ref,
) {
  return (template) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'احفظ قالب المنتجات CSV',
      fileName: 'alikhlas-products-template.csv',
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (path == null) return false;
    await File(path).writeAsString(template, flush: true);
    return true;
  };
});

final appClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final useCasesProvider = Provider<V2UseCases>((ref) {
  return V2UseCases(
    ref.watch(databaseProvider),
    clock: ref.watch(appClockProvider),
  );
});

final barcodeLabelPrinterProvider = Provider<BarcodeLabelPrinter>((ref) {
  return (items, settings) => BarcodeLabelsPdf.printLabels(
    items,
    pageFormat: BarcodeLabelsPdf.labelFormat(
      widthMm: settings.widthMm,
      heightMm: settings.heightMm,
    ),
  );
});

final printerTestPageProvider = Provider<PrinterTestPage>((ref) {
  return PrinterTestPagePdf.printTestPage;
});

final automaticBackupCheckProvider = Provider<Future<File?> Function()>((ref) {
  return ref.watch(useCasesProvider).tryAutomaticBackup;
});

final bootstrapProvider = FutureProvider<void>((ref) async {
  final useCases = ref.watch(useCasesProvider);
  final checkBackup = ref.watch(automaticBackupCheckProvider);
  await useCases.bootstrap(createDefaultOwner: false);
  if (!ref.mounted) return;
  final timer = Timer.periodic(const Duration(minutes: 1), (_) async {
    final previousWarning = useCases.backupWarning;
    final file = await checkBackup();
    if (ref.mounted &&
        (file != null || previousWarning != useCases.backupWarning)) {
      ref.invalidate(workbenchProvider);
    }
  });
  ref.onDispose(timer.cancel);
});

final initialOwnerRequiredProvider = FutureProvider<bool>((ref) {
  return ref.watch(useCasesProvider).hasOwner().then((hasOwner) => !hasOwner);
});

final dashboardProvider = FutureProvider.autoDispose<DashboardSnapshot>((ref) {
  return ref.watch(useCasesProvider).dashboardSnapshot();
});

final workbenchProvider = FutureProvider.autoDispose<WorkbenchSnapshot>((ref) {
  return ref.watch(useCasesProvider).workbenchSnapshot();
});

class CurrentOwner extends Notifier<User?> {
  @override
  User? build() => null;

  void setOwner(User? owner) => state = owner;
}

final currentOwnerProvider = NotifierProvider<CurrentOwner, User?>(
  CurrentOwner.new,
);

final saleReceiptPrinterProvider =
    Provider<Future<void> Function(SaleReceiptSnapshot)>(
      (ref) => SaleReceiptPdf.printReceipt,
    );

typedef SaleWriter =
    Future<AppResult<int>> Function({
      String? operationKey,
      int? customerId,
      required List<SaleLineInput> items,
      required List<PaymentInput> payments,
      InstallmentTerms? installmentTerms,
      required int discountMinor,
    });
final saleWriterProvider = Provider<SaleWriter>((ref) {
  final useCases = ref.watch(useCasesProvider);
  return ({
    operationKey,
    customerId,
    required items,
    required payments,
    installmentTerms,
    required discountMinor,
  }) {
    if (operationKey == null) {
      return Future.value(const AppFailure<int>('معرّف البيع مطلوب'));
    }
    return useCases.submitPendingSale(
      PendingSale(
        operationKey: operationKey,
        customerId: customerId,
        items: items,
        payments: payments,
        installmentTerms: installmentTerms,
        discountMinor: discountMinor,
      ),
    );
  };
});
final saleReceiptLoaderProvider =
    Provider<Future<SaleReceiptSnapshot> Function(int)>(
      (ref) => ref.watch(useCasesProvider).saleReceipt,
    );

typedef PurchaseWriter =
    Future<AppResult<int>> Function({
      String? operationKey,
      int? supplierId,
      required List<PurchaseLineInput> items,
      required List<PaymentInput> payments,
      required bool allowNegativeBalance,
    });
final purchaseWriterProvider = Provider<PurchaseWriter>((ref) {
  final useCases = ref.watch(useCasesProvider);
  return ({
    operationKey,
    supplierId,
    required items,
    required payments,
    required allowNegativeBalance,
  }) {
    if (operationKey == null) {
      return Future.value(const AppFailure<int>('معرّف الشراء مطلوب'));
    }
    return useCases.submitPendingPurchase(
      PendingPurchase(
        operationKey: operationKey,
        supplierId: supplierId,
        items: items,
        payments: payments,
      ),
      allowNegativeBalance: allowNegativeBalance,
    );
  };
});
