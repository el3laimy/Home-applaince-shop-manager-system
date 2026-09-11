import 'dart:io';

import 'package:alikhlas_pos/v2/app/local_image_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product image is copied into app support storage', () async {
    final tempDir = await Directory.systemTemp.createTemp('alikhlas-image-');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final sourceFile = File('${tempDir.path}/source.png');
    await sourceFile.writeAsBytes([1, 2, 3, 4]);
    final appSupportDir = Directory('${tempDir.path}/support');

    final storedPath = await LocalImageStore.copyProductImage(
      sourceFile.path,
      appSupportDirectory: appSupportDir,
    );
    await sourceFile.delete();

    expect(storedPath, contains('product-images'));
    expect(File(storedPath).existsSync(), isTrue);
    expect(File(storedPath).readAsBytesSync(), [1, 2, 3, 4]);
  });

  test(
    'background image is copied and unsupported files are rejected',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('alikhlas-bg-');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final imageFile = File('${tempDir.path}/wallpaper.webp');
      final textFile = File('${tempDir.path}/not-image.txt');
      await imageFile.writeAsBytes([9, 8, 7]);
      await textFile.writeAsString('not an image');
      final appSupportDir = Directory('${tempDir.path}/support');

      final storedPath = await LocalImageStore.copyBackgroundImage(
        imageFile.path,
        appSupportDirectory: appSupportDir,
      );

      expect(storedPath, contains('backgrounds'));
      expect(File(storedPath).existsSync(), isTrue);
      await expectLater(
        LocalImageStore.copyBackgroundImage(
          textFile.path,
          appSupportDirectory: appSupportDir,
        ),
        throwsArgumentError,
      );
    },
  );
}
