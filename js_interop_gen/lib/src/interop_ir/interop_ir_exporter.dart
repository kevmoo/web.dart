// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:path/path.dart' as p;

import 'interop_ir_schema.dart';

/// Stage 1 pure-Dart analyzer exporter that resolves a Dart JS interop entry
/// library and serializes its `@JSExport` classes, transitively referenced
/// `extension type`s, `ExternalDartReference<T>` handles, and global wrapper
/// registrations into the canonical `.interop.json` IR.
class InteropIrExporter {
  const InteropIrExporter({this.packageRoot, this.includedPaths});

  /// Optional package root directory for `AnalysisContextCollection`.
  final String? packageRoot;

  /// Optional explicit list of included paths for `AnalysisContextCollection`.
  final List<String>? includedPaths;

  /// Resolves [entryFilePath] and returns its JSON-serializable Interop IR map.
  Future<Map<String, Object?>> export(
    String entryFilePath, {
    String? packageRoot,
    List<String>? includedPaths,
  }) => extractInteropIr(
    entryFilePath,
    packageRoot: packageRoot ?? this.packageRoot,
    includedPaths: includedPaths ?? this.includedPaths,
  );

  /// Alias for [export].
  Future<Map<String, Object?>> extract(
    String entryFilePath, {
    String? packageRoot,
    List<String>? includedPaths,
  }) => export(
    entryFilePath,
    packageRoot: packageRoot,
    includedPaths: includedPaths,
  );
}

/// Extracts the strictly-scoped JS Interop Types JSON Sidecar IR from
/// [entryFilePath] and its reachable package libraries.
///
/// If neither [packageRoot] nor [includedPaths] is provided, walks up from the
/// directory containing [entryFilePath] to find the nearest directory with a
/// `pubspec.yaml` (falling back to `dirname(entryFilePath)` for standalone
/// temporary test directories).
Future<Map<String, Object?>> extractInteropIr(
  String entryFilePath, {
  String? packageRoot,
  List<String>? includedPaths,
}) async {
  final normalizedEntry = p.normalize(p.absolute(entryFilePath));
  final resolvedPaths = _resolveIncludedPaths(
    normalizedEntry,
    packageRoot: packageRoot,
    includedPaths: includedPaths,
  );

  final collection = AnalysisContextCollection(includedPaths: resolvedPaths);
  final context = collection.contextFor(normalizedEntry);
  final session = context.currentSession;

  final resolvedResult = await session.getResolvedLibrary(normalizedEntry);
  if (resolvedResult is! ResolvedLibraryResult) {
    throw StateError(
      'Failed to resolve entry library at $normalizedEntry: $resolvedResult',
    );
  }

  final entryLibrary = resolvedResult.element;
  final targetPackagePrefix = _packagePrefix(entryLibrary.uri);

  // Collect all libraries in the same package reachable from the entry library.
  final packageLibraries = <Uri, LibraryElement>{};
  void collectLibraries(LibraryElement lib) {
    if (packageLibraries.containsKey(lib.uri)) return;
    if (!_belongsToPackage(lib.uri, targetPackagePrefix)) return;
    packageLibraries[lib.uri] = lib;
    for (final exported in lib.exportedLibraries) {
      collectLibraries(exported);
    }
    for (final fragment in lib.fragments) {
      for (final imp in fragment.libraryImports) {
        final imported = imp.importedLibrary;
        if (imported != null) {
          collectLibraries(imported);
        }
      }
      for (final exp in fragment.libraryExports) {
        final exported = exp.exportedLibrary;
        if (exported != null) {
          collectLibraries(exported);
        }
      }
    }
  }

  collectLibraries(entryLibrary);

  final extQueue = Queue<ExtensionTypeElement>();
  final seenExtIds = <String>{};

  void enqueueExtensionType(ExtensionTypeElement el) {
    if (el.library.isInSdk) return;
    final id = _elementId(el);
    if (seenExtIds.add(id)) {
      extQueue.add(el);
    }
  }

  // Seed extension types defined in or exported by the package libraries so
  // all public JS interop extension types are included.
  for (final expEl in entryLibrary.exportNamespace.definedNames2.values) {
    if (expEl is ExtensionTypeElement && !expEl.library.isInSdk) {
      enqueueExtensionType(expEl);
    }
  }
  for (final lib in packageLibraries.values) {
    for (final ext in lib.extensionTypes) {
      if (ext.isPublic) {
        enqueueExtensionType(ext);
      }
    }
  }

  // Find all `@JSExport`-annotated classes across package libraries.
  final exportedClasses = <ClassElement>[];
  final seenClasses = <String>{};
  void enqueueExportedClass(ClassElement cls) {
    final id = _elementId(cls);
    if (seenClasses.add(id)) {
      exportedClasses.add(cls);
    }
  }

  for (final lib in packageLibraries.values) {
    for (final cls in lib.classes) {
      if (_hasJsExportAnnotation(cls) || _hasAnyJsExportMember(cls)) {
        enqueueExportedClass(cls);
      }
    }
  }

  // Discover `createJSInteropWrapper<T>` + `globalContext.setProperty(...)`
  // registrations in the entry library AST.
  final rootExports = <Map<String, Object?>>[];
  for (final unitResult in resolvedResult.units) {
    final finder = _GlobalWrapperFinder(onWrappedClass: enqueueExportedClass);
    unitResult.unit.accept(finder);
    rootExports.addAll(finder.registrations);
  }

  // Serialize `@JSExport` classes and enqueue any referenced extension types.
  final exportsJson = <Map<String, Object?>>[];
  for (final cls in exportedClasses) {
    exportsJson.add(_serializeExportedClass(cls, enqueueExtensionType));
  }

  // Transitively serialize all queued `ExtensionTypeElement`s.
  final extensionTypesJson = <String, Object?>{};
  while (extQueue.isNotEmpty) {
    final ext = extQueue.removeFirst();
    final id = _elementId(ext);
    extensionTypesJson[id] = _serializeExtensionType(ext, enqueueExtensionType);
  }

  return <String, Object?>{
    InteropIrKeys.schemaVersion: interopIrSchemaVersion,
    InteropIrKeys.version: interopIrVersion,
    InteropIrKeys.entryLibrary: entryLibrary.uri.toString(),
    InteropIrKeys.rootExports: rootExports,
    if (rootExports.isNotEmpty) InteropIrKeys.globalExports: rootExports,
    InteropIrKeys.exports: exportsJson,
    InteropIrKeys.extensionTypes: extensionTypesJson,
  };
}

