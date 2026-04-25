class WitModel {
  final List<WasmPackage> packages;
  final List<WasmComponentInterface> interfaces;
  final List<WasmWorld> worlds;

  WitModel({
    required this.packages,
    required this.interfaces,
    required this.worlds,
  });

  factory WitModel.fromJson(Map<String, dynamic> json) {
    final packagesList = json['packages'] as List<dynamic>;
    final packages = packagesList
        .map((p) => WasmPackage.fromJson(p as Map<String, dynamic>))
        .toList();

    final interfacesList = json['interfaces'] as List<dynamic>;
    final interfaces = interfacesList
        .map((i) => WasmComponentInterface.fromJson(i as Map<String, dynamic>))
        .toList();

    final worldsList = json['worlds'] as List<dynamic>;
    final worlds = worldsList
        .map((w) => WasmWorld.fromJson(w as Map<String, dynamic>))
        .toList();

    return WitModel(packages: packages, interfaces: interfaces, worlds: worlds);
  }
}

class WasmPackage {
  final String name;
  final String namespace;
  final String packageName;
  final String version;

  WasmPackage({
    required this.name,
    required this.namespace,
    required this.packageName,
    required this.version,
  });

  factory WasmPackage.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final parts = name.split('@');
    final nameWithoutVersion = parts[0];
    final version = parts.length > 1 ? '@${parts[1]}' : '';

    final nameParts = nameWithoutVersion.split(':');
    final namespace = nameParts[0];
    final packageName = nameParts.length > 1 ? nameParts[1] : '';

    return WasmPackage(
      name: name,
      namespace: namespace,
      packageName: packageName,
      version: version,
    );
  }
}

class WasmComponentInterface {
  final String name;
  final List<WasmFunction> functions;

  WasmComponentInterface({required this.name, required this.functions});

  factory WasmComponentInterface.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final functionsMap = json['functions'] as Map<String, dynamic>;
    final functions = functionsMap.entries.map((e) {
      final funcJson = e.value as Map<String, dynamic>;
      return WasmFunction.fromJson(funcJson);
    }).toList();

    return WasmComponentInterface(name: name, functions: functions);
  }
}

class WasmFunction {
  final String name;
  final List<WasmParam> params;
  final WitType? result;

  WasmFunction({
    required this.name,
    required this.params,
    required this.result,
  });

  factory WasmFunction.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final paramsList = json['params'] as List<dynamic>;
    final params = paramsList
        .map((p) => WasmParam.fromJson(p as Map<String, dynamic>))
        .toList();
    final result = json['result'] != null
        ? WitType(json['result'] as Object)
        : null;

    return WasmFunction(name: name, params: params, result: result);
  }
}

class WasmParam {
  final String name;
  final WitType type;

  WasmParam({required this.name, required this.type});

  factory WasmParam.fromJson(Map<String, dynamic> json) => WasmParam(
    name: json['name'] as String,
    type: WitType(json['type'] as Object),
  );
}

class WasmWorld {
  final String name;
  final Map<String, dynamic> exports;

  WasmWorld({required this.name, required this.exports});

  factory WasmWorld.fromJson(Map<String, dynamic> json) => WasmWorld(
    name: json['name'] as String,
    exports: json['exports'] as Map<String, dynamic>,
  );
}

// Sealed class for WIT types
sealed class WitType {
  WitType._();

  factory WitType(Object value) {
    if (value is String) return PrimitiveWitType(value);
    if (value is int) return ReferenceWitType(value);
    throw ArgumentError('Invalid WIT type: $value');
  }
}

class PrimitiveWitType extends WitType {
  final String name;
  PrimitiveWitType(this.name) : super._();
}

class ReferenceWitType extends WitType {
  final int id;
  ReferenceWitType(this.id) : super._();
}
