// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

/// Generates TypeScript `.d.ts` declarations purely from the decoded
/// `.interop.json` [ir] Map.
///
/// Accepts only JSON-decoded primitives/maps/lists (`Map<String, Object?>`) and
/// has zero dependency on `package:analyzer` or Dart AST types.
String generateDtsFromInteropIr(
  Map<String, Object?> ir, {
  String? globalNameOverride,
}) {
  final buf = StringBuffer()
    ..writeln(
      '// Generated from dist/bridge.interop.json by package:js_interop_gen.',
    )
    ..writeln('// Do not edit by hand.')
    ..writeln();

  final extensionTypesList = _extractExtensionTypesList(ir['extensionTypes']);
  final emittedTypeNames = <String>{};

  for (final ext in extensionTypesList) {
    final name = (ext['name'] ?? ext['jsName'] ?? ext['dartName']) as String;
    emittedTypeNames.add(name);
    final docComment = ext['docComment'] as String?;
    final typeParams = _formatTypeParams(
      ext['typeParameters'] as List<Object?>?,
    );
    final xTsType = ext['x-ts-type'] as String?;
    final callSig =
        (ext['callSignature'] ?? ext['call']) as Map<Object?, Object?>?;
    final indexSig = ext['indexSignature'] as Map<Object?, Object?>?;
    final repType = _asStringMap(
      ext['representationType'] ?? ext['representation'],
    );
    final properties = _asMapList(ext['properties']);
    final factoryParams = _asMapList(ext['literalFactoryParams']);

    _writeJsDoc(buf, docComment);

    if (xTsType != null && xTsType.isNotEmpty) {
      buf
        ..writeln('export type $name$typeParams = $xTsType;')
        ..writeln();
      continue;
    }

    if (callSig != null) {
      final params = _formatFunctionParams(
        _asMapList(callSig['positionalParams'] ?? callSig['parameters']),
        _asMapList(callSig['namedParams']),
      );
      final retTs = _irTypeToTs(
        _asStringMap(callSig['returnType']),
        includeNullUnion: true,
      );
      buf
        ..writeln('export type $name$typeParams = ($params) => $retTs;')
        ..writeln();
      continue;
    }

    if (repType['kind'] == 'externalDartRef') {
      final rawDartType = (repType['dartType'] as String?) ?? name;
      final dartType = rawDartType.split('::').last;
      final brandSym = '__${name}Brand';
      buf
        ..writeln('declare const $brandSym: unique symbol;')
        ..writeln(
          'export type $name$typeParams = '
          '{ readonly [$brandSym]: ${jsonEncode(dartType)} };',
        )
        ..writeln();
      continue;
    }

    if (repType['kind'] == 'primitive' &&
        properties.isEmpty &&
        factoryParams.isEmpty) {
      final primName = (repType['name'] ?? repType['type']) as String? ?? 'any';
      final tsPrim = _primitiveToTs(primName);
      buf
        ..writeln('export type $name$typeParams = $tsPrim;')
        ..writeln();
      continue;
    }

    if (indexSig != null && properties.isEmpty && factoryParams.isEmpty) {
      final keyTs = _irTypeToTs(
        _asStringMap(indexSig['keyType']),
        includeNullUnion: false,
      );
      final valTs = _irTypeToTs(
        _asStringMap(indexSig['valueType']),
        includeNullUnion: true,
      );
      buf
        ..writeln('export type $name$typeParams = Record<$keyTs, $valTs>;')
        ..writeln();
      continue;
    }

    // Object / structural extension type: merge `properties` (from external
    // getters/setters) and `literalFactoryParams` (Trap 1).
    final mergedFields = _mergeExtensionTypeFields(properties, factoryParams);
    buf.writeln('export interface $name$typeParams {');
    for (final field in mergedFields) {
      _writeJsDoc(buf, field.docComment, indent: '  ');
      final readonlyPrefix = field.readonly ? 'readonly ' : '';
      final optSuffix = field.optional ? '?' : '';
      final safeKey = _formatTsPropertyKey(field.jsName);
      buf.writeln('  $readonlyPrefix$safeKey$optSuffix: ${field.tsType};');
    }
    buf
      ..writeln('}')
      ..writeln();
  }

  // Emit `@JSExport` classes as TypeScript interfaces.
  final exportsList = _asMapList(ir['exports']);
  final exportedClassNames = <String>[];
  for (final exp in exportsList) {
    final jsName = (exp['jsName'] ?? exp['name'] ?? exp['dartName']) as String;
    exportedClassNames.add(jsName);
    final docComment = exp['docComment'] as String?;
    _writeJsDoc(buf, docComment);
    buf.writeln('export interface $jsName {');

    final members = _asMapList(exp['members']);
    for (final member in members) {
      final kind = member['kind'] as String;
      final rawMemberName =
          (member['jsName'] ?? member['name'] ?? member['dartName']) as String;
      final mName = _formatTsPropertyKey(rawMemberName);
      final mDoc = member['docComment'] as String?;
      _writeJsDoc(buf, mDoc, indent: '  ');

      switch (kind) {
        case 'field':
          final ro = (member['readonly'] as bool? ?? false) ? 'readonly ' : '';
          final typeMap = _asStringMap(member['type'] ?? member['returnType']);
          final tsType = _irTypeToTs(typeMap, includeNullUnion: true);
          buf.writeln('  $ro$mName: $tsType;');
        case 'getter':
          final retMap = _asStringMap(member['returnType'] ?? member['type']);
          final tsType = _irTypeToTs(retMap, includeNullUnion: true);
          buf.writeln('  readonly $mName: $tsType;');
        case 'setter':
          final typeMap = _asStringMap(member['type'] ?? member['returnType']);
          final tsType = _irTypeToTs(typeMap, includeNullUnion: true);
          buf.writeln('  $mName: $tsType;');
        case 'method':
          final posParams = _asMapList(
            member['positionalParams'] ?? member['parameters'],
          );
          final namedParams = _asMapList(member['namedParams']);
          final paramsStr = _formatFunctionParams(posParams, namedParams);
          final retMap = _asStringMap(member['returnType'] ?? member['type']);
          final retTs = _irTypeToTs(retMap, includeNullUnion: true);
          buf.writeln('  $mName($paramsStr): $retTs;');
      }
    }
    buf
      ..writeln('}')
      ..writeln();
  }

  // Emit `DartBridgeApi` alias for the primary `@JSExport` bridge interface
  // and `Dart*` aliases for `*JS` extension types so consumers can import
  // either naming convention directly from the generated `.d.ts`.
  if (exportedClassNames.isNotEmpty) {
    final primaryBridge = exportedClassNames.first;
    if (primaryBridge != 'DartBridgeApi') {
      buf.writeln('export type DartBridgeApi = $primaryBridge;');
    }
  }
  for (final name in emittedTypeNames) {
    if (name.endsWith('JS') && name.length > 2) {
      final base = name.substring(0, name.length - 2);
      final aliasName = 'Dart$base';
      if (!emittedTypeNames.contains(aliasName)) {
        buf.writeln('export type $aliasName = $name;');
      }
    }
  }
  if (emittedTypeNames.contains('TaxMapEntryJS') &&
      !emittedTypeNames.contains('DartTaxItem')) {
    buf.writeln('export type DartTaxItem = TaxMapEntryJS;');
  }

  final rawGlobals = _asMapList(ir['globalExports'] ?? ir['rootExports']);
  if (globalNameOverride != null && globalNameOverride.isNotEmpty) {
    final jsName = rawGlobals.isNotEmpty
        ? _resolveGlobalJsName(
            rawGlobals.first,
            exportsList,
            exportedClassNames,
          )
        : (exportedClassNames.isNotEmpty
              ? exportedClassNames.first
              : 'unknown');
    buf
      ..writeln()
      ..writeln('declare global {')
      ..writeln('  // eslint-disable-next-line no-var')
      ..writeln('  var $globalNameOverride: $jsName | undefined;')
      ..writeln('}');
  } else if (rawGlobals.isNotEmpty) {
    buf
      ..writeln()
      ..writeln('declare global {');
    for (final reg in rawGlobals) {
      final prop =
          (reg['globalProperty'] ?? reg['globalName'] ?? reg['name']) as String;
      final jsName = _resolveGlobalJsName(reg, exportsList, exportedClassNames);
      buf
        ..writeln('  // eslint-disable-next-line no-var')
        ..writeln('  var $prop: $jsName | undefined;');
    }
    buf.writeln('}');
  }

  return buf.toString();
}

