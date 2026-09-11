import 'dart:io';
import 'dart:typed_data';

import 'package:alikhlas_pos/v2/app/v2_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'report saver writes exact UTF-8 preview and propagates write failure',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'support-report-',
      );
      final picker = _ReportPicker();
      FilePicker.platform = picker;
      final container = ProviderContainer();
      addTearDown(() async {
        container.dispose();
        await directory.delete(recursive: true);
      });
      final save = container.read(supportReportSaverProvider);
      const preview = 'تقرير دعم إخلاص POS\nنسخة التطبيق: 9.4.2+7\n';
      expect(await save(preview), isFalse);
      expect(directory.listSync(), isEmpty);

      final output = File('${directory.path}/تقرير الدعم.txt');
      picker.path = output.path;
      expect(await save(preview), isTrue);
      expect(await output.readAsString(), preview);
      picker.path = '${directory.path}/missing/report.txt';
      await expectLater(save(preview), throwsA(isA<FileSystemException>()));
      expect(await output.readAsString(), preview);
    },
  );

  test(
    'version provider reads package metadata instead of a fixed release',
    () async {
      for (final entry in [
        ('9.4.2', '7', '9.4.2+7'),
        ('2.0.0', '', '2.0.0'),
        ('', '', 'غير متاح'),
      ]) {
        PackageInfo.setMockInitialValues(
          appName: 'ALIkhlas POS',
          packageName: 'alikhlas_pos',
          version: entry.$1,
          buildNumber: entry.$2,
          buildSignature: '',
        );
        final container = ProviderContainer();
        try {
          expect(await container.read(appVersionProvider.future), entry.$3);
        } finally {
          container.dispose();
        }
      }
    },
  );
}

class _ReportPicker extends FilePicker {
  String? path;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async => path;
}
