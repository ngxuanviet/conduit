import 'dart:async';
import 'dart:isolate';
import 'package:reflectable/reflectable.dart';

import '../conduit_isolate_exec.dart';

const sourceName = '../isolate_exec/lib/src/executable.dart';

@isolateReflector
@sourceName
abstract class Executable<T extends Object?> {
  Executable(this.message) : _sendPort = message["_sendPort"] as SendPort?;

  Future<T> execute();

  final Map<String, dynamic> message;
  final SendPort? _sendPort;

  U instanceOf<U>(
    String typeName, {
    List positionalArguments = const [],
    Map<Symbol, dynamic> namedArguments = const {},
    String constructorName = "",
  }) {
    ClassMirror? typeMirror = isolateReflector
        .libraries[0]?.declarations[Symbol(typeName)] as ClassMirror?;

    print('odososos');
    for (var element in isolateReflector.libraries.values) {
      print(element.declarations);
    }
    typeMirror ??= isolateReflector.libraries.values
        .where((lib) => lib.uri.scheme == "package" || lib.uri.scheme == "file")
        .expand((lib) => lib.declarations.values)
        .firstWhere(
      (decl) {
        print('oiajsdoijasodij');
        print(decl is ClassMirror);
        print(decl.simpleName);
        print(typeName);
        return decl is ClassMirror && decl.simpleName == typeName;
      },
      orElse: () => throw ArgumentError(
          "Unknown type '$typeName'. Did you forget to import it?"),
    ) as ClassMirror?;

    return typeMirror!.newInstance(
      constructorName,
      positionalArguments,
      namedArguments,
    ) as U;
  }

  void send(dynamic message) {
    _sendPort!.send(message);
  }

  void log(String message) {
    _sendPort!.send({"_line_": message});
  }
}
