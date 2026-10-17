// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Canonical JSON IR schema version string (`1.0.0`).
const String interopIrVersion = '1.0.0';

/// Canonical integer schema version (`1`) for backward compatibility with
/// Stage 2 `.interop.json` consumers.
const int interopIrSchemaVersion = 1;

/// Top-level and nested property keys for the `.interop.json` sidecar schema.
abstract final class InteropIrKeys {
  static const String schemaVersion = 'schemaVersion';
  static const String version = 'version';
  static const String entryLibrary = 'entryLibrary';
  static const String rootExports = 'rootExports';
  static const String globalExports = 'globalExports';
  static const String exports = 'exports';
  static const String extensionTypes = 'extensionTypes';

  // Root / global export entry keys.
  static const String globalName = 'globalName';
  static const String globalProperty = 'globalProperty';
  static const String dartClass = 'dartClass';
  static const String jsName = 'jsName';

  // Exported class & member keys.
  static const String dartName = 'dartName';
  static const String docComment = 'docComment';
  static const String members = 'members';
  static const String kind = 'kind';
  static const String readonly = 'readonly';
  static const String type = 'type';
  static const String returnType = 'returnType';
  static const String positionalParams = 'positionalParams';
  static const String namedParams = 'namedParams';
  static const String name = 'name';
  static const String required = 'required';

  // Extension type keys.
  static const String id = 'id';
  static const String representationType = 'representationType';
  static const String erasedRepresentationType = 'erasedRepresentationType';
  static const String typeParameters = 'typeParameters';
  static const String bound = 'bound';
  static const String implements_ = 'implements';
  static const String properties = 'properties';
  static const String literalFactoryParams = 'literalFactoryParams';
  static const String methods = 'methods';
  static const String callSignature = 'callSignature';
  static const String indexSignature = 'indexSignature';
  static const String keyType = 'keyType';
  static const String valueType = 'valueType';
  static const String xTsType = 'x-ts-type';
  static const String setterType = 'setterType';
  static const String hasGetter = 'hasGetter';
  static const String hasSetter = 'hasSetter';

  // Type node keys.
  static const String nullable = 'nullable';
  static const String typeArgs = 'typeArgs';
  static const String dartType = 'dartType';
}

/// Discriminator values for type nodes (`type['kind']`) across the 5 closed
/// `_isAllowedExternalType` categories in `pkg/_js_interop_checks`.
abstract final class InteropIrTypeKind {
  /// Category 1: Dart primitives (`void`, `never`, `Null`, `bool`, `int`,
  /// `double`, `num`, `String`).
  static const String primitive = 'primitive';

  /// Category 2: Core `dart:js_interop` built-in extension types (`JSAny`,
  /// `JSObject`, `JSArray`, `JSPromise`, `JSFunction`, `JSUint8Array`, etc.).
  static const String jsBuiltin = 'jsBuiltin';

  /// Category 3: Opaque Dart heap reference (`ExternalDartReference<T>`).
  static const String externalDartRef = 'externalDartRef';

  /// Category 4: Async return types (`Future<T>` / `FutureOr<T>`).
  static const String future = 'future';

  /// Category 5: User-defined JS interop `extension type`s.
  static const String extensionType = 'extensionType';

  /// Function type node (`R Function(...)`).
  static const String function = 'function';

  /// Generic type parameter reference (`T`).
  static const String typeParam = 'typeParam';

  /// General interface reference fallback.
  static const String interface = 'interface';

  /// Dynamic or top type (`dynamic`, `Object?`).
  static const String any = 'any';
}

/// Discriminator values for `@JSExport` class member nodes (`member['kind']`).
abstract final class InteropIrMemberKind {
  static const String field = 'field';
  static const String getter = 'getter';
  static const String setter = 'setter';
  static const String method = 'method';
}

/// Allowed Dart primitive type names in Category 1 of `_isAllowedExternalType`.
const Set<String> allowedInteropPrimitives = <String>{
  'void',
  'never',
  'Null',
  'bool',
  'int',
  'double',
  'num',
  'String',
};

/// Core `dart:js_interop` built-in extension type names in Category 2 of
/// `_isAllowedExternalType`.
const Set<String> coreJsBuiltinTypes = <String>{
  'JSAny',
  'JSObject',
  'JSFunction',
  'JSExportedDartFunction',
  'JSArray',
  'JSPromise',
  'JSBoxedDartObject',
  'JSArrayBuffer',
  'JSDataView',
  'JSTypedArray',
  'JSInt8Array',
  'JSUint8Array',
  'JSUint8ClampedArray',
  'JSInt16Array',
  'JSUint16Array',
  'JSInt32Array',
  'JSUint32Array',
  'JSFloat32Array',
  'JSFloat64Array',
  'JSNumber',
  'JSBoolean',
  'JSString',
  'JSSymbol',
  'JSBigInt',
  'ExternalDartReference',
};

/// Coerces a decoded JSON [raw] object to a `Map<String, Object?>`.
Map<String, Object?> asIrStringMap(Object? raw) {
  if (raw is Map<String, Object?>) return raw;
  if (raw is Map) {
    return <String, Object?>{
      for (final entry in raw.entries) entry.key.toString(): entry.value,
    };
  }
  return const <String, Object?>{};
}

/// Coerces a decoded JSON [raw] list to a `List<Map<String, Object?>>`.
List<Map<String, Object?>> asIrMapList(Object? raw) {
  if (raw is! List) return const <Map<String, Object?>>[];
  return <Map<String, Object?>>[for (final item in raw) asIrStringMap(item)];
}

/// Validates that [ir] conforms to the JS Interop JSON IR schema (`1.0.0` / `1`).
///
/// Throws a [FormatException] if required top-level fields are missing or have
/// incompatible types.
void validateInteropIr(Map<String, Object?> ir) {
  final schemaVer = ir[InteropIrKeys.schemaVersion];
  final ver = ir[InteropIrKeys.version];
  final hasValidVersion =
      schemaVer == interopIrSchemaVersion ||
      schemaVer == interopIrVersion ||
      ver == interopIrVersion;
  if (!hasValidVersion) {
    throw FormatException(
      'Unsupported or missing JS Interop IR schemaVersion: '
      'expected $interopIrSchemaVersion or "$interopIrVersion", '
      'got schemaVersion=$schemaVer, version=$ver.',
    );
  }

  final exports = ir[InteropIrKeys.exports];
  if (exports is! List) {
    throw const FormatException(
      'Invalid JS Interop IR: "exports" must be a JSON List.',
    );
  }

  final extensionTypes = ir[InteropIrKeys.extensionTypes];
  if (extensionTypes is! Map) {
    throw const FormatException(
      'Invalid JS Interop IR: "extensionTypes" must be a JSON Map.',
    );
  }
}

/// Returns `true` if [ir] passes [validateInteropIr] without throwing.
bool isValidInteropIr(Map<String, Object?> ir) {
  try {
    validateInteropIr(ir);
    return true;
  } on FormatException {
    return false;
  }
}
