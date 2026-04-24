# 04 Dart Binding Sketch - JS Interop Path

## Objective
Sketch the generated Dart API for the `adder` component using standard Web APIs via `package:web` and `dart:js_interop`.

## Design

We will generate an extension type for the exports and a wrapper class for the instance.

```dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Extension type for the exports of the adder component.
extension type AdderExports._(JSObject _) implements JSObject {
  /// The exported `add` function.
  /// We use `@JS` to map the potentially complex export name.
  @JS('add') // Fallback to simple name if not mangled, or use full path
  external JSFunction get _add;
}

/// Wrapper class for the instantiated component.
class Adder {
  final web.Instance _instance;
  final AdderExports _exports;

  Adder(this._instance) : _exports = _instance.exports as AdderExports;

  /// Instantiates the component from a stream of bytes (e.g., a fetch response).
  static Future<Adder> instantiateStreaming(Future<web.Response> source) async {
    final promise = web.WebAssembly.instantiateStreaming(source.toJS);
    final result = await promise.toDart;
    return Adder(result.instance);
  }

  /// Instantiates the component from a buffer source.
  static Future<Adder> instantiate(web.BufferSource bytes) async {
    final promise = web.WebAssembly.instantiate(bytes as JSObject);
    final result = await promise.toDart;
    // Result is a WebAssemblyInstantiatedSource when passed bytes
    final instantiated = result as web.WebAssemblyInstantiatedSource;
    return Adder(instantiated.instance);
  }

  /// Calls the exported `add` function, doing the interop work for the user.
  int add(int x, int y) {
    final result = _exports._add.callAsFunction(null, x.toJS, y.toJS) as JSNumber;
    return result.toDartInt;
  }
}
```

## Key Considerations
- **Export Naming**: We use the `@JS` annotation on the extension type getter to map the actual export name (which might be complex like `docs:adder/add#add`) to a clean internal Dart name (like `_add`). This allows us to keep the interop layer typed and clean.
- **Type Conversion**: We use `toJS` and `toDartInt` for numbers. For strings or complex types, we will need more complex conversion logic involving Wasm memory.
- **Component Model Support**: This design assumes the component can be loaded as a core module or that the browser/environment handles the component model translation. If we need to use `jco` or similar, the loading code will change.

## Next Steps
1.  **Verify Export Names**: Check the actual export names in the compiled `.wasm` file or by loading it in a test.
2.  **Implement Generator Prototype**: Create a simple script to generate this code from the JSON WIT definition.

## References
- [00_research_and_exploration.md](./00_research_and_exploration.md)
- [01_wasm_pkg_tools_exploration.md](./01_wasm_pkg_tools_exploration.md)
- [02_creating_rust_component.md](./02_creating_rust_component.md)
- [03_binding_generation_design.md](./03_binding_generation_design.md)
