import 'package:conduit_runtime/runtime.dart';
import 'package:conduit_runtime/src/mirror_context.dart';

@runtimeReflector
abstract class Compiler {
  /// Returns a map of runtime objects that can be used at runtime while running in mirrored mode.
  Map<Type, dynamic> compile(MirrorContext context);
}
