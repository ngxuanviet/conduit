import 'mirror_coerce.dart';
import 'package:reflectable/reflectable.dart';

import 'reflector.dart';

MirrorContext instance = MirrorContext._();

class MirrorContext {
  MirrorContext._();

  final List<ClassMirror> types = runtimeReflector.libraries.values
      .where((lib) =>
          lib.uri.scheme == "package" ||
          lib.uri.scheme == "file" ||
          lib.uri.scheme == "reflectable")
      .expand((lib) => lib.declarations.values)
      .whereType<ClassMirror>()
      .toList();

  List<ClassMirror> getSubclassesOf(Type type) {
    final mirror = runtimeReflector.reflectType(type);
    return types.where((decl) {
      if (decl.isAbstract) {
        return false;
      }

      if (!decl.isSubclassOf(mirror as ClassMirror)) {
        return false;
      }

      if (decl.hasReflectedType) {
        if (decl.reflectedType == type) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  T coerce<T>(dynamic input) {
    return runtimeCast(input, T) as T;
  }
}

T? firstMetadataOfType<T>(DeclarationMirror dm, {TypeMirror? dynamicType}) {
  final tMirror = dynamicType ?? runtimeReflector.reflectType(T);
  try {
    return dm.metadata.firstWhere(
        (im) => runtimeReflector.reflect(im).type.isSubtypeOf(tMirror)) as T?;
    // ignore: avoid_catching_errors
  } on StateError catch (_) {
    return null;
  }
}
