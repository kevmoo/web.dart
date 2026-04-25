# 07 Roadblock: Executing Wasm Components on Web/Node

## Problem
When trying to run the test in Node.js using `dart test -p node`, we encountered the following error:
```
CompileError: WebAssembly.instantiate(): expected version 01 00 00 00, found 0d 00 01 00 @+4
```
This confirms that standard Web APIs (`WebAssembly.instantiate`) expect a **Core Wasm** module (magic number `01 00 00 00`), but we are providing a **Wasm Component** (magic number `0d 00 01 00`).

## Context
As of now, browsers and Node.js do not natively support the Wasm Component Model binary format. They only support Core WebAssembly.

## Proposed Solution
To run a Wasm Component on the web or Node, we need to **transpile** it to a core module and JS glue code using a tool like **`jco`** (JavaScript Component Object).

## Next Steps
1.  Install `@bytecodealliance/jco` via npm. (In progress, task started).
2.  Use `jco transpile` to convert our component.
3.  Update the test to load the transpiled output instead of the raw component file.

## Log
- 2026-04-24: User tried installing via `mise` but encountered an error.
- 2026-04-24: Started local install via `npm install @bytecodealliance/jco` in `dco` directory.


## References
- [00_research_and_exploration.md](./00_research_and_exploration.md)
- [01_wasm_pkg_tools_exploration.md](./01_wasm_pkg_tools_exploration.md)
- [02_creating_rust_component.md](./02_creating_rust_component.md)
- [03_binding_generation_design.md](./03_binding_generation_design.md)
- [04_dart_binding_sketch.md](./04_dart_binding_sketch.md)
- [05_generator_prototype.md](./05_generator_prototype.md)
- [06_make_example_script.md](./06_make_example_script.md)