List<String> _resolveIncludedPaths(
  String normalizedEntry, {
  String? packageRoot,
  List<String>? includedPaths,
}) {
  if (includedPaths != null && includedPaths.isNotEmpty) {
    return includedPaths.map((path) => p.normalize(p.absolute(path))).toList();
  }
  if (packageRoot != null && packageRoot.isNotEmpty) {
    return <String>[p.normalize(p.absolute(packageRoot))];
  }
  return <String>[_findNearestPackageRoot(normalizedEntry)];
}

String _findNearestPackageRoot(String normalizedEntryFile) {
  final entryDir = p.dirname(normalizedEntryFile);
  var dir = entryDir;
  while (true) {
    if (File(p.join(dir, 'pubspec.yaml')).existsSync()) {
      return dir;
    }
    final parent = p.dirname(dir);
    if (parent == dir) {
      break;
    }
    dir = parent;
  }
  return entryDir;
}

String _packagePrefix(Uri uri) {
  if (uri.scheme == 'package' && uri.pathSegments.isNotEmpty) {
    return 'package:${uri.pathSegments.first}/';
  }
  return p.dirname(uri.toString());
}

bool _belongsToPackage(Uri uri, String packagePrefix) =>
    uri.toString().startsWith(packagePrefix);

String _elementId(Element element) {
  final libUri = element.library?.uri.toString() ?? '';
  return '$libUri::${element.displayName}';
}

bool _hasJsExportAnnotation(Element element) {
  for (final ann in element.metadata.annotations) {
    if (_annotationClassName(ann) == 'JSExport') return true;
  }
  return false;
}

bool _hasAnyJsExportMember(ClassElement cls) {
  for (final m in cls.methods) {
    if (!m.isStatic && _hasJsExportAnnotation(m)) return true;
  }
  for (final g in cls.getters) {
    if (!g.isStatic && _hasJsExportAnnotation(g)) return true;
  }
  for (final s in cls.setters) {
    if (!s.isStatic && _hasJsExportAnnotation(s)) return true;
  }
  for (final f in cls.fields) {
    if (!f.isStatic && _hasJsExportAnnotation(f)) return true;
  }
  return false;
}

String? _annotationClassName(ElementAnnotation annotation) {
  final el = annotation.element;
  if (el is ConstructorElement) {
    return el.enclosingElement.name;
  }
  if (el is PropertyAccessorElement) {
    return el.name;
  }
  final obj = annotation.computeConstantValue();
  return obj?.type?.element?.name;
}

