# 02 Creating a Rust Component

## Objective
Create a simple Wasm component in Rust to use as a test case for generating Dart bindings.

## Current Status
- [x] Initialize Rust project in `_wasm_rust_example`.
- [x] Add WIT interface definition (updated to u64).
- [x] Implement the component in Rust (updated to u64 and fixed import).
- [x] Build targeting `wasm32-wasip2`.
- [x] Verify built component with `wasm-tools`.

## Log

### 2026-04-24: Project Directory Provided
- User provided directory: `/Users/kevmoo/github/web/_wasm_rust_example`.
- Directory contains only `README.md`.
- Plan to use `cargo init --lib` to initialize the project.

### 2026-04-24: Project Setup & Implementation
- Initialized project with `cargo init --lib`.
- Configured `Cargo.toml` with `crate-type = ["cdylib"]`.
- Added `wit-bindgen` dependency.
- Created `wit/world.wit` with `adder` interface.
- Implemented `AdderComponent` in `src/lib.rs`.
- Added `wasm32-wasip2` target via `rustup`.

### 2026-04-24: Correction & Rebuild (64-bit ints)
- Updated `wit/world.wit` and `src/lib.rs` to use `u64` instead of `u32` per user request.
- Fixed missing import in `src/lib.rs` (`use super::AdderComponent;`).
- Built successfully in release mode: `target/wasm32-wasip2/release/_wasm_rust_example.wasm`.
- Verified with `wasm-tools component wit`, confirming export of `docs:adder/add` with `u64` types.



## Next Steps
1.  **Initialize Project**: Run `cargo init --lib` in `/Users/kevmoo/github/web/_wasm_rust_example`.
2.  **Configure Cargo.toml**: Set `crate-type = ["cdylib"]`.
3.  **Add WIT**: Create `wit/world.wit`.
4.  **Generate Bindings & Implement**: Use `wit-bindgen` and implement the trait.
5.  **Build**: Run `cargo build --target=wasm32-wasip2`.

## References
- [00_research_and_exploration.md](./00_research_and_exploration.md)
- [01_wasm_pkg_tools_exploration.md](./01_wasm_pkg_tools_exploration.md)
