import 'dart:io';

import 'package:conduit_runtime/runtime.dart';
import 'package:conduit_runtime/src/mirror_context.dart';

@runtimeReflector
abstract class Compiler {
  /// Returns a map of runtime objects that can be used at runtime while running in mirrored mode.
  Map<String, dynamic> compile(MirrorContext context);

  void didFinishPackageGeneration(BuildContext context) {}

  List<Uri> getUrisToResolve(BuildContext context) => [];
}

/// Runtimes that generate source code implement this method.
abstract class SourceCompiler {
  /// The source code, including directives, that declare a class that is equivalent in behavior to this runtime.
  String compile(BuildContext ctx);
}
