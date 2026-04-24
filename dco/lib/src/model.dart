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
  final String result;

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
    final result = json['result'] as String;

    return WasmFunction(name: name, params: params, result: result);
  }
}

class WasmParam {
  final String name;
  final String type;

  WasmParam({required this.name, required this.type});

  factory WasmParam.fromJson(Map<String, dynamic> json) {
    return WasmParam(
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }
}
