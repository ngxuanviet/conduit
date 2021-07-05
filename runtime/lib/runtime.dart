library runtime;

import 'dart:io';
import 'package:conduit_runtime/src/mirror_context.dart';

import 'src/compiler.dart';

export 'src/analyzer.dart';
export 'src/build.dart';
export 'src/build_context.dart';
export 'src/build_manager.dart';
export 'src/compiler.dart';
export 'src/context.dart';
export 'src/exceptions.dart';
export 'src/file_system.dart';
export 'src/generator.dart';
export 'src/mirror_coerce.dart';
export 'src/mirror_context.dart';

// @GlobalQuantifyCapability(r"^dart.core.List$", runtimeReflector)
// @GlobalQuantifyCapability(r"^dart.core.Iterable$", runtimeReflector)
// @GlobalQuantifyCapability(r"^dart.core.Iterator$", runtimeReflector)
// @GlobalQuantifyCapability(r"^dart.core.Map$", runtimeReflector)
@GlobalQuantifyCapability(r"^dart.core.bool", runtimeReflector)
@GlobalQuantifyCapability(r"^dart.core.int", runtimeReflector)
@GlobalQuantifyCapability(r"^dart.core.double", runtimeReflector)
@GlobalQuantifyCapability(r"^dart.core.num", runtimeReflector)
@GlobalQuantifyCapability(r"^dart.core.String", runtimeReflector)
@GlobalQuantifyCapability(r"^dart.core.List", runtimeReflector)
@GlobalQuantifyCapability(r"^dart.core.Map", runtimeReflector)
import 'package:reflectable/reflectable.dart';

/// Compiler for the runtime package itself.
///
/// Removes dart:mirror from a replica of this package, and adds
/// a generated runtime to the replica's pubspec.
class RuntimePackageCompiler extends Compiler {
  @override
  Map<String, dynamic> compile(MirrorContext context) => {};

  @override
  void deflectPackage(Directory destinationDirectory) {
    final libraryFile = File.fromUri(
        destinationDirectory.uri.resolve("lib/").resolve("runtime.dart"));
    libraryFile.writeAsStringSync(
        "library runtime;\nexport 'src/context.dart';\nexport 'src/exceptions.dart';");

    final contextFile = File.fromUri(destinationDirectory.uri
        .resolve("lib/")
        .resolve("src/")
        .resolve("context.dart"));
    final contextFileContents = contextFile.readAsStringSync().replaceFirst(
        "import 'package:conduit_runtime/src/mirror_context.dart' as context;",
        "import 'package:generated_runtime/generated_runtime.dart' as context;");
    contextFile.writeAsStringSync(contextFileContents);

    final pubspecFile =
        File.fromUri(destinationDirectory.uri.resolve("pubspec.yaml"));
    final pubspecContents = pubspecFile.readAsStringSync().replaceFirst(
        "\ndependencies:",
        "\ndependencies:\n  generated_runtime:\n    path: ../../generated_runtime/");
    pubspecFile.writeAsStringSync(pubspecContents);
  }
}

class RuntimeReflector extends Reflectable {
  const RuntimeReflector()
      : super(
          newInstanceCapability,
          invokingCapability,
          instanceInvokeCapability,
          declarationsCapability,
          typingCapability,
          libraryCapability,
          superclassQuantifyCapability,
          reflectedTypeCapability,
        );
}

const runtimeReflector = RuntimeReflector();
