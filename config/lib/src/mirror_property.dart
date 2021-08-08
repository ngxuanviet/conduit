import 'package:conduit_config/src/configuration.dart';
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

  dynamic _decodeValue(dynamic value,
      {Type configuration = Configuration, String keyPath = ''}) {
    try {
      if (type.isSubtypeOf(runtimeReflector.reflectType(num))) {
        return _decodeNum(value);
      } else if (type.isSubtypeOf(runtimeReflector.reflectType(bool))) {
        return _decodeBool(value);
      } else if (type.isSubtypeOf(runtimeReflector.reflectType(String))) {
        if (value is YamlList) {
          return _decodeList(value.nodes,
              configuration: configuration, keyPath: keyPath);
        } else if (value is YamlScalar) {
          return value.value as String;
        }
        return value as String?;
      } else if (type
          .isSubtypeOf(runtimeReflector.reflectType(Configuration))) {
        return _decodeConfig(value,
            configuration: configuration, keyPath: keyPath);
      } else if (type.isSubtypeOf(runtimeReflector.reflectType(List))) {
        if (value is YamlMap) {
          return _decodeMap(value.value,
              configuration: configuration, keyPath: keyPath);
        }
        if (value is Set) {
          throw UnimplementedError;
        }
        return _decodeList(value as List,
            configuration: configuration, keyPath: keyPath);
      } else if (type.isSubtypeOf(runtimeReflector.reflectType(Map))) {
        return _decodeMap(value as Map,
            configuration: configuration, keyPath: keyPath);
      }
    } on ConfigurationException catch (e) {
      throw ConfigurationException(configuration, e.toString(),
          keyPath: e.keyPath);
    } catch (e) {
      throw ConfigurationException(configuration, e.toString(),
          keyPath: keyPath);
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

  Configuration _decodeConfig(dynamic object,
      {Type? configuration = Configuration, String keyPath = ''}) {
    final item = (type as ClassMirror).newInstance('', []) as Configuration;

    item.decode(object,
        configuration: configuration ?? type.reflectedType, keyPath: keyPath);

    return item;
  }

  dynamic _decodeList(List value,
      {Type configuration = Configuration, String keyPath = ''}) {
    final out = [];
    if (value.isEmpty) {
      return out;
    }

    for (var i = 0; i < value.length; i++) {
      var val = value[i];
      if (val is YamlNode) {
        val = val.value;
      }

      TypeMirror innerType;
      if (val is List) {
        innerType = runtimeReflector.reflectType(List);
      } else if (val is Map) {
        innerType = runtimeReflector.reflectType(Map);
      } else if (val is Set) {
        innerType = runtimeReflector.reflectType(List);
      } else {
        innerType = runtimeReflector.reflect(val as Object).type;
      }

      final innerDecoder = MirrorTypeCodec(innerType);
      final v = innerDecoder._decodeValue(val,
          configuration: configuration, keyPath: '$keyPath[$i]');
      out.add(v);
    }
    return out;
  }

  dynamic _decodeMap(Map value,
      {Type configuration = Configuration, String keyPath = ''}) {
    final map = {};

    value.forEach((key, val) {
      if (key is! String) {
        throw StateError('cannot have non-String key');
      }

      if (val is YamlNode) {
        val = val.value;
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
      map[key] = innerDecoder._decodeValue(val,
          configuration: configuration, keyPath: keyPath);
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

  dynamic decode(dynamic input,
      {Type configuration = Configuration, String keyPath = ''}) {
    return codec._decodeValue(Configuration.getEnvironmentOrValue(input),
        configuration: configuration, keyPath: keyPath);
  }
}
