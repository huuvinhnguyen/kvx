# Architecture Overview

## Purpose

KVX contains two client implementations of the same device-management product:

- Native SwiftUI application in `kvx/`
- Flutter application in `kvx_flutter/`

Both implementations should preserve the same domain concepts and user-visible behavior while respecting platform-specific UI conventions.

## Layered Design

```text
Presentation -> Application -> Domain <- Data
                                      ^
                                      |
                         Platform / hardware adapters
```

### Domain

The domain contains framework-independent entities, repository contracts, and business rules. Device and schedule identity, status, and relationships belong here. Domain code must not depend on SwiftUI, Flutter widgets, HTTP clients, or hardware SDKs.

### Application

Use cases coordinate business operations such as fetching devices, changing device state, and managing schedules. Use cases depend on repository interfaces rather than concrete API or hardware implementations.

### Data

The data layer implements repository interfaces and contains remote/local data sources, DTO mapping, authentication providers, persistence, and transport-specific error handling. API and storage details must not leak into presentation or domain code.

### Presentation

Presentation contains screens, reusable UI components, and state holders:

- Swift: SwiftUI views and `@Observable` view models
- Flutter: screens, widgets, and Provider-backed state

Views render state and send user intents to their state holder; they should not call raw APIs directly.

### Platform and Hardware Integration

Hardware-specific code must be isolated behind protocols/interfaces or adapters. Device SDKs, simulator controls, Bluetooth integrations, and OS-specific capabilities belong in platform/data integration code. The domain should remain testable without physical hardware.

## Main Flows

### Load devices

```text
Device list view
  -> device view model/provider
  -> fetch devices use case
  -> device repository interface
  -> remote/local repository implementation
  -> data source or API client
```

### Open device details

A list item navigates to the detail screen with the stable device identity. The detail screen displays device metadata, current status, sensor readings when available, control actions, and schedules belonging to that device.

### Handle failures

Remote operations expose loading, success, empty, and error states. Presentation provides a clear retry action. A failed remote operation must not silently overwrite valid existing state.

## Repository Locations

| Concern | Swift | Flutter |
|---|---|---|
| Entities | `kvx/Models/` | `kvx_flutter/lib/domain/entities/` |
| Repository contracts | `kvx/Domain/Repositories/` | `kvx_flutter/lib/domain/repositories/` |
| Use cases | `kvx/Domain/UseCases/` | `kvx_flutter/lib/application/usecases/` |
| Repository implementations | `kvx/Data/Repositories/` | `kvx_flutter/lib/data/repositories/` |
| API/data sources | `kvx/Services/`, `kvx/Data/` | `kvx_flutter/lib/data/datasources/` |
| UI and state | `kvx/Views/`, `kvx/ViewModels/` | `kvx_flutter/lib/presentation/` |

## Design Constraints

- Prefer existing repository, use-case, and state-management abstractions.
- Keep asynchronous work non-blocking.
- Keep platform implementations behaviorally aligned where the feature exists in both clients.
- Do not modify unrelated components while implementing a feature.
- Keep secrets and environment-specific configuration outside source code.

## Related Documentation

- [Project rules](../../ai/PROJECT.md)
- [Detailed architecture guidance](../../ai/ARCHITECTURE.md)
- [Coding conventions](../../ai/CONVENTIONS.md)
- [Development workflow](../../ai/WORKFLOW.md)
