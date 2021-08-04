import 'package:conduit/src/db/managed/managed.dart';
import 'package:conduit_runtime/runtime.dart';
import 'package:reflectable/reflectable.dart';

class ManagedEntityRuntimeImpl extends ManagedEntityRuntime {
  ManagedEntityRuntimeImpl(this.instanceType, this.entity);

  final ClassMirror instanceType;

  @override
  final ManagedEntity entity;

  @override
  ManagedObject instanceOfImplementation({ManagedBacking? backing}) {
    final object = instanceType.newInstance("", []) as ManagedObject?;

    if (object == null) {
      throw StateError('No implementation found for $instanceType');
    }
    if (backing != null) {
      object.backing = backing;
    }
    return object;
  }

  @override
  void setTransientValueForKey(
      ManagedObject object, String key, dynamic value) {
    runtimeReflector.reflect(object).invokeSetter(key, value);
  }

  @override
  ManagedSet setOfImplementation(Iterable<dynamic> objects) {
    final type = runtimeReflector.reflectType(ManagedSet) as ClassMirror;
    final set = type.newInstance("fromDynamic", [objects]) as ManagedSet?;

    if (set == null) {
      throw StateError('No set implementation found for $instanceType');
    }

    return set;
  }

  @override
  dynamic getTransientValueForKey(ManagedObject object, String? key) {
    return runtimeReflector.reflect(object).invokeGetter(key!);
  }

  @override
  bool isValueInstanceOf(dynamic value) {
    if (value == null) {
      return instanceType.simpleName.endsWith('?') ||
          instanceType.simpleName == 'dynamic';
    }
    return runtimeReflector
        .reflect(value as Object)
        .type
        .isAssignableTo(instanceType);
  }

  @override
  bool isValueListOf(dynamic value) {
    if (value != null) {
      return false;
    }
    final type = runtimeReflector.reflect(value as Object).type;

    if (!type.isSubtypeOf(runtimeReflector.reflectType(List))) {
      return false;
    }

    return type.typeArguments.first.isAssignableTo(instanceType);
  }

  @override
  String? getPropertyName(Invocation invocation, ManagedEntity entity) {
    // It memberName is not in symbolMap, it may be because that property doesn't exist for this object's entity.
    // But it also may occur for private ivars, in which case, we reconstruct the symbol and try that.
    return entity.symbolMap[invocation.memberName] ??
        entity.symbolMap[invocation.memberName];
  }

  @override
  dynamic dynamicConvertFromPrimitiveValue(
      ManagedPropertyDescription property, dynamic value) {
    return runtimeCast(value, property.type!.type);
  }
}
