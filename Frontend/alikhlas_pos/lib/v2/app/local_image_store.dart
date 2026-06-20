import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalImageStore {
  const LocalImageStore._();

  static Future<String> copyProductImage(
    String sourcePath, {
    Directory? appSupportDirectory,
  }) {
    return _copyImage(
      sourcePath,
      bucketName: 'product-images',
      appSupportDirectory: appSupportDirectory,
    );
  }

  static Future<String> copyBackgroundImage(
    String sourcePath, {
    Directory? appSupportDirectory,
  }) {
    return _copyImage(
      sourcePath,
      bucketName: 'backgrounds',
      appSupportDirectory: appSupportDirectory,
    );
  }

  static Future<String> _copyImage(
    String sourcePath, {
    required String bucketName,
    Directory? appSupportDirectory,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw const FileSystemException('Image file does not exist');
    }

    final extension = p.extension(sourcePath).toLowerCase();
    if (!_supportedExtensions.contains(extension)) {
      throw ArgumentError.value(sourcePath, 'sourcePath', 'Unsupported image');
    }

    final supportDir =
        appSupportDirectory ?? await getApplicationSupportDirectory();
    final targetDir = Directory(p.join(supportDir.path, bucketName));
    await targetDir.create(recursive: true);

    if (p.isWithin(targetDir.path, sourceFile.path)) return sourceFile.path;

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final targetFile = File(p.join(targetDir.path, '$timestamp$extension'));
    await sourceFile.copy(targetFile.path);
    return targetFile.path;
  }

  static const _supportedExtensions = {'.jpg', '.jpeg', '.png', '.webp'};
}
