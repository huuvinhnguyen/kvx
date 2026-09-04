# Architecture

## Architectural Goals

- Keep business rules independent from SwiftUI, Flutter widgets, and network clients.
- Make the same device concepts available in both implementations.
- Keep remote API failures explicit and expose loading/error states to the UI.
- Prefer small, testable units over view-specific business logic.

## Layers

### Domain
Contains entities, repository contracts, and framework-independent rules.

- Swift: `Domain/`, `Models/`
- Flutter: `lib/domain/`

Domain code must not import UI frameworks or concrete data sources.

### Application
Contains use cases that coordinate domain operations.

- Swift: `Domain/UseCases/`
- Flutter: `lib/application/`

A use case should represent one meaningful user operation, such as fetching devices or changing device state.

### Data
Contains API clients, authentication, DTOs, data sources, and repository implementations.

- Swift: `Data/`, `Services/`
- Flutter: `lib/data/`

Only this layer should know API transport details, response mapping, and persistence details.

### Presentation
Contains screens, reusable UI components, and state holders.

- Swift: `Views/`, `ViewModels/`
- Flutter: `lib/presentation/`

Views render state and send user intents to a view model/provider. They should not make raw HTTP requests.

## Core Flow

```text
View -> ViewModel/Provider -> Use Case -> Repository interface -> Repository implementation -> API/Data source
```

## Device and Schedule Rules

- `Device.id` is the stable identity used for updates and deletion.
- Device status is one of `online`, `offline`, or `busy`.
- A schedule belongs to one device through `deviceId`.
- Schedule mutation should preserve the schedule identity and change only the requested fields.
- UI-only formatting (status colors, icons, localized labels) belongs in presentation helpers.

## State and Concurrency

- Set loading state before an async request and clear it on every completion path.
- Clear stale errors before retrying.
- Do not update UI state after a view model has been deallocated.
- Keep optimistic updates reversible when a remote mutation can fail.

## Navigation

- List screens own collection-level state.
- Detail screens receive a device identity/value and own detail-level interactions.
- Navigation should be explicit (`NavigationLink` in SwiftUI; route/navigation APIs in Flutter).

## Testing Boundaries

- Unit test entities, filtering, use cases, and repository mapping without rendering UI.
- Test view models/providers with fake repositories.
- Keep UI tests focused on critical user journeys: load, search/filter, open detail, add schedule, and retry errors.