List<Map<String, Object?>> _extractExtensionTypesList(Object? raw) {
  if (raw is Map<Object?, Object?>) {
    return <Map<String, Object?>>[
      for (final entry in raw.entries) _asStringMap(entry.value),
    ];
  }
  if (raw is List<Object?>) {
    return _asMapList(raw);
  }
  return const <Map<String, Object?>>[];
}

String _resolveGlobalJsName(
  Map<String, Object?> reg,
  List<Map<String, Object?>> exportsList,
  List<String> exportedClassNames,
) {
  final direct = (reg['jsName'] ?? reg['interfaceName']) as String?;
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }
  final dartClass = (reg['dartClass'] ?? reg['exportedClass']) as String?;
  if (dartClass != null && dartClass.isNotEmpty) {
    for (final exp in exportsList) {
      if (exp['dartClass'] == dartClass ||
          exp['id'] == dartClass ||
          exp['dartName'] == dartClass) {
        final expJs = (exp['jsName'] ?? exp['name']) as String?;
        if (expJs != null && expJs.isNotEmpty) return expJs;
      }
    }
    return dartClass.split('::').last;
  }
  return exportedClassNames.isNotEmpty ? exportedClassNames.first : 'unknown';
}

class _MergedTsField {
  _MergedTsField({
    required this.jsName,
    required this.tsType,
    required this.optional,
    required this.readonly,
    this.docComment,
  });

