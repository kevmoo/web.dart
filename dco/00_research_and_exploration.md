# 00 Research and Exploration - Wasm Components in Dart

## Objective
The goal is to enable the use of WebAssembly (Wasm) Components from Dart, targeting the Web (via `dart2js` and `dart2wasm`) and Node.js. We want to generate Dart bindings for Wasm Components, similar to how `js_interop_gen` generates bindings for JavaScript APIs.

## Context
This research is based on the mission outlined in [dco_mission.md](./dco_mission.md).
Key constraints and goals:
- Target the latest stable spec (Preview 3 / v0.3).
- Generate a Dart interface for a component.
- For `dart2wasm`, link directly to the component without a JS bridge if possible.
- For `dart2js`, use a JS bridge.
- Use `wasm-pkg-tools` to find and inspect components.

## Current Status
- [x] Mission document initialized and agent plan drafted in `dco_mission.md`.
- [/] Initial research on Wasm Component Model v0.3.
- [ ] Exploration of `wasm-pkg-tools`.

## Research Log

### 2026-04-24: Initial Setup
- Created this research tracking file.
- Reviewed the mission in `dco_mission.md`.

### 2026-04-24: Initial Research Findings
- Researched Wasm Component Model and WASI versions.
- Confirmed that **WASI 0.2.0** is the current stable release (Jan 2024).
- **WASI 0.3.0 (Preview 3)** is completed (per user sources, as of ~March 2026) and focuses on **concurrency** (async and threads).
- Found that `wkg` (wasm-pkg-tools) is the tool for fetching and publishing components.
- Documentation found online was mostly centered on Preview 2, but Preview 3 is considered done.

### 2026-04-24: Correction on Preview 3 Status
- User clarified that **Preview 3 is DONE** (as of over a month ago). Updated the notes to reflect that the spec is completed, despite some documentation still referencing it as in-progress.



## Next Steps for Future Agent / Self
1.  **Research Wasm Component Model v0.3**:
    - Understand the structure of a Wasm component.
    - Understand WIT (WebAssembly Interface Types) and how it defines interfaces.
2.  **Explore `wasm-pkg-tools`**:
    - Check the repository: https://github.com/bytecodealliance/wasm-pkg-tools
    - See how to use it to inspect components and extract WIT definitions.
3.  **Identify a Test Component**:
    - Find a simple component that complies with the v0.3 spec.
4.  **Analyze Dart Wasm Support**:
    - Check current capabilities of `dart2wasm` regarding component model support.

## References
- [dco_mission.md](./dco_mission.md)
- `wasm-pkg-tools` repo: https://github.com/bytecodealliance/wasm-pkg-tools
