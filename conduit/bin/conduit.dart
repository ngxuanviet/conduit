import 'dart:async';
import 'package:universal_io/io.dart';

import 'package:conduit/src/cli/runner.dart';

Future main(List<String> args) async {
  final runner = Runner();
  final values = runner.options.parse(args);
  exitCode = await runner.process(values);
}
