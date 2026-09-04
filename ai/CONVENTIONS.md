# Coding Conventions

## General

- Prefer existing architecture.
- Avoid unnecessary refactoring.
- Keep changes minimal.
- Do not duplicate functionality.
- Match the surrounding code style before introducing a new abstraction.
- Keep each function, type, and change focused on one responsibility.
- Use clear, descriptive names; avoid unnecessary abbreviations.
- Preserve existing behavior unless the task explicitly requires a behavior change.
- Keep user-facing text consistent with the target platform and existing language.
- Do not commit credentials, access tokens, private keys, or generated build output.
- Handle loading, success, empty, and error states for remote data.
- Keep asynchronous work non-blocking and provide retry behavior where appropriate.

## Swift

- Use `UpperCamelCase` for types and `lowerCamelCase` for properties, methods, and local values.
- Use SwiftUI composition; extract meaningful sections into private computed views or reusable `View` types.
- Keep observable state in view models; views must not make raw API calls.
- Use `async`/`await` for asynchronous operations.
- Prefer dependency injection through protocols for testability.
- Use SF Symbols, semantic system colors, and platform styles instead of duplicated magic values.
- Keep model enums `CaseIterable` only when the UI or business logic needs to enumerate them.
- Use `private` for implementation details and the narrowest suitable access level for APIs.
- Dispose or cancel tasks, timers, and subscriptions owned by an object.
- Add `#Preview` for representative SwiftUI screens where practical.

## Flutter / Dart

- Use `UpperCamelCase` for classes and enums; use `lowerCamelCase` for members, methods, and local values.
- Use `const` constructors and widgets whenever values are compile-time constants.
- Keep business logic out of widgets; use providers/view models and use cases.
- Dispose controllers, focus nodes, and subscriptions owned by a widget.
- Prefer immutable entities and `copyWith` for state updates.
- Keep imports consistent with the existing `lib` package structure.
- Use typed models and explicit error states rather than passing loosely typed maps through the UI.
- Keep widgets small, composable, and responsible for presentation only.

## Architecture

- Respect the dependency flow: `Presentation -> Application -> Domain <- Data`.
- Keep domain entities and repository contracts independent of UI frameworks and concrete data sources.
- Put repository implementations, API clients, DTO mapping, and persistence in the data layer.
- Put orchestration of business operations in use cases.
- Prefer existing abstractions over parallel implementations.
- Hardware- and platform-specific code must stay behind protocols, interfaces, or adapters.
- Do not move hardware concerns into domain entities or reusable UI components.

## UI

- Follow platform conventions for navigation, sheets, lists, pull-to-refresh, alerts, and destructive actions.
- Make icon-only actions accessible with labels or meaningful accessibility hints.
- Use sufficiently large tap targets and support Dynamic Type/text scaling where applicable.
- Provide clear loading, empty, error, and retry states.
- Confirm destructive actions when an undo option is not available.
- Support light and dark system appearances for new screens.
- Avoid hard-coded dimensions and colors when semantic or adaptive values are available.
- Keep Swift and Flutter user flows behaviorally aligned when implementing the same feature.

## Testing

- Add or update tests when behavior changes.
- Unit test entities, filtering, use cases, state transitions, and repository mapping.
- Test success, failure, empty, nil/null, and boundary cases.
- Use fakes or mocks for network, persistence, and hardware dependencies.
- Keep tests deterministic, isolated, readable, and fast.
- Reserve UI tests for critical user journeys and accessibility behavior.
- Do not claim a build or test passed unless it was actually run.

## Documentation

- Update relevant documentation when architecture, API behavior, setup, or user-visible behavior changes.
- Record significant technical choices in `docs/decisions/`.
- Keep task-specific plans and follow-up notes in `ai/tasks/`.
- Never place real credentials or access tokens in documentation; use placeholders.

## Git

### Branches

- Feature: `feat/<short-name>`
- Bug fix: `fix/<short-name>`
- Refactor: `refactor/<short-name>`
- Documentation: `docs/<short-name>`
- Tests: `test/<short-name>`
- Chore: `chore/<short-name>`

### Commit format

Use a lowercase type followed by a colon and a concise imperative description:

```text
feat: add device detail navigation
fix: handle device request timeout
refactor: extract device status mapper
test: cover schedule validation
docs: document BinBlog API
chore: update build configuration
```

Supported commit types:

- `feat:` — add a user-visible feature.
- `fix:` — correct an existing bug.
- `refactor:` — restructure code without changing intended behavior.
- `test:` — add or update tests.
- `docs:` — add or update documentation.
- `chore:` — maintenance, tooling, dependencies, or build configuration.

### Commit guidelines

- Keep commits small and logically focused.
- Do not mix unrelated changes in one commit.
- Explain behavior or intent in the commit body when the title is insufficient.
- Do not commit secrets, local configuration, generated files, or credentials.
- Review `git diff` before committing.
