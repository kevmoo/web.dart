# History Curation & Validation Plan

## Objective
Systematically process the massive changeset on the `vscode_2nd_try` branch using a "Hybrid Curation" strategy. We will preserve good, atomic commits, squash/rebuild messy "WIP/oops" commits, and subject every single commit to a rigorous 3-step validation protocol. The result will be a clean, linear, and perfectly validated git history.

## Key Files & Context
- **Target Branch:** `vscode_2nd_try`
- **Scope:** Primarily `js_interop_gen` (transformer refactoring, AST fixes, test updates) and verifying `web` generation.
- **Tooling:** Git CLI, Dart MCP (for validation), and local test runners.

## Critical Guardrails
- **Don't throw away anything!** This is especially true for `.md` files. The agent is encouraged to create commits titled `DOC TO REVIEW: xyz` that contain only markdown files for process notes. This ensures humans can review them later without cluttering code commits.
- **DO NOT REVERT GOOD WORK. ASK FOR HELP!** If solid, working progress is made but a roadblock is hit, do not start over or discard the work. Stop and ask the user for help!

## Implementation Steps

### Phase 1: Snapshot & Audit
1. **Safety First:** Create a local backup branch (`vscode_2nd_try_backup`) so we can work destructively without fear of losing data.
2. **Audit Log:** Export a clean list of commits (`git log origin/HEAD..HEAD --oneline > conductor/audit.txt`).
3. **Categorize:** We will review `audit.txt` and mark up the commits into three buckets:
   - **Keep:** Clean, atomic features or bug fixes.
   - **Squash/Fixup:** "Oops" commits, formatting fixes, or trailing bug fixes that belong with an earlier "Keep" commit.
   - **Re-evaluate/Rebuild:** Large, messy commits that need to be split, or areas where the scope is tangled.

### Phase 2: The Interactive Curation Engine
We will use `git rebase -i origin/HEAD` as our primary engine to enact the audit:
1. **Reorder:** Move related commits together (e.g., group all AST type resolution fixes).
2. **Squash:** Apply the `fixup` or `squash` commands to fold the messy/trailing commits into their primary atomic commits.
3. **Edit (The "Targeted Rebuild"):** For commits marked "Re-evaluate", we will use the `edit` command during rebase. When the rebase pauses, we will:
   - Run `git reset HEAD^` to uncommit the files but leave them in the working tree.
   - Use `git add -p` to meticulously stage targeted logical changes.
   - Commit these specific changes with a clear message.
   - Proceed to Phase 3 (Validation) before moving to the next split commit.

### Phase 3: The Rigorous Validation Protocol
Every curated commit MUST pass this strict 3-step validation before being finalized in the rebase:

1. **Verify the Failure State (Before Changes):**
   - Stash or exclude the proposed fixes to `lib/` temporarily.
   - Run the tests/generation (ALL TESTS).
   - **Expected Result:** The generator should fail with a runtime error, OR the generated Dart output file should contain static analysis errors. This proves the issue exists.

2. **Verify the Fix (Apply Changes):**
   - Apply the fixes to the generator source code (e.g., in `js_interop_gen/lib/`).
   - Format the code: Run `dart format .` to ensure no weird formatting artifacts are introduced.
   - Run the generator/tests (ALL TESTS).
   - **Expected Result:** The output changes should be minimal and localized to the target test output file (with zero or no-op changes to other files). All static errors in the generated Dart code must be gone.

3. **Verify pkg:web Integrity:**
   - Regenerate the `pkg:web` bindings using the updated generator.
   - **Expected Result:** There should be **zero** diffs in `pkg:web` (because the fixes target VS Code d.ts parsing/AST bugs, not standard WebIDL behavior).

### Phase 4: Final State Guarantee
At the end of the rebase process, and for every individual commit within the new history:
- **Test Clean:** 100% of the tests in the repository must pass.
- **Analyzer Clean:** EVERY FILE in the repository must pass static analysis with zero errors or warnings (`dart analyze .`).
- **Format Clean:** All code must be formatted correctly (`dart format .`).
- **Rollback:** Because we created `vscode_2nd_try_backup`, we can abort the rebase at any point if the history gets tangled.