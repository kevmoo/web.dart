# Agent Handoff: Curation and Validation

## Welcome, Agent!
Your primary objective for this session is to execute the interactive rebase and strict validation protocol outlined in `conductor/plan.md`. We have a massive git history on the `vscode_2nd_try` branch that needs to be meticulously curated into perfectly validated, atomic commits.

## Prerequisites
Before you start any Git operations, please:
1. Read the full strategy in `conductor/plan.md`.
2. Understand the strict **3-Step Validation Protocol** required for *every single commit*. This is the most critical part of your job.
3. Ensure you are on the `vscode_2nd_try` branch.

## Critical Rules
1. **Don't throw away anything!** This is especially true for `.md` files. You are always welcome to create commits titled `DOC TO REVIEW: xyz` that contain only markdown files. Most commits in this series only touch markdown for process notes. We want to let a human review those later. Keeping them in their own commits is great.
2. **DO NOT REVERT GOOD WORK. ASK FOR HELP!** If you have done solid work that seems reasonable and working and then hit a roadblock, don't try to start over or throw things away. Just stop and ask for help!

## Execution Directives
1. **Safety First:** Begin by creating a backup branch (`git branch vscode_2nd_try_backup`). Do not push this backup unless instructed.
2. **Audit:** Generate the audit log (`git log origin/HEAD..HEAD --oneline > conductor/audit.txt`) and analyze it to plan your squashes and edits.
3. **Rebase:** Initiate `git rebase -i origin/HEAD`.
4. **The Validation Loop (CRITICAL):**
   When the rebase pauses for an `edit`, or when you have assembled an atomic commit, you MUST perform the validation exactly as described in `plan.md`:
   - **Step 1:** Validate the failure state (without your `lib/` fixes).
   - **Step 2:** Validate the fix state (apply `lib/` fixes, check generated output).
   - **Step 3:** Validate `pkg:web` integrity (regenerate and ensure 0 diffs).
5. **No Shortcuts:** Do not combine unrelated fixes to save time. Do not skip validation. The user demands absolute precision.

## Final State
When you complete the rebase, the local `vscode_2nd_try` branch must be perfectly clean. Running `dart analyze .` and `dart test` at the repo root must yield 100% success with zero warnings.

Good luck!