  final String jsName;
  final String tsType;
  final bool optional;
  final bool readonly;
  final String? docComment;
}

List<_MergedTsField> _mergeExtensionTypeFields(
  List<Map<String, Object?>> properties,
  List<Map<String, Object?>> factoryParams,
) {
  final isObjectLiteralOutput =
      properties.isEmpty ||
      factoryParams.any((f) => (f['required'] as bool?) == true);
  final propMap = <String, Map<String, Object?>>{
    for (final p in properties)
      ((p['jsName'] ?? p['name'] ?? p['dartName']) as String): p,
  };
  final factoryMap = <String, Map<String, Object?>>{
    for (final f in factoryParams)
      ((f['jsName'] ?? f['name'] ?? f['dartName']) as String): f,
  };

  final orderedKeys = <String>{...factoryMap.keys, ...propMap.keys};

  final result = <_MergedTsField>[];
  for (final key in orderedKeys) {
    final prop = propMap[key];
    final fact = factoryMap[key];
    final doc = (prop?['docComment'] ?? fact?['docComment']) as String?;

    if (isObjectLiteralOutput) {
      final typeMap = _asStringMap(
        fact?['type'] ?? prop?['type'] ?? prop?['getterType'],
      );
      final isNullable = (typeMap['nullable'] as bool?) ?? false;
      final isRequiredInFactory = (fact?['required'] as bool?) ?? !isNullable;

      final optional = !isRequiredInFactory;
      final includeNullUnion = isRequiredInFactory && isNullable;
      final tsType = _irTypeToTs(typeMap, includeNullUnion: includeNullUnion);
      result.add(
        _MergedTsField(
          jsName: key,
          tsType: tsType,
          optional: optional,
          readonly: false,
          docComment: doc,
        ),
      );
    } else {
      final getterTypeMap = _asStringMap(
        prop?['type'] ?? prop?['getterType'] ?? fact?['type'],
      );
      final setterTypeRaw = prop?['setterType'];
      final hasSetter =
          (prop?['hasSetter'] as bool?) ??
          (setterTypeRaw is Map<Object?, Object?>);
      final isReadonly = (prop?['readonly'] as bool?) ?? !hasSetter;
      final isNullable = (getterTypeMap['nullable'] as bool?) ?? true;

      if (!isReadonly && setterTypeRaw is Map<Object?, Object?>) {
        final setterTypeMap = _asStringMap(setterTypeRaw);
        final tsType = _irTypeToTs(setterTypeMap, includeNullUnion: false);
        result.add(
          _MergedTsField(
            jsName: key,
            tsType: tsType,
            optional: isNullable,
            readonly: false,
            docComment: doc,
          ),
        );
      } else {
        final tsType = _irTypeToTs(
          getterTypeMap,
          includeNullUnion: isNullable,
          inReadonlyContext: isReadonly,
        );
        result.add(
          _MergedTsField(
            jsName: key,
            tsType: tsType,
            optional: isNullable,
            readonly: isReadonly,
            docComment: doc,
          ),
        );
      }
    }
  }
  return result;
}

