import 'package:code_builder/code_builder.dart' as code;
import 'model.dart';
import 'type_mapper.dart';
import 'utils.dart';

class StructGenerator {
  final TypeMapper _typeMapper;

  StructGenerator(List<WasmType> types) : _typeMapper = TypeMapper(types);

  code.ExtensionType generateStruct(WasmRecordType record) {
    final name = record.name;
    if (name == null) {
      throw ArgumentError('Cannot generate bindings for anonymous record.');
    }

    final className = capitalize(name);

    final getters = <code.Method>[];

    for (final field in record.fields) {
      getters.add(
        code.Method(
          (b) => b
            ..name = field.name
            ..type = code.MethodType.getter
            ..external = true
            ..returns = _typeMapper.mapDartType(field.type),
        ),
      );
    }

    return code.ExtensionType(
      (b) => b
        ..name = className
        ..primaryConstructorName = '_'
        ..representationDeclaration = code.RepresentationDeclaration(
          (b) => b
            ..name = '_'
            ..declaredRepresentationType = code.refer(
              'JSObject',
              'dart:js_interop',
            ),
        )
        ..implements.add(code.refer('JSObject', 'dart:js_interop'))
        ..methods.addAll(getters),
    );
  }
}