String? _extractAnnotationNameArg(
  Element element,
  String targetAnnotationClass,
) {
  final annotations = <ElementAnnotation>[
    ...element.metadata.annotations,
    if (element is PropertyAccessorElement)
      ...element.variable.metadata.annotations,
  ];
  for (final ann in annotations) {
    if (_annotationClassName(ann) != targetAnnotationClass) continue;
    final obj = ann.computeConstantValue();
    if (obj == null) continue;
    final fromField = obj.getField('name')?.toStringValue();
    if (fromField != null && fromField.isNotEmpty) {
      return fromField;
    }
    final posArgs = obj.constructorInvocation?.positionalArguments;
    if (posArgs != null && posArgs.isNotEmpty) {
      final firstStr = posArgs.first.toStringValue();
      if (firstStr != null && firstStr.isNotEmpty) {
        return firstStr;
      }
    }
  }
  return null;
}

String? _extractJsName(Element element) =>
    _extractAnnotationNameArg(element, 'JS');

String? _extractJsExportName(Element element) =>
    _extractAnnotationNameArg(element, 'JSExport');

bool _isExternalAccessor(PropertyAccessorElement accessor) {
  if (accessor.isExternal) return true;
  final variable = accessor.variable;
  return variable is FieldElement && variable.isExternal;
}

String? _cleanDocComment(String? rawDoc) {
  if (rawDoc == null || rawDoc.trim().isEmpty) return null;
  final lines = rawDoc.split('\n').map((line) {
    var trimmed = line.trim();
    if (trimmed.startsWith('///')) {
      trimmed = trimmed.substring(3);
      if (trimmed.startsWith(' ')) trimmed = trimmed.substring(1);
    } else if (trimmed.startsWith('/**')) {
      trimmed = trimmed.substring(3);
    } else if (trimmed.endsWith('*/')) {
      trimmed = trimmed.substring(0, trimmed.length - 2);
    } else if (trimmed.startsWith('*')) {
      trimmed = trimmed.substring(1);
      if (trimmed.startsWith(' ')) trimmed = trimmed.substring(1);
    }
    return trimmed.trimRight();
  }).toList();
  final joined = lines.join('\n').trim();
  return joined.isEmpty ? null : joined;
}

