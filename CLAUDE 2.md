# CLAUDE.md - AI Assistant Context Guide

This document provides essential context for AI assistants working with the WorkoutsApp project. It helps optimize context usage and improve code generation accuracy.

## Project Overview

**WorkoutsApp** is a modern iOS application that displays country information using SwiftUI and follows Clean Architecture principles with Dependency Injection.

- **Platform**: iOS
- **UI Framework**: SwiftUI
- **Minimum iOS Version**: iOS 17+ (uses SwiftData)
- **Language**: Swift 6.0+
- **Architecture**: Clean Architecture with DI Container pattern

## Core Architecture

### 1. Dependency Injection Container (`DIContainer.swift`)

The app uses a custom DI container pattern:

```swift
struct DIContainer {
    let appState: Store<AppState>
    let interactors: Interactors
}
```

**Access in views**: Use `@Environment(\.injected)` to access the container.

```swift
@Environment(\.injected) private var injected: DIContainer
```

### 2. State Management (`AppState.swift`)

Centralized state using a `Store<AppState>` pattern with Combine:

```swift
struct AppState: Equatable {
    var routing = ViewRouting()    // Navigation state
    var system = System()           // System state (keyboard, active state)
    var permissions = Permissions() // Permission status
}
```

**Key patterns**:
- Use `injected.appState[\.keyPath]` for direct access
- Use `injected.appState.updates(for: \.keyPath)` for reactive updates
- All routing state lives in `AppState.ViewRouting`

### 3. Layer Separation

**Views** → **Interactors** → **Repositories** → **API/Database**

- **Views**: Pure SwiftUI, no business logic
- **Interactors**: Business logic protocols (e.g., `CountriesInteractor`)
- **Repositories**: Data access protocols
  - `WebRepository`: Network calls
  - `DBRepository`: SwiftData persistence

## Key Patterns & Conventions

### Loadable State Pattern

Used throughout for async operations:

```swift
enum Loadable<T> {
    case notRequested
    case isLoading(Cancellable)
    case loaded(T)
    case failed(Error)
}
```

**Usage in views**:
```swift
@State private var details: Loadable<DBModel.CountryDetails> = .notRequested

// Load data
$details.load {
    try await injected.interactors.countries.loadCountryDetails(country: country)
}
```

### Routing Pattern

Each view has its own `Routing` struct:

```swift
extension CountriesList {
    struct Routing: Equatable {
        var countryCode: String?
    }
}
```

**Binding to AppState**:
```swift
@State private var routingState: Routing = .init()
private var routingBinding: Binding<Routing> {
    $routingState.dispatched(to: injected.appState, \.routing.countriesList)
}
```

### View Testing with Inspection

Views include inspection support for testing:

```swift
let inspection = Inspection<Self>()

// In body
.onReceive(inspection.notice) { self.inspection.visit(self, $0) }
```

## Data Models

### SwiftData Models (`DBModel` namespace)

All SwiftData models are in the `DBModel` namespace:

```swift
extension DBModel {
    @Model
    final class Country {
        var name: String
        var alpha3Code: String
        var population: Int
        var flag: URL?
        // ...
    }
}
```

**Important**: Use `DBModel.Country`, `DBModel.CountryDetails`, etc.

## Common File Locations

```
/repo/
├── App.swift                    # Main app entry point
├── AppDelegate.swift            # App lifecycle
├── AppEnvironment.swift         # Bootstrap & configuration
├── AppState.swift               # Centralized state
├── DIContainer.swift            # Dependency injection
│
├── Views/
│   ├── CountriesListView.swift
│   ├── CountryDetailsView.swift
│   └── ...
│
├── Interactors/
│   ├── CountriesInteractor.swift
│   ├── ImagesInteractor.swift
│   └── UserPermissionsInteractor.swift
│
├── Repositories/
│   ├── CountriesWebRepository.swift
│   ├── WebRepository.swift
│   └── ...
│
├── Models/
│   └── DBModel+*.swift
│
├── System/
│   ├── DeepLinksHandler.swift
│   ├── PushNotificationsHandler.swift
│   └── SystemEventsHandler.swift
│
└── Utilities/
    ├── Helpers.swift
    ├── Loadable.swift
    └── ...
```

## Key Conventions

### 1. Async/Await Everywhere
- All network and database operations use Swift Concurrency
- No completion handlers or Dispatch queues
- Interactors are `async throws`

### 2. Protocol-Based Design
- All interactors and repositories are protocols
- Real implementations and Stub implementations for testing
- Example: `CountriesInteractor` → `RealCountriesInteractor` + `StubCountriesInteractor`

