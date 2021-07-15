/// Executes closures on isolates.
///
///
library conduit_isolate_exec;

import 'package:reflectable/reflectable.dart';

export 'src/executable.dart';
export 'src/executor.dart' hide sourceName;
export 'src/source_generator.dart' hide sourceName;

const sourceName = '../isolate_exec/lib/conduit_isolate_exec.dart';

@isolateReflector
@sourceName
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