Map<String, Object?> _serializeExportedClass(
  ClassElement cls,
  void Function(ExtensionTypeElement) onExtensionType,
) {
  final classHasExport = _hasJsExportAnnotation(cls);
  final customClassName = _extractJsExportName(cls);
  final jsName = (customClassName != null && customClassName.isNotEmpty)
      ? customClassName
      : cls.displayName;
  final doc = _cleanDocComment(cls.documentationComment);

  final members = <Map<String, Object?>>[];

  // Instance fields (explicitly declared)
  for (final field in cls.fields) {
    if (field.isStatic || !field.isPublic || field.isAbstract) continue;
    if (!field.isOriginDeclaration) continue;
    if (!classHasExport && !_hasJsExportAnnotation(field)) continue;
    final fieldJsName =
        _extractJsExportName(field) ??
        _extractJsName(field) ??
        field.displayName;
    final fieldDoc = _cleanDocComment(field.documentationComment);
    members.add(<String, Object?>{
      InteropIrKeys.kind: InteropIrMemberKind.field,
      InteropIrKeys.dartName: field.displayName,
      InteropIrKeys.jsName: fieldJsName,
      InteropIrKeys.docComment: ?fieldDoc,
      InteropIrKeys.readonly: field.isFinal || field.isConst,
      InteropIrKeys.type: _serializeType(field.type, onExtensionType),
    });
  }

  // Explicit instance getters
  for (final getter in cls.getters) {
    if (getter.isStatic || !getter.isPublic || getter.isAbstract) continue;
    if (!getter.isOriginDeclaration) continue;
    if (!classHasExport && !_hasJsExportAnnotation(getter)) continue;
    final getterJsName =
        _extractJsExportName(getter) ??
        _extractJsName(getter) ??
        getter.displayName;
    final getterDoc = _cleanDocComment(getter.documentationComment);
    members.add(<String, Object?>{
      InteropIrKeys.kind: InteropIrMemberKind.getter,
      InteropIrKeys.dartName: getter.displayName,
      InteropIrKeys.jsName: getterJsName,
      InteropIrKeys.docComment: ?getterDoc,
      InteropIrKeys.returnType: _serializeType(
        getter.returnType,
        onExtensionType,
      ),
    });
  }

  // Explicit instance setters
  for (final setter in cls.setters) {
    if (setter.isStatic || !setter.isPublic || setter.isAbstract) continue;
    if (!setter.isOriginDeclaration) continue;
    if (!classHasExport && !_hasJsExportAnnotation(setter)) continue;
    final setterJsName =
        _extractJsExportName(setter) ??
        _extractJsName(setter) ??
        setter.displayName;
    final setterDoc = _cleanDocComment(setter.documentationComment);
    final paramType = setter.formalParameters.isNotEmpty
        ? setter.formalParameters.first.type
        : setter.returnType;
    members.add(<String, Object?>{
      InteropIrKeys.kind: InteropIrMemberKind.setter,
      InteropIrKeys.dartName: setter.displayName,
      InteropIrKeys.jsName: setterJsName,
      InteropIrKeys.docComment: ?setterDoc,
      InteropIrKeys.type: _serializeType(paramType, onExtensionType),
    });
  }

  // Instance methods
  for (final method in cls.methods) {
    if (method.isStatic ||
        !method.isPublic ||
        method.isAbstract ||
        method.isOperator) {
      continue;
    }
    if (!classHasExport && !_hasJsExportAnnotation(method)) continue;
    final methodJsName =
        _extractJsExportName(method) ??
        _extractJsName(method) ??
        method.displayName;
    final methodDoc = _cleanDocComment(method.documentationComment);

    final positionalParams = <Map<String, Object?>>[];
    final namedParams = <Map<String, Object?>>[];
    for (final param in method.formalParameters) {
      final paramJson = <String, Object?>{
        InteropIrKeys.name: param.displayName,
        InteropIrKeys.required: param.isRequired,
        InteropIrKeys.type: _serializeType(param.type, onExtensionType),
      };
      if (param.isNamed) {
        namedParams.add(paramJson);
      } else {
        positionalParams.add(paramJson);
      }
    }

    members.add(<String, Object?>{
      InteropIrKeys.kind: InteropIrMemberKind.method,
      InteropIrKeys.dartName: method.displayName,
      InteropIrKeys.jsName: methodJsName,
      InteropIrKeys.docComment: ?methodDoc,
      InteropIrKeys.positionalParams: positionalParams,
      if (namedParams.isNotEmpty) InteropIrKeys.namedParams: namedParams,
      InteropIrKeys.returnType: _serializeType(
        method.returnType,
        onExtensionType,
      ),
    });
  }

  return <String, Object?>{
    InteropIrKeys.dartClass: _elementId(cls),
    InteropIrKeys.dartName: cls.displayName,
    InteropIrKeys.jsName: jsName,
    InteropIrKeys.docComment: ?doc,
    InteropIrKeys.members: members,
  };
}

