import 'package:conduit/src/application/channel.dart';
import 'package:conduit/src/http/controller.dart';
import 'package:conduit/src/http/serializable.dart';
import 'package:conduit/src/runtime/impl.dart';
import 'package:conduit/src/runtime/orm/data_model_compiler.dart';
import 'package:conduit_runtime/runtime.dart';

class ConduitCompiler extends Compiler {
  @override
  Map<Type, dynamic> compile(MirrorContext context) {
    final m = <Type, dynamic>{};

    m.addEntries(context
        .getSubclassesOf(ApplicationChannel)
        .map((t) => MapEntry(t.reflectedType, ChannelRuntimeImpl(t))));
    m.addEntries(context
        .getSubclassesOf(Serializable)
        .map((t) => MapEntry(t.reflectedType, SerializableRuntimeImpl(t))));
    m.addEntries(context
        .getSubclassesOf(Controller)
        .map((t) => MapEntry(t.reflectedType, ControllerRuntimeImpl(t))));

    m.addAll(DataModelCompiler().compile(context));

    return m;
  }
}
