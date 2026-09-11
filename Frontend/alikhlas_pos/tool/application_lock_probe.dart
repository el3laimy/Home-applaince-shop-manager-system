import 'dart:io';
import 'package:alikhlas_pos/v2/data/application_lock.dart';

Future<void> main(List<String> arguments) async {
  try {
    await ApplicationLock.acquire(Directory(arguments.first));
    stdout.writeln('acquired');
    if (arguments.length > 1 && arguments[1] == 'hold') {
      await stdin.first;
    }
    await ApplicationLock.release();
  } on ApplicationAlreadyRunning {
    stdout.writeln('busy');
    exitCode = 23;
  }
}
