import 'dart:convert';

import 'package:conduit_runtime/runtime.dart';
import 'package:conduit_runtime/src/mirror_coerce.dart';
import 'package:test/test.dart';

import 'coerce_test.reflectable.dart';

void main() {
  initializeReflectable();
  T? mirrorCoerce<T>(dynamic input) {
    return runtimeCast(input, T) as T?;
  }

  void testInvocation(String suiteName, T? Function<T>(dynamic input) coerce) {
    group("($suiteName) Primitive Types (success)", () {
      test("dynamic", () {
        expect(coerce(wash("foo")), "foo");
        expect(coerce(null), null);
      });

      test("int", () {
        expect(coerce<int>(wash(2)), 2);
        expect(coerce<int>(null), null);
      });

      test("String", () {
        expect(coerce<String>(wash("string")), "string");
        expect(coerce<String>(null), null);
      });
      test("bool", () {
        expect(coerce<bool>(wash(true)), true);
        expect(coerce<bool>(null), null);
      });
      test("num", () {
        expect(coerce<num>(wash(3.2)), 3.2);
        expect(coerce<num>(null), null);

        expect(coerce<int>(wash(3)), 3);
      });
      test("double", () {
        expect(coerce<double>(wash(3.2)), 3.2);
        expect(coerce<double>(null), null);
      });
    });

    group("($suiteName) Primitive Types (cast error)", () {
      test("int fail", () {
        try {
          coerce<int>(wash("foo"));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, 'int');
          expect(e.actualType, String);
        }
      });
      test("String fail", () {
        try {
          coerce<String>(wash(5));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, 'String');
          expect(e.actualType, int);
        }
      });
      test("bool fail", () {
        try {
          coerce<bool>(wash("foo"));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, 'bool');
          expect(e.actualType, String);
        }
      });
      test("num fail", () {
        try {
          coerce<num>(wash("foo"));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, 'num');
          expect(e.actualType, String);
        }
      });
      test("double fail", () {
        try {
          coerce<double>(wash("foo"));
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, 'double');
          expect(e.actualType, String);
        }
      });
    });

    group("($suiteName) List Types (success)", () {
      test("null/empty", () {
        expect(runtimeCastList(null, String), null);
        expect(runtimeCastList([], String), []);
      });

      test("int", () {
        expect(
          runtimeCastList(wash([2, 4]), int),
          [2, 4],
        );
      });

      test("String", () {
        expect(
          runtimeCastList(wash(["a", "b", "c"]), String),
          ["a", "b", "c"],
        );
      });

      test("num", () {
        expect(
          runtimeCastList(wash([3.0, 2]), num),
          [3.0, 2],
        );
      });

      test("bool", () {
        expect(runtimeCastList(wash([false, true]), bool), [false, true]);
      });

      test("list of map", () {
        expect(
            runtimeCastListOfMaps(
                wash([
                  {"a": "b"},
                  null,
                  {"a": 1}
                ]),
                dynamic),
            [
              {"a": "b"},
              null,
              {"a": 1}
            ]);

        expect(runtimeCastListOfMaps(null, dynamic), null);
        expect(runtimeCastListOfMaps([], dynamic), <Map<String, dynamic>>[]);
      });
    });

    group("($suiteName) List Types (cast error)", () {
      test("heterogenous", () {
        try {
          runtimeCastList(wash(["x", 4]), int);
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, "List<int>");
          expect(e.actualType.toString(), "List<dynamic>");
        }
      });

      test("outer list ok, inner list not ok", () {
        try {
          runtimeCastListOfLists(
              wash([
                ["foo", 3],
                ["baz"]
              ]),
              String);
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, "List<List<String>>");
          expect(e.actualType.toString(), "List<dynamic>");
        }
      });

      test("list of map, inner map not ok", () {
        try {
          runtimeCastListOfMaps(
              wash([
                {"a": 1},
                {"a": "b"}
              ]),
              int);
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, "List<Map<String, int>>");
          expect(e.actualType.toString(), "List<dynamic>");
        }
      });
    });

    group("($suiteName) Map types (success)", () {
      test("null", () {
        expect(
          runtimeCastMap(null, dynamic),
          null,
        );
      });

      test("string->dynamic", () {
        expect(
          runtimeCastMap(wash({"a": 1, "b": "c"}), dynamic),
          {"a": 1, "b": "c"},
        );
      });

      test("string->int", () {
        expect(
          runtimeCastMap(wash({"a": 1, "b": 2}), int),
          {"a": 1, "b": 2},
        );
      });

      test("string->num", () {
        expect(
          runtimeCastMap(wash({"a": 1, "b": 2.0}), num),
          {"a": 1, "b": 2.0},
        );
      });

      test("string->string", () {
        expect(
          runtimeCastMap(wash({"a": "1", "b": "2.0"}), String),
          {"a": "1", "b": "2.0"},
        );
      });
    });

    group("($suiteName) Map types (failure)", () {
      test("bad key type", () {
        try {
          // Note: this input is not 'washed' as the wash function encodes/decodes via json, and this would be invalid json
          // But for the purpose of this test, we want an untyped map, which this input is
          runtimeCastMap(<dynamic, dynamic>{"a": 1, 2: "c"}, dynamic);
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, "Map<String, dynamic>");
          expect(e.actualType.toString(), endsWith("Map<dynamic, dynamic>"));
        }
      });

      test("bad val type", () {
        try {
          runtimeCastMap(wash({"a": 1, "b": "foo"}), int);
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, "Map<String, int>");
          expect(e.actualType.toString(), endsWith("Map<String, dynamic>"));
        }
      });

      test("nested list has invalid element", () {
        try {
          runtimeCastMapOfLists(
              wash({
                "a": [2]
              }),
              String);
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, "Map<String, List<String>>");
          expect(e.actualType.toString(), endsWith("Map<String, dynamic>"));
        }
      });

      test("nested map has invalid value type", () {
        try {
          runtimeCastMapOfMaps(wash({"a": []}), int);
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, "Map<String, Map<String, int>>");
          expect(e.actualType.toString(), endsWith("Map<String, dynamic>"));
        }

        try {
          runtimeCastMapOfMaps(
              wash({
                "a": {"b": "foo"}
              }),
              int);
          fail('unreachable');
        } on TypeCoercionException catch (e) {
          expect(e.expectedType, "Map<String, Map<String, int>>");
          expect(e.actualType.toString(), endsWith("Map<String, dynamic>"));
        }
      });
    });
  }

  testInvocation("mirrored", mirrorCoerce);
}

dynamic wash(dynamic input) {
  return json.decode(json.encode(input));
}
