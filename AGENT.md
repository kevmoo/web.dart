# Agent Instructions for this Project

## code_builder API Usage
- **Rule**: ALWAYS use the full `code_builder` API for generating code. Do NOT use raw string dumping via `code.Code(...)` for statements or expressions that can be represented by the API (like variable declarations, method calls, etc.).
- **Rationale**: Using the full API makes the generator more robust, handles prefixes and imports automatically, and ensures better maintainability.
- **Exception Handling**: If `code_builder` emits syntax that triggers lints (like `unnecessary_parenthesis`), use `// ignore_for_file` at the top of the generated file rather than resorting to string dumping.

## Communication
- **Rule**: If you are ever stuck, confused about the WIT JSON structure, or unsure how to map a specific feature to `code_builder`, **ASK THE USER**! Do not make assumptions or use "hacky" workarounds without confirmation.

## File Organization
- **Rule**: Keep entrypoints minimal. Move heavy logic to `lib/src/`.
- **Rule**: Follow standard Dart package conventions.

## Dart Coding Style
- **Rule**: Prefer **switch expressions** over `if-else` blocks for pattern matching or mapping values to expressions (introduced in Dart 3.0).


## Lessons Learned & Pitfalls to Avoid (For Future Agents)
- **Preserve State when Overwriting**: When updating files (especially large ones like `generator.dart`), be extremely careful not to overwrite lines with older versions from your memory or previous views. Always read the *current* content first or use targeted replaces instead of full overrides unless you have carefully merged all changes.
- **Scoped Emitter and String Code**: If you use `DartEmitter.scoped()`, remember that it generates its own prefixes (like `_i1`, `_i2`). Do NOT hardcode prefixes like `web.` in raw `Code` strings, as they will likely conflict with what the emitter generates! Use the full API with `refer(symbol, url)` so the emitter can handle prefixes automatically.
- **Extension Methods and Prefixes**: In Dart, if you import a library with a prefix (e.g., `import 'dart:js_interop_unsafe' as ...`), its extension methods cannot be called as instance methods on objects. You must use the explicit extension call syntax (e.g., `Prefix.ExtensionName(receiver).method()`).

