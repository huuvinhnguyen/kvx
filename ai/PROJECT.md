# Project

## Purpose

KVX is a cross-platform application for monitoring, managing, and controlling connected devices. It supports device discovery and listing, status filtering, device details, sensor readings, device control, and scheduling.

The repository contains native Swift and Flutter implementations that should provide consistent behavior while following each platform's conventions.

## Technology

### Swift application

- Swift and SwiftUI
- Swift Observation with `@Observable`
- Swift concurrency with `async`/`await`
- Clean Architecture
- Xcode project in `kvx.xcodeproj`

### Flutter application

- Dart and Flutter
- Provider for presentation state
- `http` for remote requests
- Clean Architecture
- Flutter project in `kvx_flutter/`

### External integration

- BinBlog device API
- Credentials are supplied at build or run time through `BINBLOG_USERNAME` and `BINBLOG_PASSWORD`.
- Credentials and access tokens must not be committed to source control.

## Architecture

The system contains:

- **Domain layer**: Device and schedule entities, repository interfaces, and framework-independent business rules.
- **Application layer**: Use cases that coordinate domain operations.
- **Data layer**: Remote and local data sources, API response models, authentication providers, and repository implementations.
- **Presentation layer**: SwiftUI views and observable view models in Swift; screens, widgets, and providers in Flutter.
- **Platform integration layer**: Platform- or hardware-specific implementations kept behind interfaces so they do not leak into domain logic.

The primary dependency flow is:

```text
Presentation -> Application -> Domain <- Data
```

Important locations:

- `kvx/`: Native Swift application
- `kvx_flutter/lib/`: Flutter application
- `kvxTests/`: Swift unit tests
- `kvxUITests/`: Swift UI tests
- `kvx_flutter/test/`: Flutter tests
- `ai/`: Project guidance, agent roles, workflows, and task notes

Detailed architectural guidance is available in `ai/ARCHITECTURE.md`.

## Important Rules

- Do not modify unrelated components.
- Prefer existing abstractions.
- Avoid blocking operations.
- Preserve existing functionality.
- Hardware-specific code must stay isolated.