String _formatFunctionParams(
  List<Map<String, Object?>> positionalParams,
  List<Map<String, Object?>> namedParams,
) {
  final parts = <String>[];
  for (final param in positionalParams) {
    final name = (param['name'] ?? param['jsName']) as String;
    final required = (param['required'] as bool?) ?? true;
    final typeMap = _asStringMap(param['type']);
    final isNullable = (typeMap['nullable'] as bool?) ?? false;
    final opt = !required ? '?' : '';
    final tsType = _irTypeToTs(typeMap, includeNullUnion: isNullable);
    parts.add('$name$opt: $tsType');
  }
  if (namedParams.isNotEmpty) {
    final namedFields = <String>[];
    for (final param in namedParams) {
      final rawName = (param['jsName'] ?? param['name']) as String;
      final name = _formatTsPropertyKey(rawName);
      final required = (param['required'] as bool?) ?? false;
      final typeMap = _asStringMap(param['type']);
      final isNullable = (typeMap['nullable'] as bool?) ?? false;
      final opt = !required ? '?' : '';
      final tsType = _irTypeToTs(
        typeMap,
        includeNullUnion: required && isNullable,
      );
      namedFields.add('$name$opt: $tsType');
    }
    parts.add('options?: { ${namedFields.join('; ')} }');
  }
  return parts.join(', ');
}

String _irTypeToTs(
  Map<String, Object?> typeMap, {
  required bool includeNullUnion,
  bool inReadonlyContext = false,
}) {
  final kind = (typeMap['kind'] as String?) ?? 'any';
  final isNullable = (typeMap['nullable'] as bool?) ?? false;

  String baseTs;
  switch (kind) {
    case 'primitive':
      final name = (typeMap['name'] ?? typeMap['type']) as String? ?? 'any';
      if (name == 'Null') {
        return 'null';
      }
      baseTs = _primitiveToTs(name);
    case 'jsBuiltin':
      baseTs = _jsBuiltinToTs(typeMap, inReadonlyContext: inReadonlyContext);
    case 'extensionType':
    case 'interface':
      final rawName =
          (typeMap['name'] as String?) ??
          (typeMap['id'] as String?)?.split('::').last ??
          'unknown';
      final typeArgs = _asMapList(typeMap['typeArgs']);
      if (typeArgs.isEmpty) {
        baseTs = rawName;
      } else {
        final formattedArgs = typeArgs
            .map((a) => _irTypeToTs(a, includeNullUnion: true))
            .join(', ');
        baseTs = '$rawName<$formattedArgs>';
      }
    case 'externalDartRef':
      final rawDartType = (typeMap['dartType'] as String?) ?? 'Object';
      final dartType = rawDartType.split('::').last;
      baseTs = '{ readonly __dartRef: ${jsonEncode(dartType)} }';
    case 'future':
      final typeArgs = _asMapList(typeMap['typeArgs']);
      final inner = typeArgs.isEmpty
          ? 'unknown'
          : _irTypeToTs(typeArgs.first, includeNullUnion: true);
      baseTs = 'Promise<$inner>';
    case 'function':
      final pos = _asMapList(
        typeMap['positionalParams'] ?? typeMap['parameters'],
      );
      final ret = _asStringMap(typeMap['returnType']);
      final paramsStr = _formatFunctionParams(
        pos,
        const <Map<String, Object?>>[],
      );
      final retStr = _irTypeToTs(ret, includeNullUnion: true);
      baseTs = '(($paramsStr) => $retStr)';
    case 'typeParam':
      baseTs = (typeMap['name'] as String?) ?? 'unknown';
    default:
      baseTs = 'unknown';
  }

  if (includeNullUnion &&
      isNullable &&
      baseTs != 'void' &&
      baseTs != 'any' &&
      baseTs != 'unknown' &&
      !baseTs.contains('| null')) {
    return '$baseTs | null';
  }
  return baseTs;
}

