# 03 Binding Generation Design

## Objective
Design a generator that takes a Wasm Component (or its WIT definition) and produces a Dart interface to interact with it.

## Input
- A compiled Wasm Component (`.wasm` file) containing its WIT definition.
- Or a standalone WIT file (`.wit`).

## Output
- A Dart file containing:
    - An interface or class representing the component.
    - Methods corresponding to the exported functions.
    - Type mappings from Wasm Component types to Dart types.

## Extraction Strategy
- Use `wasm-tools component wit <file> --json` to extract the WIT definition as a JSON document.
- This avoids the need to write a WIT parser in Dart.

## Type Mapping Strategy (Initial Thoughts)
- `u32` -> `int`
- `u64` -> `int` (Safe up to 53 bits on web without special handling, full 64-bit on `dart2wasm`).
- `string` -> `String` (Requires handling memory allocation/deallocation in Wasm memory).
- More complex types (records, variants) will need custom Dart classes or extension types.

## Target Environments
1.  **Web APIs (via package:web)**: We will use standard Web APIs like `WebAssembly.instantiate` to load and invoke the module. This allows us to bootstrap quickly and run on the web (both `dart2js` and `dart2wasm` can use these APIs).
2.  **dart2wasm (Future)**: Direct linking or minimal overhead invocation without a JS bridge is deferred as it might require changes to how `dart2wasm` works.

## Proposed Workflow for Generator
1.  **Extract**: Run `wasm-tools component wit <file> --json` and capture the output.
2.  **Parse**: Parse the JSON in Dart to build an AST or model of the component interface.
3.  **Generate**: Emit Dart code that uses `package:web` to load and call the component.

## Pivot to JS Bindings
- **Decision**: Start with JS bindings using standard Web APIs instead of direct `dart2wasm` linking.
- **Rationale**: Direct linking in `dart2wasm` might require compiler changes. Using Web APIs allows quick bootstrapping and compatibility across `dart2js` and `dart2wasm`.
- **Reference**: Confirmed that `package:web` exposes `WebAssembly` APIs in `wasm_js_api.dart`.

## Next Steps
1.  **Run Extraction on Test Component**: Run `wasm-tools component wit _wasm_rust_example.wasm --json` to see what the JSON looks like. (Done!)
2.  **Analyze JSON Structure**: Understand the schema of the JSON emitted by `wasm-tools`. (Done!)
3.  **Design JS Binding API**: Design the Dart API that uses `package:web` to load and call the component.


## Example JSON Output
Here is the JSON output for our test component:
```json
{
  "worlds": [
    {
      "name": "root",
      "imports": {},
      "exports": {
        "interface-0": {
          "interface": {
            "id": 0
          }
        }
      },
      "package": 1
    }
  ],
  "interfaces": [
    {
      "name": "add",
      "types": {},
      "functions": {
        "add": {
          "name": "add",
          "kind": "freestanding",
          "params": [
            {
              "name": "x",
              "type": "u64"
            },
            {
              "name": "y",
              "type": "u64"
            }
          ],
          "result": "u64"
        }
      },
      "package": 0
    }
  ],
  "types": [],
  "packages": [
    {
      "name": "docs:adder@0.1.0",
      "interfaces": {
        "add": 0
      },
      "worlds": {}
    },
    {
      "name": "root:component",
      "interfaces": {},
      "worlds": {
        "root": 0
      }
    }
  ]
}
```


## References
- [00_research_and_exploration.md](./00_research_and_exploration.md)
- [01_wasm_pkg_tools_exploration.md](./01_wasm_pkg_tools_exploration.md)
- [02_creating_rust_component.md](./02_creating_rust_component.md)
