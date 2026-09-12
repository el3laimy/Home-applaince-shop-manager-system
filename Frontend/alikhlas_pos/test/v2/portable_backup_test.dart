import 'dart:convert';
import 'dart:io';

import 'package:alikhlas_pos/v2/application/v2_use_cases.dart';
import 'package:alikhlas_pos/v2/core/result.dart';
import 'package:alikhlas_pos/v2/data/app_database.dart';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

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

  test(
    'portable backup upgrades its staged v4 database before restore',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'alikhlas-portable-v4-',
      );
      addTearDown(() => root.delete(recursive: true));
      final sourceDirectory = Directory(p.join(root.path, 'source'));
      final targetDirectory = Directory(p.join(root.path, 'target'));
      await sourceDirectory.create();
      await targetDirectory.create();

      final sourceDb = AppDatabase(
        NativeDatabase(File(p.join(sourceDirectory.path, 'shop.db'))),
      );
      final source = V2UseCases(sourceDb);
      await source.bootstrap(createDefaultOwner: true);
      final backgroundImage = File(
        p.join(sourceDirectory.path, 'backgrounds', 'store.webp'),
      );
      await backgroundImage.parent.create(recursive: true);
      await backgroundImage.writeAsBytes([8, 7, 6], flush: true);
      await source.updateUiBackground(
        preset: 'aurora',
        imagePath: backgroundImage.path,
      );
      final currentBundle = await source.createPortableBackup(
        Directory(p.join(root.path, 'backups')),
      );
      await sourceDb.close();

      final legacyBundle = await _downgradePortableBundleToV4(
        currentBundle,
        Directory(p.join(root.path, 'legacy-bundle')),
      );

      var targetDb = AppDatabase(
        NativeDatabase(File(p.join(targetDirectory.path, 'shop.db'))),
      );
      addTearDown(() => targetDb.close());
      final target = V2UseCases(targetDb);
      await target.bootstrap(createDefaultOwner: true);
      await target.restoreFromPortableBackup(legacyBundle);
      await targetDb.close();

      final restoredFile = File(p.join(targetDirectory.path, 'shop.db'));
      expect(_databaseVersion(restoredFile), kAppDatabaseSchemaVersion);
      targetDb = AppDatabase(NativeDatabase(restoredFile));
      final restoredBackground = await V2UseCases(targetDb).uiBackground();
      expect(restoredBackground.imagePath, isNotNull);
      expect(
        p.isWithin(targetDirectory.path, restoredBackground.imagePath!),
        isTrue,
      );
      expect(await File(restoredBackground.imagePath!).readAsBytes(), [
        8,
        7,
        6,
      ]);
    },
  );
}

Future<File> _downgradePortableBundleToV4(
  File bundle,
  Directory staging,
) async {
  await staging.create(recursive: true);
  final archive = ZipDecoder().decodeBytes(
    await bundle.readAsBytes(),
    verify: true,
  );
  await extractArchiveToDisk(archive, staging.path);
  final database = File(p.join(staging.path, 'database.db'));
  final raw = sqlite.sqlite3.open(database.path);
  try {
    raw
      ..execute('DROP TRIGGER IF EXISTS products_nonnegative_insert;')
      ..execute('DROP TRIGGER IF EXISTS products_nonnegative_update;')
      ..execute('ALTER TABLE products DROP COLUMN image_path;')
      ..execute('ALTER TABLE products DROP COLUMN inventory_value_minor;')
      ..execute('ALTER TABLE sale_items DROP COLUMN cost_minor;')
      ..execute('ALTER TABLE sale_return_items DROP COLUMN cost_minor;')
      ..execute('PRAGMA user_version = 4;');
  } finally {
    raw.close();
  }

  final manifestFile = File(p.join(staging.path, 'manifest.json'));
  final manifest =
      jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
  final databaseManifest = manifest['database'] as Map<String, dynamic>;
  databaseManifest['sha256'] = sha256
      .convert(await database.readAsBytes())
      .toString();
  await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

  final legacyBundle = File(p.join(staging.parent.path, 'portable-v4.zip'));
  await ZipFileEncoder().zipDirectory(staging, filename: legacyBundle.path);
  return legacyBundle;
}

int _databaseVersion(File file) {
  final raw = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
  try {
    return raw.select('PRAGMA user_version;').single.values.single as int;
  } finally {
    raw.close();
  }
}
