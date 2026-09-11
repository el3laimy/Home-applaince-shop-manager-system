import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'portable backup restores database and local images on another path',
    () async {
      final root = await Directory.systemTemp.createTemp('alikhlas-portable-');
      addTearDown(() => root.delete(recursive: true));
      final sourceDirectory = Directory(p.join(root.path, 'source'));
      final targetDirectory = Directory(p.join(root.path, 'target'));
      await sourceDirectory.create();
      await targetDirectory.create();

      final sourceDb = AppDatabase(
        NativeDatabase(File(p.join(sourceDirectory.path, 'shop.db'))),
      );
      addTearDown(sourceDb.close);
      final source = V2UseCases(sourceDb);
      await source.bootstrap(createDefaultOwner: true);
      final productImage = File(
        p.join(sourceDirectory.path, 'product-images', 'washing.png'),
      );
      await productImage.parent.create(recursive: true);
      await productImage.writeAsBytes([1, 2, 3, 4], flush: true);
      final backgroundImage = File(
        p.join(sourceDirectory.path, 'backgrounds', 'store.webp'),
      );
      await backgroundImage.parent.create(recursive: true);
      await backgroundImage.writeAsBytes([8, 7, 6], flush: true);
      final product = await source.createProduct(
        operationKey: source.newOpeningStockOperationKey(),
        name: 'غسالة',
        salePriceMinor: 20000,
        openingQty: 0,
        openingCostMinor: 0,
        imagePath: productImage.path,
      );
      expect(product, isA<AppSuccess<Product>>());
      await source.updateUiBackground(
        preset: 'aurora',
        imagePath: backgroundImage.path,
      );
      final bundle = await source.createPortableBackup(
        Directory(p.join(root.path, 'backups')),
      );
      expect(await bundle.exists(), isTrue);
      await sourceDb.close();

      var targetDb = AppDatabase(
        NativeDatabase(File(p.join(targetDirectory.path, 'shop.db'))),
      );
      addTearDown(() => targetDb.close());
      final target = V2UseCases(targetDb);
      await target.bootstrap(createDefaultOwner: true);
      await target.restoreFromPortableBackup(bundle);
      await targetDb.close();

      targetDb = AppDatabase(
        NativeDatabase(File(p.join(targetDirectory.path, 'shop.db'))),
      );
      final restored = V2UseCases(targetDb);
      final restoredProduct = await targetDb
          .select(targetDb.products)
          .getSingle();
      final restoredBackground = await restored.uiBackground();
      final restoredProductImage = File(restoredProduct.imagePath!);
      final restoredBackgroundImage = File(restoredBackground.imagePath!);

      expect(restoredProduct.name, 'غسالة');
      expect(
        p.isWithin(targetDirectory.path, restoredProductImage.path),
        isTrue,
      );
      expect(
        p.isWithin(targetDirectory.path, restoredBackgroundImage.path),
        isTrue,
      );
      expect(await restoredProductImage.readAsBytes(), [1, 2, 3, 4]);
      expect(await restoredBackgroundImage.readAsBytes(), [8, 7, 6]);
    },
  );
}
