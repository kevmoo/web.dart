https://github.com/bytecodealliance/wasm-pkg-tools

There are Wasm Components out in the world.

I'd like to be able to use from from Dart on the Web (and Node).

(VM will have to be much later.)

Just like js_interop_gen, I'd like to be able to point to component and generate
a Dart interface for it.

When compiling for the web, I'd love to have the compiled Wasm code link directly
to the Wasm component without a JS bridge.

Obviously, we'll need a JS bridge for dart2js output code.

I think there was just a "preview 3" or v0.3 release.

Ideally we'd target the latest stable spec.

I was thinking we could use wasm-pkg-tools to find a publish component that fits
the v0.3 spec and generate bindings for it.

## Agent plan

1. **Research & Exploration**:
   - Study the WebAssembly Component Model (specifically v0.3 / Preview 3).
   - Investigate `wasm-pkg-tools` to understand how to fetch and inspect components.
   - Research existing Dart efforts or discussions around Wasm Components.

2. **Component Identification**:
   - Find a simple, standard Wasm component that adheres to the v0.3 spec to use as a test case.

3. **Binding Generation Design**:
   - Determine how to parse the component's interface (likely WIT - WebAssembly Interface Types).
   - Design the Dart API mapping for component types and functions.
   - Plan the integration with `package:web` and JS interop.

4. **Implementation**:
   - Develop a prototype generator (potentially leveraging `wasm-pkg-tools` or similar parsers).
   - Implement the JS bridge generator for `dart2js` compatibility.
   - Explore direct linking strategies for `dart2wasm`.

5. **Validation**:
   - Generate bindings for the test component.
   - Create a sample application (Web and Node) to verify functionality.