Map<String, Object?> _serializeExtensionType(
  ExtensionTypeElement ext,
  void Function(ExtensionTypeElement) onExtensionType,
) {
  final doc = _cleanDocComment(ext.documentationComment);
  final repType = _serializeType(ext.representation.type, onExtensionType);
  final erasedRepType = _serializeType(ext.typeErasure, onExtensionType);

  final typeParams = <Map<String, Object?>>[];
  for (final tp in ext.typeParameters) {
    typeParams.add(<String, Object?>{
      InteropIrKeys.name: tp.displayName,
      if (tp.bound != null)
        InteropIrKeys.bound: _serializeType(tp.bound!, onExtensionType),
    });
  }

  final implementsList = <String>[];
  for (final iface in ext.interfaces) {
    if (iface.isDartCoreObject) continue;
    implementsList.add(iface.element.displayName);
    final ifaceEl = iface.element;
    if (ifaceEl is ExtensionTypeElement && !ifaceEl.library.isInSdk) {
      onExtensionType(ifaceEl);
    }
  }

  // 1. Collect `external` getters and setters (grouping by resolved `jsName`
  //    and linking `correspondingSetter`).
  final propByJsName = <String, _ExtensionPropRecord>{};
  final dartNameToJsName = <String, String>{};

  for (final getter in ext.getters) {
    if (getter.isStatic || !getter.isPublic) continue;
    if (!_isExternalAccessor(getter)) continue;

    final jsName = _extractJsName(getter) ?? getter.displayName;
    dartNameToJsName[getter.displayName] = jsName;
    final propDoc = _cleanDocComment(
      getter.documentationComment ?? getter.variable.documentationComment,
    );
    final serializedGetterType = _serializeType(
      getter.returnType,
      onExtensionType,
    );

    final record = propByJsName.putIfAbsent(
      jsName,
      () => _ExtensionPropRecord(dartName: getter.displayName, jsName: jsName),
    );
    record.hasGetter = true;
    record.getterType = serializedGetterType;
    record.docComment ??= propDoc;

    final corrSetter = getter.correspondingSetter;
    if (corrSetter != null && _isExternalAccessor(corrSetter)) {
      record.hasSetter = true;
      if (corrSetter.formalParameters.isNotEmpty) {
        record.setterType = _serializeType(
          corrSetter.formalParameters.first.type,
          onExtensionType,
        );
      }
    }
  }

  for (final setter in ext.setters) {
    if (setter.isStatic || !setter.isPublic) continue;
    if (!_isExternalAccessor(setter)) continue;

    final jsName =
        _extractJsName(setter) ??
        dartNameToJsName[setter.displayName] ??
        setter.displayName;
    final propDoc = _cleanDocComment(
      setter.documentationComment ?? setter.variable.documentationComment,
    );
    final paramType = setter.formalParameters.isNotEmpty
        ? _serializeType(setter.formalParameters.first.type, onExtensionType)
        : null;

    final record = propByJsName.putIfAbsent(
      jsName,
      () => _ExtensionPropRecord(dartName: setter.displayName, jsName: jsName),
    );
    record.hasSetter = true;
    if (paramType != null) {
      record.setterType = paramType;
    }
    record.docComment ??= propDoc;
  }

  final propertiesJson = <Map<String, Object?>>[
    for (final prop in propByJsName.values) prop.toJson(),
  ];

  // 2. Collect `literalFactoryParams` from any `external` object-literal
  //    constructor (where all parameters are named).
  final literalFactoryParams = <Map<String, Object?>>[];
  final seenFactoryParamJsNames = <String>{};
  for (final ctor in ext.constructors) {
    if (!ctor.isExternal) continue;
    if (ctor.formalParameters.isEmpty) continue;
    if (!ctor.formalParameters.every((p) => p.isNamed)) continue;

    for (final param in ctor.formalParameters) {
      final jsName = _extractJsName(param) ?? param.displayName;
      if (!seenFactoryParamJsNames.add(jsName)) continue;
      literalFactoryParams.add(<String, Object?>{
        InteropIrKeys.dartName: param.displayName,
        InteropIrKeys.jsName: jsName,
        InteropIrKeys.required: param.isRequiredNamed,
        InteropIrKeys.type: _serializeType(param.type, onExtensionType),
      });
    }
  }

  // 3. Check for `external` `call` method (Trap 3: closure extension types),
  //    `external` index operator `operator []`, and regular `external` methods.
  Map<String, Object?>? callSignature;
  Map<String, Object?>? indexSignature;
  final methodsJson = <Map<String, Object?>>[];

  for (final method in ext.methods) {
    if (!method.isExternal || method.isStatic || !method.isPublic) continue;
    if (method.displayName == 'call') {
      callSignature = <String, Object?>{
        InteropIrKeys.positionalParams: <Map<String, Object?>>[
          for (final p in method.formalParameters.where((p) => p.isPositional))
            <String, Object?>{
              InteropIrKeys.name: p.displayName,
              InteropIrKeys.required: p.isRequiredPositional,
              InteropIrKeys.type: _serializeType(p.type, onExtensionType),
            },
        ],
        InteropIrKeys.returnType: _serializeType(
          method.returnType,
          onExtensionType,
        ),
      };
    } else if (method.displayName == '[]' &&
        method.formalParameters.length == 1) {
      indexSignature = <String, Object?>{
        InteropIrKeys.keyType: _serializeType(
          method.formalParameters.first.type,
          onExtensionType,
        ),
        InteropIrKeys.valueType: _serializeType(
          method.returnType,
          onExtensionType,
        ),
      };
    } else if (!method.isOperator) {
      final methodJsName = _extractJsName(method) ?? method.displayName;
      final methodDoc = _cleanDocComment(method.documentationComment);
      final positionalParams = <Map<String, Object?>>[];
      final namedParams = <Map<String, Object?>>[];
      for (final param in method.formalParameters) {
        final paramJson = <String, Object?>{
          InteropIrKeys.name: param.displayName,
          InteropIrKeys.required: param.isRequired,
          InteropIrKeys.type: _serializeType(param.type, onExtensionType),
        };
        if (param.isNamed) {
          namedParams.add(paramJson);
        } else {
          positionalParams.add(paramJson);
        }
      }
      methodsJson.add(<String, Object?>{
        InteropIrKeys.kind: InteropIrMemberKind.method,
        InteropIrKeys.dartName: method.displayName,
        InteropIrKeys.jsName: methodJsName,
        InteropIrKeys.docComment: ?methodDoc,
        InteropIrKeys.positionalParams: positionalParams,
        if (namedParams.isNotEmpty) InteropIrKeys.namedParams: namedParams,
        InteropIrKeys.returnType: _serializeType(
          method.returnType,
          onExtensionType,
        ),
      });
    }
  }

  // 4. Check for explicit or convention-based `x-ts-type` mapping for scalar
  //    unions and dynamic-key Record maps.
  final xTsType = _inferSpecialTsType(
    name: ext.displayName,
    docComment: doc,
    repType: repType,
    properties: propertiesJson,
    literalFactoryParams: literalFactoryParams,
  );

  return <String, Object?>{
    InteropIrKeys.id: _elementId(ext),
    InteropIrKeys.name: ext.displayName,
    InteropIrKeys.docComment: ?doc,
    InteropIrKeys.representationType: repType,
    InteropIrKeys.erasedRepresentationType: erasedRepType,
    InteropIrKeys.typeParameters: typeParams,
    InteropIrKeys.implements_: implementsList,
    InteropIrKeys.properties: propertiesJson,
    InteropIrKeys.literalFactoryParams: literalFactoryParams,
    if (methodsJson.isNotEmpty) InteropIrKeys.methods: methodsJson,
    InteropIrKeys.callSignature: ?callSignature,
    InteropIrKeys.indexSignature: ?indexSignature,
    InteropIrKeys.xTsType: ?xTsType,
  };
}

