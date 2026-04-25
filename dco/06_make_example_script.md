# 06 Orchestration Script - make_example.dart

## Objective
Create a script to automate the full pipeline: Build Rust -> Extract WIT -> Generate Bindings.

## Implementation
- Created `dco/tool/make_example.dart`.
- It performs the following steps:
    1. Runs `cargo build` in `_wasm_rust_example`.
    2. Runs `wasm-tools component wit` to extract JSON.
    3. Runs `dart run dco:generate_bindings` to generate bindings.

## Current Status
- [x] Script created at `dco/tool/make_example.dart`.
- [ ] Verify the script by running it.

## Next Steps
1.  Run `dart tool/make_example.dart` from `dco` directory.
2.  Verify that it rebuilds the component and regenerates bindings.

## References
- [00_research_and_exploration.md](./00_research_and_exploration.md)
- [01_wasm_pkg_tools_exploration.md](./01_wasm_pkg_tools_exploration.md)
- [02_creating_rust_component.md](./02_creating_rust_component.md)
- [03_binding_generation_design.md](./03_binding_generation_design.md)
- [04_dart_binding_sketch.md](./04_dart_binding_sketch.md)
- [05_generator_prototype.md](./05_generator_prototype.md)
