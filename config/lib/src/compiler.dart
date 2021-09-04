import 'package:conduit_runtime/runtime.dart';

import 'configuration.dart';

class ConfigurationCompiler extends Compiler {
  @override
  Map<Type, dynamic> compile(MirrorContext context) {
    return Map.fromEntries(context.getSubclassesOf(Configuration).map((c) {
      return MapEntry(c.reflectedType, c.newInstance('', []));
    }));
  }
}
