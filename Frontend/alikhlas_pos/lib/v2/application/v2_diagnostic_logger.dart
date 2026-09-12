import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DiagnosticLogSummary {
  const DiagnosticLogSummary({
    required this.recordCount,
    required this.lastRecordedAt,
    required this.hasRotatedLog,
  });

  final int recordCount;
  final DateTime? lastRecordedAt;
  final bool hasRotatedLog;
}

/// Privacy-safe local diagnostics for unexpected application failures.
///
/// Entries intentionally omit exception messages, payloads, customer data, and
/// file paths. The operation key is hashed so related failures can be matched
/// without exporting the durable financial identifier itself.
class V2DiagnosticLogger {
  V2DiagnosticLogger.forFile(
    this.file, {
    this.maximumBytes = 256 * 1024,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static Future<V2DiagnosticLogger>? _shared;

  static Future<V2DiagnosticLogger> shared() =>
      _shared ??= _createInApplicationSupport();

  static Future<V2DiagnosticLogger> _createInApplicationSupport() async {
    Directory directory;
    try {
      directory = await getApplicationSupportDirectory();
    } on Object {
      directory = Directory(
        p.join(Directory.systemTemp.path, 'alikhlas-pos-diagnostics-$pid'),
      );
    }
    return V2DiagnosticLogger.forFile(
      File(p.join(directory.path, 'diagnostics', 'errors.jsonl')),
    );
  }

  final File file;
  final int maximumBytes;
  final DateTime Function() _clock;
  Future<void> _pending = Future<void>.value();

  File get rotatedFile => File('${file.path}.1');

  Future<void> recordError({
    required String module,
    required String event,
    required Object error,
    StackTrace? stackTrace,
    String? operationId,
  }) {
    final record = <String, Object>{
      'timestampUtc': _clock().toUtc().toIso8601String(),
      'level': 'error',
      'module': _safeToken(module),
      'event': _safeToken(event),
      'errorType': _safeToken(error.runtimeType.toString()),
      if (operationId != null && operationId.isNotEmpty)
        'operationHash': _fingerprint(operationId),
      if (stackTrace != null) 'stackHash': _fingerprint(stackTrace.toString()),
    };
    final encoded = '${jsonEncode(record)}\n';
    _pending = _pending
        .catchError((Object _) {})
        .then((_) => _appendBestEffort(encoded));
    return _pending;
  }

  Future<DiagnosticLogSummary> summary() async {
    await _pending;
    var count = 0;
    DateTime? lastRecordedAt;
    for (final source in [rotatedFile, file]) {
      try {
        if (!await source.exists()) continue;
        final lines = await source.readAsLines();
        for (final line in lines) {
          try {
            final decoded = jsonDecode(line);
            if (decoded is! Map) continue;
            final timestamp = DateTime.tryParse(
              decoded['timestampUtc']?.toString() ?? '',
            );
            count += 1;
            if (timestamp != null &&
                (lastRecordedAt == null || timestamp.isAfter(lastRecordedAt))) {
              lastRecordedAt = timestamp;
            }
          } on FormatException {
            // A partial final line must not make support-report creation fail.
          }
        }
      } on FileSystemException {
        // Rotation or an unavailable diagnostic directory must not block support.
      }
    }
    var hasRotatedLog = false;
    try {
      hasRotatedLog = await rotatedFile.exists();
    } on FileSystemException {
      // Treat an unavailable rotated file as absent in the summary.
    }
    return DiagnosticLogSummary(
      recordCount: count,
      lastRecordedAt: lastRecordedAt,
      hasRotatedLog: hasRotatedLog,
    );
  }

  Future<void> _appendBestEffort(String encoded) async {
    try {
      await file.parent.create(recursive: true);
      if (await file.exists() &&
          await file.length() + utf8.encode(encoded).length > maximumBytes) {
        if (await rotatedFile.exists()) await rotatedFile.delete();
        await file.rename(rotatedFile.path);
      }
      await file.writeAsString(encoded, mode: FileMode.append, flush: true);
    } on FileSystemException {
      // Diagnostics can never turn an otherwise recoverable flow into failure.
    }
  }

  static String _safeToken(String value) {
    final normalized = value.replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_');
    return normalized.substring(0, normalized.length.clamp(0, 80));
  }

  static String _fingerprint(String value) =>
      sha256.convert(utf8.encode(value)).toString().substring(0, 16);
}

typedef V2DiagnosticEventSink =
    void Function({
      required String module,
      required String event,
      required Object error,
      StackTrace? stackTrace,
      String? operationId,
    });

void recordV2DiagnosticError({
  required String module,
  required String event,
  required Object error,
  StackTrace? stackTrace,
  String? operationId,
}) {
  unawaited(
    V2DiagnosticLogger.shared()
        .then(
          (logger) => logger.recordError(
            module: module,
            event: event,
            error: error,
            stackTrace: stackTrace,
            operationId: operationId,
          ),
        )
        .catchError((Object _) {}),
  );
}
