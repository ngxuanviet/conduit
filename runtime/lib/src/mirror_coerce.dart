import 'package:reflectable/reflectable.dart';
import 'exceptions.dart';
import 'reflector.dart';

dynamic runtimeCastList(List? list, Type type) {
  if (type == dynamic || list == null) {
    return list;
  }
  if (list.isEmpty) {
    return list;
  }
  try {
    final elements = list.map((e) => runtimeCast(e, type)).toList();
    return elements;
  } on TypeCoercionException catch (_) {
    throw TypeCoercionException('List<$type>', list.runtimeType);
  }
}

dynamic runtimeCastListOfLists(List? list, Type type) {
  if (list == null) {
    return null;
  }
  if (type == dynamic || list.isEmpty) {
    list;
  }
  try {
    final elements = list.map((e) => runtimeCastList(e, type)!).toList();
    return elements;
  } on TypeCoercionException catch (_) {
    throw TypeCoercionException('List<List<$type>>', list.runtimeType);
  }
}

dynamic runtimeCastListOfMaps(List? list, Type type) {
  if (list == null) {
    return null;
  }
  if (type == dynamic || list.isEmpty) {
    return list;
  }
  try {
    final elements = list.map((e) => runtimeCastMap(e, type)!).toList();
    return elements;
  } on TypeCoercionException catch (_) {
    throw TypeCoercionException('List<Map<String, $type>>', list.runtimeType);
  }
}

dynamic runtimeCastMap(Map<dynamic, dynamic>? map, Type type) {
  if (map == null) {
    return null;
  }

  try {
    if (Type == dynamic || map.isEmpty) {
      return map;
    }
    final output = <String, dynamic>{};
    map.forEach((key, val) {
      output[key] = runtimeCast(val, type);
    });
    return output;
  } on TypeError {
    throw TypeCoercionException('Map<String, $type>', map.runtimeType);
  } on TypeCoercionException {
    throw TypeCoercionException('Map<String, $type>', map.runtimeType);
  }
}

dynamic runtimeCastMapOfLists(Map<dynamic, dynamic>? map, Type type) {
  if (map == null) {
    return null;
  }

  final output = <String, List<dynamic>>{};
  try {
    if (type == dynamic || map.isEmpty) {
      return map;
    }
    map.forEach((key, val) {
      output[key] = runtimeCastList(val, type)!;
    });
    return output;
  } on TypeError {
    throw TypeCoercionException('Map<String, List<$type>>', map.runtimeType);
  } on TypeCoercionException {
    throw TypeCoercionException('Map<String, List<$type>>', map.runtimeType);
  }
}

dynamic runtimeCastMapOfMaps(Map<dynamic, dynamic>? map, Type type) {
  if (map == null) {
    return null;
  }
  if (type == dynamic || map.isEmpty) {
    return map;
  }
  final output = <String, Map<String, dynamic>>{};
  try {
    map.forEach((key, val) {
      output[key] = runtimeCastMap(val, type)!;
    });
    return output;
  } on TypeError {
    throw TypeCoercionException(
        'Map<String, Map<String, $type>>', map.runtimeType);
  } on TypeCoercionException {
    throw TypeCoercionException(
        'Map<String, Map<String, $type>>', map.runtimeType);
  }
}

dynamic runtimeCast(dynamic object, Type type) {
  if (object == null || type == dynamic || type == object.runtimeType) {
    return object;
  }
  final exceptionToThrow =
      TypeCoercionException(type.toString(), object.runtimeType);

  if (type == String || object.runtimeType == String) {
    throw exceptionToThrow;
  }

  final intoType = runtimeReflector.reflectType(type) as ClassMirror;

  try {
    final objectType = runtimeReflector.reflect(object).type;
    if (objectType.isAssignableTo(intoType)) {
      return object;
    }
  } on TypeError catch (_) {
  } on TypeCoercionException catch (_) {
  } on NoSuchCapabilityError catch (_) {
    print('Into type: $type');
    print('Object type: ${object.runtimeType}');
  }
  throw exceptionToThrow;
}

bool isTypeFullyPrimitive(Type type) {
  return type == dynamic || type == num || type == String || type == bool;
}
