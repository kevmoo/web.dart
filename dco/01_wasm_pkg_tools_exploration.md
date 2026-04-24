# 01 Exploration of wasm-pkg-tools (wkg)

## Objective
Explore the `wkg` tool to understand how to fetch, inspect, and publish Wasm Components. We want to see if we can use it to get WIT definitions for Preview 3 components.

## Current Status
- [x] Install `wkg` via `cargo install wkg`.
- [x] Verify installation.
- [/] Explore basic commands (`wkg --help`, `wkg config`).
- [ ] Attempt to fetch a component.

## Log

### 2026-04-24: Installation Initiated
- Confirmed `cargo` is available.
- Started `cargo install wkg` in the background.

### 2026-04-24: Installation Completed
- The background task completed successfully.
- `wkg v0.15.0` was installed to `/Users/kevmoo/.cargo/bin/wkg`.

### 2026-04-24: Verification and Basic Help
- Ran `wkg --help` successfully.
- Available commands: `config`, `get`, `publish`, `oci`, `wit`.

### 2026-04-24: Search Capabilities Explored
- Checked if `wkg` has a search command: It does not.
- Checked if `gh` can search packages: It does not.
- Attempted to use GitHub API to list packages for `webassembly` org: Failed with 403 Forbidden (requires `read:packages` scope).
- Conclusion: No direct way to search for components via these tools. Must know the package spec or find them via external documentation/registries.

### 2026-04-24: Fetched Bytecode Alliance Registry Config
- Read `https://bytecodealliance.org/.well-known/wasm-pkg/registry.json`.
- Content:
  ```json
  {
          "ociRegistry": "ghcr.io",
          "ociNamespacePrefix": "bytecodealliance/wasm-pkg/"
  }
  ```
- This confirms they use `ghcr.io` with the prefix `bytecodealliance/wasm-pkg/`.





## Next Steps
1.  **Verify Installation**: Once the cargo install completes, check if `wkg` is in the PATH and runnable.
2.  **Explore Help**: Run `wkg --help` to see available commands.
3.  **Fetch Component**: Try to fetch a simple component to see what the output looks like.

## References
- [00_research_and_exploration.md](./00_research_and_exploration.md)
- `wasm-pkg-tools` repo: https://github.com/bytecodealliance/wasm-pkg-tools