String? _inferSpecialTsType({
  required String name,
  required String? docComment,
  required Map<String, Object?> repType,
  required List<Map<String, Object?>> properties,
  required List<Map<String, Object?>> literalFactoryParams,
}) {
  if (docComment != null) {
    final match = RegExp(
      r'(?:@tsType|x-ts-type:)\s*([^\n]+)',
    ).firstMatch(docComment);
    if (match != null) {
      return match.group(1)!.trim();
    }
  }
  switch (name) {
    case 'JSNumOrString':
      return 'number | string';
    case 'JSStringMap':
    case 'JSStringRecord':
      return 'Record<string, string>';
    case 'JSNumberMap':
    case 'JSNumberRecord':
    case 'JSIntMap':
      return 'Record<string, number>';
    case 'JSNumOrStringMap':
    case 'JSNumOrStringRecord':
    case 'JSExchangeRateMap':
    case 'JSCurrencyTotalsMap':
      return 'Record<string, number | string>';
    case 'JSNestedCurrencyMap':
    case 'JSPerCurrencyTotalsMap':
      return 'Record<string, Record<string, number | string>>';
    default:
      if (properties.isEmpty &&
          literalFactoryParams.isEmpty &&
          repType[InteropIrKeys.kind] == InteropIrTypeKind.jsBuiltin &&
          repType[InteropIrKeys.name] == 'JSAny' &&
          name.toLowerCase().contains('numorstring')) {
        return 'number | string';
      }
      return null;
  }
}

