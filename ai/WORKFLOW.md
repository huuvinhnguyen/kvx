# Workflow

## Start of a Task

1. Read `ai/PROJECT.md`, `ai/ARCHITECTURE.md`, and `ai/CONVENTIONS.md`.
2. Identify the target platform (Swift, Flutter, or both).
3. Inspect the existing screens, view models/providers, domain entities, repository contracts, and tests.
4. Write a task note in `ai/tasks/` for work that spans multiple files or changes architecture.
5. Confirm assumptions about API behavior and persistence before implementing them.

## Plan

1. State the user-visible behavior and acceptance criteria.
2. Identify the layer and files that should change.
3. Prefer extending existing repository/use-case patterns over adding parallel infrastructure.
4. Include error, loading, empty, offline, and accessibility behavior.
5. Keep the plan small enough to review and test incrementally.

## Implement

1. Make domain changes first, then data/application, then presentation.
2. Keep platform implementations behaviorally aligned where the feature exists in both apps.
3. Add or update unit tests alongside logic changes.
4. Avoid unrelated formatting or refactoring.
5. Never hard-code real credentials; use the documented environment/configuration flow.

## Verify

Run the checks relevant to the changed platform:

### Swift

- Build the Xcode target or use the project run script.
- Run unit tests in `kvxTests`.
- Run UI tests in `kvxUITests` when navigation or user interaction changes.

### Flutter

```bash
cd kvx_flutter
flutter analyze
flutter test
```

Also manually verify the changed flow on a representative simulator/device when UI behavior changes.

## Review Checklist

- Does the feature follow the layer boundaries?
- Are loading, error, retry, and empty states handled?
- Are destructive actions safe and recoverable?
- Are async operations and observable state correct?
- Are Swift and Flutter behavior aligned where intended?
- Are tests meaningful and passing?
- Is the diff limited to the requested scope?

## Completion

Summarize changed files, behavior, verification commands and results, and any known limitations. Do not claim a build or test passed unless it was actually run.
