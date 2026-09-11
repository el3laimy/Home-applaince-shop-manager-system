import 'package:alikhlas_pos/v2/app/v2_app.dart';
import 'package:alikhlas_pos/v2/app/v2_providers.dart';
import 'package:alikhlas_pos/v2/data/migration_recovery.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a newer database explains the safe next action in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapProvider.overrideWith(
            (ref) async => throw const DatabaseVersionTooNew(
              databaseVersion: 6,
              supportedVersion: 5,
            ),
          ),
        ],
        child: const ALIkhlasV2App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('هذه البيانات أحدث'), findsOneWidget);
    expect(find.textContaining('ثبّت إصدارًا أحدث'), findsOneWidget);
    expect(find.textContaining('تعذر تشغيل قاعدة البيانات'), findsOneWidget);
  });
}