Map<String, Object?> _serializeType(
  DartType type,
  void Function(ExtensionTypeElement) onExtensionType,
) {
  final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;

  if (type is VoidType) {
    return <String, Object?>{
      InteropIrKeys.kind: InteropIrTypeKind.primitive,
      InteropIrKeys.name: 'void',
      InteropIrKeys.nullable: false,
    };
  }
  if (type is NeverType) {
    return <String, Object?>{
      InteropIrKeys.kind: InteropIrTypeKind.primitive,
      InteropIrKeys.name: 'never',
      InteropIrKeys.nullable: false,
    };
  }
  if (type is DynamicType || type is InvalidType) {
    return <String, Object?>{
      InteropIrKeys.kind: InteropIrTypeKind.any,
      InteropIrKeys.name: 'any',
      InteropIrKeys.nullable: true,
    };
  }
  if (type is TypeParameterType) {
    return <String, Object?>{
      InteropIrKeys.kind: InteropIrTypeKind.typeParam,
      InteropIrKeys.name: type.element.displayName,
      InteropIrKeys.nullable: isNullable,
    };
  }
  if (type is FunctionType) {
    return <String, Object?>{
      InteropIrKeys.kind: InteropIrTypeKind.function,
      InteropIrKeys.nullable: isNullable,
      InteropIrKeys.positionalParams: <Map<String, Object?>>[
        for (final p in type.formalParameters.where((p) => p.isPositional))
          <String, Object?>{
            InteropIrKeys.name: p.displayName,
            InteropIrKeys.required: p.isRequiredPositional,
            InteropIrKeys.type: _serializeType(p.type, onExtensionType),
          },
      ],
      InteropIrKeys.returnType: _serializeType(
        type.returnType,
        onExtensionType,
      ),
    };
  }
  if (type is InterfaceType) {
    if (type.isDartCoreNull) {
      return <String, Object?>{
        InteropIrKeys.kind: InteropIrTypeKind.primitive,
        InteropIrKeys.name: 'Null',
        InteropIrKeys.nullable: true,
      };
    }
    if (type.isDartCoreBool) {
      return <String, Object?>{
        InteropIrKeys.kind: InteropIrTypeKind.primitive,
        InteropIrKeys.name: 'bool',
        InteropIrKeys.nullable: isNullable,
      };
    }
    if (type.isDartCoreInt) {
      return <String, Object?>{
        InteropIrKeys.kind: InteropIrTypeKind.primitive,
        InteropIrKeys.name: 'int',
        InteropIrKeys.nullable: isNullable,
      };
    }
    if (type.isDartCoreDouble) {
      return <String, Object?>{
        InteropIrKeys.kind: InteropIrTypeKind.primitive,
        InteropIrKeys.name: 'double',
        InteropIrKeys.nullable: isNullable,
      };
    }
    if (type.isDartCoreNum) {
      return <String, Object?>{
        InteropIrKeys.kind: InteropIrTypeKind.primitive,
        InteropIrKeys.name: 'num',
        InteropIrKeys.nullable: isNullable,
      };
    }
    if (type.isDartCoreString) {
      return <String, Object?>{
        InteropIrKeys.kind: InteropIrTypeKind.primitive,
        InteropIrKeys.name: 'String',
        InteropIrKeys.nullable: isNullable,
      };
    }
    if (type.isDartCoreObject) {
      return <String, Object?>{
        InteropIrKeys.kind: InteropIrTypeKind.any,
        InteropIrKeys.name: 'Object',
        InteropIrKeys.nullable: isNullable,
      };
    }
    if (type.isDartAsyncFuture || type.isDartAsyncFutureOr) {
      return <String, Object?>{
        InteropIrKeys.kind: InteropIrTypeKind.future,
        InteropIrKeys.name: type.element.displayName,
        InteropIrKeys.typeArgs: <Map<String, Object?>>[
          for (final arg in type.typeArguments)
            _serializeType(arg, onExtensionType),
        ],
        InteropIrKeys.nullable: isNullable,
      };
    }

    final el = type.element;
    if (el.displayName == 'ExternalDartReference') {
      final targetType = type.typeArguments.isNotEmpty
          ? type.typeArguments.first.getDisplayString()
          : 'Object?';
      return <String, Object?>{
        InteropIrKeys.kind: InteropIrTypeKind.externalDartRef,
        InteropIrKeys.dartType: targetType,
        InteropIrKeys.nullable: isNullable,
      };
    }

    if (el is ExtensionTypeElement) {
      if (el.library.isInSdk) {
        return <String, Object?>{
          InteropIrKeys.kind: InteropIrTypeKind.jsBuiltin,
          InteropIrKeys.name: el.displayName,
          if (type.typeArguments.isNotEmpty)
            InteropIrKeys.typeArgs: <Map<String, Object?>>[
              for (final arg in type.typeArguments)
                _serializeType(arg, onExtensionType),
            ],
          InteropIrKeys.nullable: isNullable,
        };
      }
      onExtensionType(el);
      return <String, Object?>{
        InteropIrKeys.kind: InteropIrTypeKind.extensionType,
        InteropIrKeys.id: _elementId(el),
        InteropIrKeys.name: el.displayName,
        if (type.typeArguments.isNotEmpty)
          InteropIrKeys.typeArgs: <Map<String, Object?>>[
            for (final arg in type.typeArguments)
              _serializeType(arg, onExtensionType),
          ],
        InteropIrKeys.nullable: isNullable,
      };
    }

    return <String, Object?>{
      InteropIrKeys.kind: InteropIrTypeKind.interface,
      InteropIrKeys.id: _elementId(el),
      InteropIrKeys.name: el.displayName,
      if (type.typeArguments.isNotEmpty)
        InteropIrKeys.typeArgs: <Map<String, Object?>>[
          for (final arg in type.typeArguments)
            _serializeType(arg, onExtensionType),
        ],
      InteropIrKeys.nullable: isNullable,
    };
  }

  return <String, Object?>{
    InteropIrKeys.kind: InteropIrTypeKind.any,
    InteropIrKeys.name: type.getDisplayString(),
    InteropIrKeys.nullable: isNullable,
  };
}

class _ExtensionPropRecord {
  _ExtensionPropRecord({required this.dartName, required this.jsName});

