// @GlobalQuantifyCapability(r"^dart.core.List$", runtimeReflector)
// @GlobalQuantifyCapability(r"^dart.core.Iterable$", runtimeReflector)
// @GlobalQuantifyCapability(r"^dart.core.Iterator$", runtimeReflector)
// @GlobalQuantifyCapability(r"^dart.core.Map$", runtimeReflector)
// @GlobalQuantifyCapability(r"^dart.core.List", runtimeReflector)
// @GlobalQuantifyCapability(r"^dart.core.Map", runtimeReflector)
@GlobalQuantifyCapability(r"^dart.core.bool", runtimeReflector)
@GlobalQuantifyCapability(r"^dart.core.int", runtimeReflector)
@GlobalQuantifyCapability(r"^dart.core.double", runtimeReflector)
@GlobalQuantifyCapability(r"^dart.core.num", runtimeReflector)
import 'package:reflectable/reflectable.dart';

@runtimeReflector
class RuntimeReflector extends Reflectable {
  const RuntimeReflector()
      : super(
          newInstanceCapability,
          invokingCapability,
          instanceInvokeCapability,
          declarationsCapability,
          typingCapability,
          libraryCapability,
          // subtypeQuantifyCapability,
          superclassQuantifyCapability,
          reflectedTypeCapability,
          typeAnnotationQuantifyCapability,
        );
}

// HttpRequest

const runtimeReflector = RuntimeReflector();
