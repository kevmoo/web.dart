// ignore_for_file: unnecessary_parenthesis

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:js_interop' as _i1;
import 'dart:js_interop_unsafe';

@_i1.JS('eval')
external _i1.JSAny jsEval(String code);
@_i1.JS('BigInt')
external _i1.JSAny jsBigInt(String value);

class Add {
  Add(this._module);

  final _i1.JSObject _module;

  static Future<Add> load(String modulePath) async {
    final promise = (jsEval('import("$modulePath")') as _i1.JSPromise);
    final module = (await promise.toDart as _i1.JSObject);
    return Add(module);
  }

  int add(int x, int y) {
    final iface = (_module.getProperty('add'.toJS) as _i1.JSObject);
    final func = (iface.getProperty('add'.toJS) as _i1.JSFunction);
    final result = func.callAsFunction(
      null,
      jsBigInt(x.toString()),
      jsBigInt(y.toString()),
    );
    return int.parse(result.toString());
  }

  String greet(String name) {
    final iface = (_module.getProperty('add'.toJS) as _i1.JSObject);
    final func = (iface.getProperty('greet'.toJS) as _i1.JSFunction);
    final result = (func.callAsFunction(null, name.toJS) as _i1.JSString);
    return result.toDart;
  }
}