String _primitiveToTs(String dartPrimitive) {
  switch (dartPrimitive) {
    case 'bool':
      return 'boolean';
    case 'int':
    case 'double':
    case 'num':
      return 'number';
    case 'String':
      return 'string';
    case 'void':
      return 'void';
    case 'never':
    case 'Never':
      return 'never';
    case 'Null':
      return 'null';
    default:
      return 'unknown';
  }
}

String _jsBuiltinToTs(
  Map<String, Object?> typeMap, {
  bool inReadonlyContext = false,
}) {
  final name = (typeMap['name'] as String?) ?? 'JSAny';
  final typeArgs = _asMapList(typeMap['typeArgs']);
  switch (name) {
    case 'JSBoolean':
      return 'boolean';
    case 'JSNumber':
      return 'number';
    case 'JSString':
      return 'string';
    case 'JSBigInt':
      return 'bigint';
    case 'JSSymbol':
      return 'symbol';
    case 'JSAny':
      return 'unknown';
    case 'JSObject':
      return 'Record<string, unknown>';
    case 'JSFunction':
    case 'JSExportedDartFunction':
      return '(...args: unknown[]) => unknown';
    case 'JSArray':
      final elemTs = typeArgs.isEmpty
          ? 'unknown'
          : _irTypeToTs(
              typeArgs.first,
              includeNullUnion: (typeArgs.first['nullable'] as bool?) ?? false,
            );
      final needsParens = elemTs.contains('|') || elemTs.contains('=>');
      final wrappedElem = needsParens ? '($elemTs)' : elemTs;
      return inReadonlyContext ? 'readonly $wrappedElem[]' : '$wrappedElem[]';
    case 'JSPromise':
      final elemTs = typeArgs.isEmpty
          ? 'unknown'
          : _irTypeToTs(
              typeArgs.first,
              includeNullUnion: (typeArgs.first['nullable'] as bool?) ?? false,
            );
      return 'Promise<$elemTs>';
    case 'JSUint8Array':
      return 'Uint8Array';
    case 'JSUint8ClampedArray':
      return 'Uint8ClampedArray';
    case 'JSInt8Array':
      return 'Int8Array';
    case 'JSUint16Array':
      return 'Uint16Array';
    case 'JSInt16Array':
      return 'Int16Array';
    case 'JSUint32Array':
      return 'Uint32Array';
    case 'JSInt32Array':
      return 'Int32Array';
    case 'JSFloat32Array':
      return 'Float32Array';
    case 'JSFloat64Array':
      return 'Float64Array';
    case 'JSArrayBuffer':
      return 'ArrayBuffer';
    case 'JSDataView':
      return 'DataView';
    default:
      return 'unknown';
  }
}

String _formatTypeParams(List<Object?>? rawTypeParams) {
  if (rawTypeParams == null || rawTypeParams.isEmpty) return '';
  final names = <String>[];
  for (final item in rawTypeParams) {
    if (item is String) {
      names.add(item);
    } else {
      final map = _asStringMap(item);
      final name = map['name'] as String;
      names.add(name);
    }
  }
  return '<${names.join(', ')}>';
}

String _formatTsPropertyKey(String key) {
  if (RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(key)) {
    return key;
  }
  return jsonEncode(key);
}

void _writeJsDoc(StringBuffer buf, String? doc, {String indent = ''}) {
  if (doc == null || doc.trim().isEmpty) return;
  final lines = doc.trim().split('\n');
  if (lines.length == 1) {
    buf.writeln('$indent/** ${lines.first} */');
    return;
  }
  buf.writeln('$indent/**');
  for (final line in lines) {
    if (line.isEmpty) {
      buf.writeln('$indent *');
    } else {
      buf.writeln('$indent * $line');
    }
  }
  buf.writeln('$indent */');
}

Map<String, Object?> _asStringMap(Object? raw) {
  if (raw is Map<String, Object?>) return raw;
  if (raw is Map<Object?, Object?>) {
    return <String, Object?>{
      for (final entry in raw.entries) entry.key.toString(): entry.value,
    };
  }
  return const <String, Object?>{};
}

List<Map<String, Object?>> _asMapList(Object? raw) {
  if (raw is! List<Object?>) return const <Map<String, Object?>>[];
  return <Map<String, Object?>>[for (final item in raw) _asStringMap(item)];
}
