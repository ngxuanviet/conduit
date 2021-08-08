import 'dart:io';

import 'package:conduit_runtime/runtime.dart';
import 'package:meta/meta.dart';
import 'package:reflectable/mirrors.dart';
import 'package:yaml/yaml.dart';

import 'mirror_property.dart';

/// Subclasses of [Configuration] read YAML strings and files, assigning values from the YAML document to properties
/// of an instance of this type.
@runtimeReflector
abstract class Configuration {
  /// Default constructor.
  Configuration();

  late final Map<String, MirrorConfigurationProperty> properties =
      _collectProperties();

  Configuration.fromMap(Map<dynamic, dynamic> map,
      {Type? configuration, String keyPath = ''}) {
    decode(map.map<String, dynamic>((k, v) => MapEntry(k.toString(), v)),
        configuration: configuration ?? runtimeType, keyPath: keyPath);
  }

  /// [contents] must be YAML.
  Configuration.fromString(String contents) {
    final yamlMap = loadYaml(contents) as Map<dynamic, dynamic>?;
    final map =
        yamlMap?.map<String, dynamic>((k, v) => MapEntry(k.toString(), v));
    decode(map, configuration: runtimeType);
  }

  /// Opens a file and reads its string contents into this instance's properties.
  ///
  /// [file] must contain valid YAML data.
  Configuration.fromFile(File file) : this.fromString(file.readAsStringSync());

  /// Ingests [value] into the properties of this type.
  ///
  /// Override this method to provide decoding behavior other than the default behavior.
  void decode(dynamic value, {Type? configuration, String keyPath = ''}) {
    configuration ??= runtimeType;
    if (value is! Map) {
      throw ConfigurationException(
          configuration, "input is not an object (is a '${value.runtimeType}')",
          keyPath: keyPath);
    }
    final values = Map.from(value);
    properties.forEach((name, property) {
      final takingValue = values.remove(name);
      if (takingValue == null) {
        return;
      }

      final decodedValue = property.decode(takingValue,
          configuration: configuration!, keyPath: '$keyPath.$name');
      if (decodedValue == null) {
        return;
      }

      if (decodedValue is List && decodedValue.isNotEmpty) {
        final mirror = runtimeReflector.reflect(this);
        // ignore: cast_nullable_to_non_nullable
        final ref = mirror.invokeGetter(property.property.simpleName) as List?;
        if (ref == null) {
          throw ConfigurationException(configuration, "input is wrong type",
              keyPath: '$keyPath.$name');
        }
        for (var i = 0; i < decodedValue.length; i++) {
          final e = decodedValue[i];
          if (ref is List<Configuration>) {
            final refType = ref.runtimeType.toString();
            final innerType =
                refType.substring(0, refType.length - 1).split('<')[1];
            final refMirror = runtimeReflector.annotatedClasses
                .firstWhere((mirror) => mirror.simpleName == innerType);
            final config = refMirror.newInstance('', []) as Configuration;
            config.decode(e,
                configuration: configuration, keyPath: '$keyPath.$name[$i]');
            ref.add(config);
          } else {
            ref.add(e);
          }
        }
        return;
      } else if (decodedValue is Map && decodedValue.isNotEmpty) {
        final mirror = runtimeReflector.reflect(this);
        // ignore: cast_nullable_to_non_nullable
        final ref = mirror.invokeGetter(property.property.simpleName) as Map?;
        if (ref == null) {
          throw ConfigurationException(configuration, "input is wrong type",
              keyPath: '$keyPath.$name');
        }
        for (var i = 0; i < decodedValue.entries.length; i++) {
          final entry = decodedValue.entries.elementAt(i);
          if (ref is Map<String, Configuration>) {
            final refType = ref.runtimeType.toString();
            final innerType =
                refType.substring(0, refType.length - 1).split(' ')[1];
            final refMirror = runtimeReflector.annotatedClasses
                .firstWhere((mirror) => mirror.simpleName == innerType);
            ref[entry.key as String] =
                refMirror.newInstance('', []) as Configuration;
            ref[entry.key as String]!.decode(entry.value,
                configuration: configuration,
                keyPath: '$keyPath.$name.${entry.key}');
          } else {
            ref[entry.key] = entry.value;
          }
        }
        return;
      }

      if (!runtimeReflector
          .reflect(decodedValue as Object)
          .type
          .isAssignableTo(property.property.type)) {
        throw ConfigurationException(configuration, "input is wrong type",
            keyPath: '$keyPath.$name');
      }

      final mirror = runtimeReflector.reflect(this);
      mirror.invokeSetter(property.property.simpleName, decodedValue);
    });

    if (values.isNotEmpty) {
      throw ConfigurationException(configuration,
          "unexpected keys found: ${values.keys.map((s) => "'$s'").join(", ")}.",
          keyPath: keyPath);
    }
    validate(configuration: configuration, keyPath: keyPath);
  }

