import 'dart:js_interop';

import 'package:web/web.dart' as web;

extension type AddExports._(JSObject _) implements JSObject {
  @JS('add')
  external JSFunction get _add;
}

class Add {
  Add(web.Instance instance) : _exports = instance.exports as AddExports;

  final AddExports _exports;

  static Future<Add> instantiateStreaming(Future<web.Response> source) async {
    final promise = web.WebAssembly.instantiateStreaming(source.toJS);
    final result = await promise.toDart;
    return Add(result.instance);
  }

  static Future<Add> instantiate(web.BufferSource bytes) async {
    final promise = web.WebAssembly.instantiate(bytes);
    final result = await promise.toDart;
    final instantiated = result as web.WebAssemblyInstantiatedSource;
    return Add(instantiated.instance);
  }

  int add(int x, int y) {
    final result =
        _exports._add.callAsFunction(null, x.toJS, y.toJS) as JSNumber;
    return result.toDartInt;
  }
}
