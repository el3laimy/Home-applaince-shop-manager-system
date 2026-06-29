import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/v2_use_cases.dart';
import '../data/app_database.dart';
import '../printing/barcode_labels_pdf.dart';

typedef BarcodeLabelPrinter =
    Future<void> Function(
      List<BarcodeLabelItem> items,
      BarcodeLabelSettingsSnapshot settings,
    );

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final useCasesProvider = Provider<V2UseCases>((ref) {
  return V2UseCases(ref.watch(databaseProvider));
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

final bootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(useCasesProvider).bootstrap();
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
