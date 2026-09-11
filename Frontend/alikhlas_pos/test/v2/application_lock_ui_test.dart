import 'package:alikhlas_pos/v2/app/v2_app.dart';
import 'package:alikhlas_pos/v2/app/v2_providers.dart';
import 'package:alikhlas_pos/v2/data/application_lock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'second instance explains existing window instead of database failure',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bootstrapProvider.overrideWith(
              (ref) async => throw const ApplicationAlreadyRunning(),
            ),
          ],
          child: const ALIkhlasV2App(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('التطبيق مفتوح بالفعل'), findsOneWidget);
      expect(find.textContaining('تعذر تشغيل قاعدة البيانات'), findsNothing);
      expect(find.text('دخول'), findsNothing);
    },
  );
}
