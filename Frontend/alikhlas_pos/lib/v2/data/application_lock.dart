import 'dart:io';

/// Process-lifetime lock: do not unlink the file while an owner may exist.
class ApplicationLock {
  ApplicationLock._(this._handle);
  final RandomAccessFile _handle;
  static ApplicationLock? _owner;
  static Future<void>? _acquiring;

  static Future<void> acquire(Directory directory) {
    return _acquiring ??= _acquire(
      directory,
    ).whenComplete(() => _acquiring = null);
  }

  static Future<void> _acquire(Directory directory) async {
    if (_owner != null) return;
    await directory.create(recursive: true);
    final handle = await File(
      '${directory.path}/alikhlas.instance.lock',
    ).open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
    } on FileSystemException {
      await handle.close();
      throw const ApplicationAlreadyRunning();
    }
    _owner = ApplicationLock._(handle);
  }

  /// Explicitly used by command-line tests; production holds until process exit.
  static Future<void> release() async {
    final owner = _owner;
    if (owner == null) return;
    await owner._handle.close();
    _owner = null;
  }
}

class ApplicationAlreadyRunning implements Exception {
  const ApplicationAlreadyRunning();
  @override
  String toString() =>
      'التطبيق مفتوح بالفعل. استخدم النافذة الحالية أو أغلقها ثم أعد المحاولة.';
}
