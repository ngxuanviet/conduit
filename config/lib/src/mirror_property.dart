import 'package:conduit_config/src/configuration.dart';
import 'package:conduit_config/src/intermediate_exception.dart';
import 'package:conduit_runtime/runtime.dart';
import 'package:reflectable/reflectable.dart';
import 'package:yaml/yaml.dart';

class MirrorTypeCodec {
  MirrorTypeCodec(this.type) {
    if (type.isSubtypeOf(runtimeReflector.reflectType(Configuration))) {
      final klass = type as ClassMirror;
      final classHasDefaultConstructor = klass.declarations.values.any((dm) {
        return dm is MethodMirror &&
            dm.isConstructor &&
            dm.constructorName == '' &&
            dm.parameters.every((p) => p.isOptional == true);
      });

      if (!classHasDefaultConstructor) {
        throw StateError(
          "Failed to compile '${type.reflectedType}'\n\t-> "
          "'Configuration' subclasses MUST declare an unnammed constructor "
          "(i.e. '${type.reflectedType}();') if they are nested.",
        );
      }
    }
  }

  final TypeMirror type;

  dynamic _decodeValue(dynamic value) {
    if (type.isSubtypeOf(runtimeReflector.reflectType(num))) {
      print(type.reflectedType);
      return _decodeNum(value);
    } else if (type.isSubtypeOf(runtimeReflector.reflectType(bool))) {
      return _decodeBool(value);
    } else if (type.isSubtypeOf(runtimeReflector.reflectType(String))) {
      if (value is YamlList) {
        return _decodeList(value.nodes);
      } else if (value is YamlScalar) {
        return value.value as String;
      }
      return value as String?;
    } else if (type.isSubtypeOf(runtimeReflector.reflectType(Configuration))) {
      return _decodeConfig(value);
    } else if (type.isSubtypeOf(runtimeReflector.reflectType(List))) {
      if (value is YamlMap) {
        return _decodeMap(value.value);
      }
      if (value is Set) {
        return _decodeList(value.toList());
      }
      return _decodeList(value as List);
    } else if (type.isSubtypeOf(runtimeReflector.reflectType(Map))) {
      return _decodeMap(value as Map);
    }

    return value;
  }

  bool _decodeBool(dynamic value) {
    if (value is String) {
      return value == "true";
    }

    return value as bool;
  }

  num _decodeNum(dynamic value) {
    if (value is String) {
      return num.parse(value);
    }

    return value as num;
  }

  Configuration _decodeConfig(dynamic object) {
    final item = (type as ClassMirror).newInstance('', []) as Configuration;

    item.decode(object);

    return item;
  }

  dynamic _decodeList(List value) {
    final out = [];
    if (value.isEmpty) {
      return out;
    }
    var firstVal = value.first;
    if (firstVal is YamlNode) {
      firstVal = firstVal.value;
    }

    TypeMirror innerType;
    if (firstVal is List) {
      innerType = runtimeReflector.reflectType(List);
    } else if (firstVal is Map) {
      innerType = runtimeReflector.reflectType(Map);
    } else if (firstVal is Set) {
      innerType = runtimeReflector.reflectType(List);
    } else {
      innerType = runtimeReflector.reflect(firstVal as Object).type;
    }

    final innerDecoder = MirrorTypeCodec(innerType);
    for (var i = 0; i < value.length; i++) {
      try {
        final v = innerDecoder._decodeValue(value[i]);
        out.add(v);
      } on IntermediateException catch (e) {
        e.keyPath.add(i);
        rethrow;
      } catch (e) {
        throw IntermediateException(e, [i]);
      }
    }

    return out;
  }

  dynamic _decodeMap(Map value) {
    final map = {};

    value.forEach((key, val) {
      if (key is! String) {
        throw StateError('cannot have non-String key');
      }
      TypeMirror innerType;
      if (val is List) {
        innerType = runtimeReflector.reflectType(List);
      } else if (val is Map) {
        innerType = runtimeReflector.reflectType(Map);
      } else {
        innerType = runtimeReflector.reflectType(val.runtimeType);
      }
      final innerDecoder = MirrorTypeCodec(innerType);

      try {
        map[key] = innerDecoder._decodeValue(val);
      } on IntermediateException catch (e) {
        e.keyPath.add(key);
        rethrow;
      } catch (e) {
        throw IntermediateException(e, [key]);
      }
    });

    return map;
  }

  String get expectedType {
    return type.reflectedType.toString();
  }
}

class MirrorConfigurationProperty {
  MirrorConfigurationProperty(this.property)
      : codec = MirrorTypeCodec(property.type);

  final VariableMirror property;
  final MirrorTypeCodec codec;

  String get key => property.simpleName;
  bool get isRequired => _isVariableRequired(property);

  static bool _isVariableRequired(VariableMirror m) {
    try {
      final attribute = m.metadata.firstWhere((im) => runtimeReflector
              .reflect(im)
              .type
              .isSubtypeOf(
                  runtimeReflector.reflectType(ConfigurationItemAttribute)))
          as ConfigurationItemAttribute;

      return attribute.type == ConfigurationItemAttributeType.required;
    } catch (_) {
      return false;
    }
  }

  dynamic decode(dynamic input) {
    return codec._decodeValue(Configuration.getEnvironmentOrValue(input));
  }
}