  final String dartName;
  final String jsName;
  String? docComment;
  bool hasGetter = false;
  bool hasSetter = false;
  Map<String, Object?>? getterType;
  Map<String, Object?>? setterType;

  Map<String, Object?> toJson() {
    final effectiveType =
        getterType ??
        setterType ??
        <String, Object?>{
          InteropIrKeys.kind: InteropIrTypeKind.any,
          InteropIrKeys.name: 'any',
          InteropIrKeys.nullable: true,
        };
    return <String, Object?>{
      InteropIrKeys.dartName: dartName,
      InteropIrKeys.jsName: jsName,
      InteropIrKeys.docComment: ?docComment,
      InteropIrKeys.type: effectiveType,
      InteropIrKeys.setterType: ?setterType,
      InteropIrKeys.hasGetter: hasGetter,
      InteropIrKeys.hasSetter: hasSetter,
      InteropIrKeys.readonly: !hasSetter,
    };
  }
}

class _GlobalWrapperFinder extends RecursiveAstVisitor<void> {
  _GlobalWrapperFinder({required this.onWrappedClass});

  final void Function(ClassElement) onWrappedClass;
  final List<Map<String, Object?>> registrations = <Map<String, Object?>>[];
  final Map<String, InterfaceType> _localWrapperVars =
      <String, InterfaceType>{};

  InterfaceType? _extractWrappedType(MethodInvocation invocation) {
    if (invocation.methodName.name != 'createJSInteropWrapper') return null;

    final typeArgs = invocation.typeArguments?.arguments;
    if (typeArgs != null && typeArgs.isNotEmpty) {
      final t = typeArgs.first.type;
      if (t is InterfaceType) return t;
    }

    final inferredArgs = invocation.typeArgumentTypes;
    if (inferredArgs != null && inferredArgs.isNotEmpty) {
      final first = inferredArgs.first;
      if (first is InterfaceType) return first;
    }

    final args = invocation.argumentList.arguments;
    if (args.isNotEmpty) {
      final firstArg = args.first;
      if (firstArg is Expression) {
        final argType = firstArg.staticType;
        if (argType is InterfaceType) return argType;
      }
    }
    return null;
  }

  String? _extractPropertyName(AstNode expr) {
    if (expr is SimpleStringLiteral) {
      return expr.value;
    }
    if (expr is PropertyAccess &&
        expr.propertyName.name == 'toJS' &&
        expr.target is SimpleStringLiteral) {
      return (expr.target as SimpleStringLiteral).value;
    }
    return null;
  }

  InterfaceType? _resolveWrapperValue(AstNode expr) {
    if (expr is SimpleIdentifier) {
      return _localWrapperVars[expr.name];
    }
    if (expr is MethodInvocation) {
      return _extractWrappedType(expr);
    }
    return null;
  }

  void _recordRegistration(String propName, InterfaceType wrappedType) {
    final clsEl = wrappedType.element;
    if (clsEl is ClassElement) {
      onWrappedClass(clsEl);
    }
    final jsName = _extractJsExportName(clsEl) ?? clsEl.displayName;
    registrations.add(<String, Object?>{
      InteropIrKeys.globalName: propName,
      InteropIrKeys.globalProperty: propName,
      InteropIrKeys.dartClass: _elementId(clsEl),
      InteropIrKeys.jsName: jsName,
    });
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final init = node.initializer;
    if (init is MethodInvocation) {
      final wrappedType = _extractWrappedType(init);
      if (wrappedType != null) {
        _localWrapperVars[node.name.lexeme] = wrappedType;
        final clsEl = wrappedType.element;
        if (clsEl is ClassElement) {
          onWrappedClass(clsEl);
        }
      }
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final directWrapped = _extractWrappedType(node);
    if (directWrapped != null) {
      final clsEl = directWrapped.element;
      if (clsEl is ClassElement) {
        onWrappedClass(clsEl);
      }
    }

    if (node.methodName.name == 'setProperty' &&
        node.argumentList.arguments.length == 2) {
      final keyArg = node.argumentList.arguments[0];
      final valArg = node.argumentList.arguments[1];
      final propName = _extractPropertyName(keyArg);
      final wrappedType = _resolveWrapperValue(valArg);
      if (propName != null && wrappedType != null) {
        _recordRegistration(propName, wrappedType);
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final lhs = node.leftHandSide;
    if (lhs is IndexExpression) {
      final propName = _extractPropertyName(lhs.index);
      final wrappedType = _resolveWrapperValue(node.rightHandSide);
      if (propName != null && wrappedType != null) {
        _recordRegistration(propName, wrappedType);
      }
    }
    super.visitAssignmentExpression(node);
  }
}