  /// Validates this configuration.
  ///
  /// By default, ensures all required keys are non-null.
  ///
  /// Override this method to perform validations on input data. Throw [ConfigurationException]
  /// for invalid data.
  @mustCallSuper
  void validate({Type configuration = Configuration, String keyPath = ''}) {
    final configMirror = runtimeReflector.reflect(this);
    final requiredValuesThatAreMissing = properties.values
        .where((v) {
          try {
            final value = configMirror.invokeGetter(v.key);
            return v.isRequired && value == null;
          } catch (e) {
            return true;
          }
        })
        .map((v) => v.key)
        .toList();

    if (requiredValuesThatAreMissing.isNotEmpty) {
      throw ConfigurationException.missingKeys(
          configuration, requiredValuesThatAreMissing,
          keyPath: keyPath);
    }
  }

  static dynamic getEnvironmentOrValue(dynamic value) {
    if (value is String && value.startsWith(r"$")) {
      final envKey = value.substring(1);
      if (!Platform.environment.containsKey(envKey)) {
        return null;
      }

      return Platform.environment[envKey];
    }
    return value;
  }

  Map<String, MirrorConfigurationProperty> _collectProperties() {
    final declarations = <VariableMirror>[];

    ClassMirror? ptr =
        runtimeReflector.reflectType(runtimeType) as ClassMirror?;
    while (ptr != null &&
        ptr.isSubclassOf(
            runtimeReflector.reflectType(Configuration) as ClassMirror)) {
      declarations.addAll(ptr.declarations.values
          .whereType<VariableMirror>()
          .where((vm) => !vm.isStatic && !vm.isPrivate));
      ptr = ptr.superclass;
    }

    final m = <String, MirrorConfigurationProperty>{};
    for (final vm in declarations) {
      final name = vm.simpleName;
      m[name] = MirrorConfigurationProperty(vm);
    }
    return m;
  }
}

/// Possible options for a configuration item property's optionality.
enum ConfigurationItemAttributeType {
  /// [Configuration] properties marked as [required] will throw an exception
  /// if their source YAML doesn't contain a matching key.
  required,

  /// [Configuration] properties marked as [optional] will be silently ignored
  /// if their source YAML doesn't contain a matching key.
  optional
}

/// [Configuration] properties may be attributed with these.
///
/// **NOTICE**: This will be removed in version 2.0.0.
/// To signify required or optional config you could do:
/// Example:
/// ```dart
/// class MyConfig extends Config {
///    late String required;
///    String? optional;
///    String optionalWithDefult = 'default';
///    late String optionalWithComputedDefault = _default();
///
///    String _default() => 'computed';
/// }
/// ```
class ConfigurationItemAttribute {
  const ConfigurationItemAttribute._(this.type);

  final ConfigurationItemAttributeType type;
}

/// Thrown when reading data into a [Configuration] fails.
class ConfigurationException {
  ConfigurationException(
    this.configuration,
    this.message, {
    this.keyPath = '',
  });

  ConfigurationException.missingKeys(
      this.configuration, List<String> missingKeys, {this.keyPath = ''})
      : message =
            "missing required key(s): ${missingKeys.map((s) => "'$s'").join(", ")}";

  /// The [Configuration] in which this exception occurred.
  final Type configuration;

  /// The reason for the exception.
  final String message;

  /// The key of the object being evaluated.
  ///
  /// Either a string (adds '.name') or an int (adds '\[value\]').
  final String keyPath;

  @override
  String toString() {
    final localKeyPath = keyPath.replaceFirst('.', '');
    return "Failed to read key '$localKeyPath' for '$configuration'\n\t-> $message";
  }
}

/// Thrown when [Configuration] subclass is invalid and requires a change in code.
class ConfigurationError {
  ConfigurationError(this.type, this.message);

  /// The type of [Configuration] in which this error appears in.
  final Type type;

  /// The reason for the error.
  String message;

  @override
  String toString() {
    return "Invalid configuration type '$type'. $message";
  }
}
