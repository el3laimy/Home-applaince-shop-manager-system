import 'dart:io';

/// Isolates best-effort retention cleanup from successful snapshot creation.
/// Tests can simulate a locked old backup without relying on host-specific
/// file-lock behavior.
class BackupFileOperations {
  const BackupFileOperations();

  Future<void> deleteFile(File file) => file.delete();
}