### 3. Environment Injection
- Use `@Environment(\.injected)` for DI container
- Use `@Environment(\.locale)` for localization
- Custom environment values defined via `@Entry`

### 4. SwiftData Queries in Views
- Use `.query()` modifier for search functionality
- Predicates use `#Predicate` macro syntax
- Example:
  ```swift
  .query(searchText: searchText, results: $countries) { search in
      Query(filter: #Predicate<DBModel.Country> { country in
          search.isEmpty ? true : country.name.localizedStandardContains(search)
      })
  }
  ```

### 5. Navigation
- Use `NavigationStack` with `NavigationPath`
- Programmatic navigation via routing state
- Deep linking through `AppState.ViewRouting`

### 6. Error Handling
- Use `ErrorView` component for displaying errors
- Always provide retry actions
- Loadable pattern handles error states

## Interactor Interface

When creating or modifying interactors:

```swift
protocol MyInteractor {
    func doSomething() async throws -> Result
}

struct RealMyInteractor: MyInteractor {
    // Real implementation
}

struct StubMyInteractor: MyInteractor {
    // Test stub
}
```

Add to `DIContainer.Interactors`:
```swift
struct Interactors {
    let myInteractor: MyInteractor
    // ...
}
```

## Testing Conventions

- Test files mirror source structure
- Use `Inspection<Self>()` for view testing
- Stub implementations for all protocols
- Tests use `@MainActor` when needed

## Deep Linking

The app supports deep links via:
1. Push notifications
2. URL schemes
3. Universal links

**Flow**: URL → `SystemEventsHandler` → `DeepLinksHandler` → Update `AppState.routing`

Example deep link: `showCountryFlag(alpha3Code: "AFG")`

## Push Notifications

- Registration handled by `SystemEventsHandler`
- Permissions via `UserPermissionsInteractor`
- Token sent to backend via `PushTokenWebRepository`

## Bootstrap Process

See `AppEnvironment.bootstrap()`:
1. Create `AppState` store
2. Configure URLSession
3. Create web repositories
4. Create SwiftData ModelContainer
5. Create DB repositories
6. Create interactors
7. Create DI container
8. Create system handlers

## Common Gotchas

1. **Always use `@MainActor`** for view-related interactor methods
2. **Routing state binding** must use `.dispatched(to:)` helper
3. **SwiftData queries** require `#Predicate` macro syntax
4. **Loadable cancellation** is automatic but can be triggered manually
5. **Locale changes** reset routing state (see `AppEnvironment.onChangeHandler`)

## When Adding New Features

1. **Create protocol** in appropriate layer (Interactor/Repository)
2. **Add real implementation** and stub implementation
3. **Update DIContainer** to include new dependency
4. **Update AppEnvironment.bootstrap()** to instantiate
5. **Add routing state** if needed in `AppState.ViewRouting`
6. **Create view** using established patterns (Loadable, Routing, Inspection)
7. **Write tests** using stubs

## Performance Considerations

- SwiftData ModelContainer uses background context for writes
- URLSession configured with connection pooling
- Image loading uses cached URLSession
- Search uses SwiftData predicates (optimized queries)

## Code Style

- Use `private extension` for view helpers
- Group code with `// MARK: -` comments
- Prefer `@ViewBuilder` for conditional views
- Use `some View` return types
- Property wrappers on separate lines for clarity

## AI Assistant Tips

1. **Search first**: Use `query_search` to find existing patterns before creating new code
2. **Check DIContainer**: Most dependencies are already wired up
3. **Follow Loadable pattern**: Don't reinvent async state management
4. **Use protocols**: All business logic should be protocol-based
5. **Test with stubs**: Every protocol has a stub implementation
6. **Maintain separation**: Views → Interactors → Repositories (never skip layers)

## Quick Reference

| Task | Pattern |
|------|---------|
| Access DI | `@Environment(\.injected)` |
| Load async data | `$state.load { try await ... }` |
| Navigate programmatically | Update `AppState.routing` |
| Access state reactively | `injected.appState.updates(for: \.keyPath)` |
| Query SwiftData | `.query(searchText:results:) { Query(...) }` |
| Add dependency | Protocol → Real/Stub → DIContainer → bootstrap() |
| Handle errors | Use `Loadable.failed(Error)` + `ErrorView` |

## Resources

- ViewInspector: Used for SwiftUI testing (see `Inspection<Self>`)
- EnvironmentOverrides: Used for debugging (locale, size category changes)

---

**Last Updated**: March 21, 2026
**Xcode Version**: 15.0+
**Swift Version**: 6.0+
