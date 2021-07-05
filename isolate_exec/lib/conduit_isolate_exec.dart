/// Executes closures on isolates.
///
///
library conduit_isolate_exec;

export 'src/executable.dart';
export 'src/executor.dart';
export 'src/source_generator.dart';

import 'package:reflectable/reflectable.dart';

class IsolateReflector extends Reflectable {
  const IsolateReflector()
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

const isolateReflector = IsolateReflector();
