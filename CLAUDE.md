# Clean Architecture SwiftUI - Project Overview

This document provides a comprehensive overview of the Clean Architecture SwiftUI project for AI assistants and developers.

## Project Summary

A demo iOS application showcasing Clean Architecture principles with SwiftUI, featuring a countries browser powered by the [restcountries.com](https://restcountries.com/) REST API.

**Platform**: iOS, iPadOS, macOS  
**Language**: Swift  
**UI Framework**: SwiftUI  
**Architecture**: Clean Architecture with MVVM-like patterns  
**Last Updated**: End of 2024

---

## Key Technologies

- **SwiftUI** - Declarative UI framework
- **Combine** - Reactive programming for state management
- **SwiftData** - Local persistence and database
- **Swift Concurrency** - async/await for networking
- **XCTest & ViewInspector** - 100% test coverage including UI

---

## Architecture Overview

### Three-Layer Architecture

```
┌─────────────────────────────────────────┐
│       PRESENTATION LAYER                │
│   (SwiftUI Views - Pure Functions)     │
│                                         │
│  CountriesList, CountryDetails, etc.   │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│      BUSINESS LOGIC LAYER               │
│         (Interactors)                   │
│                                         │
│  CountriesInteractor, etc.              │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│       DATA ACCESS LAYER                 │
│        (Repositories)                   │
│                                         │
│  Web Repositories + DB Repositories     │
└─────────────────────────────────────────┘
```

### 1. Presentation Layer

**Files**: `*View.swift` files (e.g., `CountriesListView.swift`, `CountryDetailsView.swift`)

**Responsibilities**:
- Render UI as a pure function of state
- No business logic
- Forward user actions to Interactors
- Observe state changes via `@State`, `@Environment`

**Key Principles**:
- Views never directly call repositories
- Side effects triggered by user actions or lifecycle events
- State injected via native SwiftUI dependency injection

### 2. Business Logic Layer

**Files**: `*Interactor.swift` files (e.g., `CountriesInteractor.swift`)

**Responsibilities**:
- Execute business logic
- Coordinate between repositories
- Update `AppState` or `Binding` with results
- Handle caching strategies

**Example**:
```swift
protocol CountriesInteractor {
    func refreshCountriesList() async throws
    func loadCountryDetails(country: DBModel.Country, forceReload: Bool) async throws -> DBModel.CountryDetails
}
```

**Key Principles**:
- Protocol-based for testability
- Never return data directly; instead update state
- Coordinate between web and database repositories

### 3. Data Access Layer

**Files**: `*Repository.swift` files (e.g., `CountriesWebRepository.swift`, `CountriesDBRepository.swift`)

**Responsibilities**:
- CRUD operations
- API calls (Web Repositories)
- Database operations (DB Repositories)
- No business logic

**Two Types**:
- **Web Repositories**: Async API calls using URLSession
- **DB Repositories**: SwiftData persistence operations

---

## Core Components

### AppState

**File**: `AppState.swift`

Redux-like centralized state management:

```swift
struct AppState: Equatable {
    var routing = ViewRouting()      // Navigation state
    var system = System()             // App lifecycle state
    var permissions = Permissions()   // Permission states
}
```

**Purpose**: Single source of truth for app-wide state

### Store<State>

**File**: `Store.swift`

Type alias for `CurrentValueSubject<State, Never>` with extensions:

```swift
typealias Store<State> = CurrentValueSubject<State, Never>
```

**Features**:
- Subscript access to state properties
- Automatic change detection
- Reactive updates via Combine
- Binding dispatchers for two-way data flow

### Loadable<T>

**File**: `Loadable.swift`

State machine for async operations:

```swift
enum Loadable<T> {
    case notRequested
    case isLoading(last: T?, cancelBag: CancelBag)
    case loaded(T)
    case failed(Error)
}
```

**Use Case**: Track loading states for API calls with previous data preservation

### DIContainer

**File**: `DIContainer.swift`

Dependency injection container:

```swift
struct DIContainer {
    let appState: Store<AppState>
    let interactors: Interactors
}
```

**Injection Method**: SwiftUI `@Environment` with custom `@Entry`

```swift
extension EnvironmentValues {
    @Entry var injected: DIContainer = ...
}
```

---

## Data Flow

### Example: Refreshing Countries List

1. **User Action**: User pulls to refresh in `CountriesList`
2. **View**: Calls `loadCountriesList(forceReload: true)`
3. **Binding**: Updates `$countriesState` using `Loadable.load()`
4. **Interactor**: `CountriesInteractor.refreshCountriesList()` is called
5. **Web Repository**: Fetches countries from REST API
6. **DB Repository**: Stores countries in SwiftData
7. **SwiftData Query**: View's `@Query` automatically refreshes
8. **UI Update**: List re-renders with new data

### Example: Navigation with Deep Linking

1. **Push Notification**: Contains country code
2. **Deep Link Handler**: Updates `AppState.routing.countriesList.countryCode`
3. **Combine Publisher**: View observes routing changes via `routingUpdate`
4. **View**: Detects country code change in `onChange(of: routingState.countryCode)`
5. **Navigation**: Appends country to `NavigationPath`
6. **UI**: NavigationStack pushes `CountryDetails` view

---

## Key Features

### 🔍 Search Implementation

Uses SwiftUI's `.searchable()` with SwiftData predicates:

```swift
.query(searchText: searchText, results: $countries, { search in
    Query(filter: #Predicate<DBModel.Country> { country in
        if search.isEmpty {
            return true
        } else {
            return country.name.localizedStandardContains(search)
        }
    }, sort: \DBModel.Country.name)
})
```

### 🔄 Pull-to-Refresh

Native SwiftUI implementation:

```swift
.refreshable {
    loadCountriesList(forceReload: true)
}
```

### 🧭 Programmatic Navigation

- Uses `NavigationPath` for type-safe navigation
- Routing state synchronized with `AppState`
- Deep linking support via routing updates

### 🔒 Permissions Management

- Centralized in `AppState.Permissions`
- `UserPermissionsInteractor` handles requests
- Key path-based permission access

### 💾 Caching Strategy

Implemented in Interactors:

```swift
func loadCountryDetails(country: DBModel.Country, forceReload: Bool) async throws -> DBModel.CountryDetails {
    if !forceReload,
       let stored = try? await dbRepository.countryDetails(for: country) {
        return stored  // Return cached data
    }
    // Fetch from API and store
}
```

---

## Testing Strategy

### Full Test Coverage

- **Unit Tests**: Interactors, Repositories, Utilities
- **UI Tests**: Using [ViewInspector](https://github.com/nalexn/ViewInspector)
- **Integration Tests**: Deep linking, system events

### Test Files Pattern

- `*Tests.swift` - Unit and integration tests
- Uses stub implementations (`StubCountriesInteractor`, etc.)
- `Inspection` helper for async UI testing

### Example Test Structure

```swift
struct StubCountriesInteractor: CountriesInteractor {
    func refreshCountriesList() async throws {
        // Stub implementation
    }
}
```

---

## File Organization

### Models

- **ApiModel**: Codable structs for API responses
- **DBModel**: SwiftData models for persistence
- Conversion methods: `apiModel.dbModel()`

### Utilities

- **CancelBag**: Task cancellation management
- **LocaleReader**: Environment locale observation
- **ErrorView**: Reusable error display component

### System Integration

- **AppDelegate**: System events and initialization
- **AppEnvironment**: Environment configuration
- **RootViewAppearance**: Root-level modifiers

---

## Dependencies

### Third-Party

- **EnvironmentOverrides**: Environment testing and overrides

### Apple Frameworks

- SwiftUI
- Combine
- SwiftData
- Foundation
- UserNotifications (for push permissions)

---

## Network Layer

### WebRepository Protocol

Base protocol for all web repositories:

```swift
protocol WebRepository {
    var session: URLSession { get }
    var baseURL: String { get }
}
```

### APICall Protocol

Defines endpoint structure:

```swift
protocol APICall {
    var path: String { get }
    var method: String { get }
    var headers: [String: String]? { get }
    func body() throws -> Data?
}
```

### Error Handling

- Custom `APIError` enum
- Loadable state captures errors
- UI displays via `ErrorView`

---

## Best Practices Demonstrated

✅ **Separation of Concerns**: Clear boundaries between layers  
✅ **Dependency Injection**: Protocol-based, testable architecture  
✅ **Unidirectional Data Flow**: State flows down, events flow up  
✅ **Reactive Programming**: Combine for state observation  
✅ **Modern Swift**: async/await, actors, SwiftData  
✅ **Accessibility**: Localization support, RTL layout  
✅ **Testing**: 100% coverage including UI  
✅ **Type Safety**: Strong typing throughout  

---

## Common Patterns

### State Update Pattern

```swift
private var routingUpdate: AnyPublisher<Routing, Never> {
    injected.appState.updates(for: \.routing.countriesList)
}

.onReceive(routingUpdate) { self.routingState = $0 }
```

### Binding Dispatch Pattern

```swift
private var routingBinding: Binding<Routing> {
    $routingState.dispatched(to: injected.appState, \.routing.countriesList)
}
```

### Loadable Loading Pattern

```swift
$countriesState.load {
    try await injected.interactors.countries
        .refreshCountriesList()
}
```

---

## Resources

- **Original Article**: [Clean Architecture for SwiftUI](https://nalexn.github.io/clean-architecture-swiftui/)
- **MVVM Branch**: Alternative implementation approach
- **Related Project**: [Authentication state handling example](https://github.com/nalexn/uikit-swiftui)

---

## Getting Started for AI Assistants

When working with this codebase:

1. **Understand the layer** - Identify if you're working with View, Interactor, or Repository
2. **Follow data flow** - User actions → Interactors → Repositories → State → Views
3. **Use protocols** - All major components are protocol-based
4. **Test everything** - Maintain 100% coverage
5. **Respect boundaries** - Views don't call Repositories directly
6. **Use Loadable** - For any async operation that needs UI feedback
7. **Update AppState** - For app-wide state changes
8. **Use Binding** - For local, view-specific state

---

## Questions to Ask When Modifying

- [ ] Which layer does this change belong to?
- [ ] Do I need to update AppState?
- [ ] Should this use Loadable for loading states?
- [ ] Do I need a new Interactor or can I extend existing?
- [ ] Is this change testable?
- [ ] Do I need both protocol and implementation?
- [ ] Should this data be cached in SwiftData?

---

## Getting Started - Building the Project

### Prerequisites

- **Xcode 16.0+** (for Swift 6.1 support)
- **iOS 18.0+** deployment target or macOS 12.0+
- Internet connection (for fetching Swift Package dependencies)

### Build Instructions

#### Option 1: Using Xcode Project (Recommended)

1. **Open the Xcode Project**
   ```bash
   open WorkoutsApp.xcodeproj
   ```

2. **Wait for Swift Package Dependencies**
   - Xcode will automatically fetch dependencies:
     - `EnvironmentOverrides` (v0.0.4+)
     - `ViewInspector` (v0.10.0+)
   - This may take 1-2 minutes on first launch

3. **Select a Target**
   - iOS Simulator (iPhone 15 Pro recommended)
   - Mac (Designed for iPad)
   - Physical iOS device (requires code signing)

4. **Build and Run**
   - Press `Cmd+R` or click the Run button
   - First build may take longer due to dependency compilation

#### Option 2: Using Swift Package Manager

If the project is set up as a standalone Swift Package:

```bash
# Resolve dependencies
swift package resolve

# Build the package
swift build

# Run tests
swift test
```

**Note**: The UIKit framework dependency is configured in the linker settings:

```swift
linkerSettings: [
    .linkedFramework("UIKit")
]
```

### Troubleshooting Common Build Issues

#### ❌ Error: "Unable to find module dependency: 'UIKit'"

**Solution**: This error typically occurs when:

1. **Building on macOS without iOS SDK**
   - UIKit is iOS/iPadOS/tvOS only
   - For macOS, the project needs conditional compilation or AppKit
   - **Fix**: Select an iOS simulator as the build destination

2. **Using wrong SDK**
   - Ensure you're building with the iOS SDK
   - In Xcode: Product → Destination → iOS Simulator

3. **Package.swift issue**
   - The current `Package.swift` links UIKit via `linkerSettings`
   - This works for iOS but not pure macOS builds
   - The project claims macOS support but uses UIKit

**Current Configuration**:
```swift
platforms: [
    .iOS(.v18),    // ✅ UIKit available
    .macOS(.v12)   // ⚠️ UIKit not available
]
```

**Recommended Fix**: If you need macOS support, you'll need to:
- Create AppKit-based AppDelegate for macOS
- Use conditional compilation (`#if os(iOS)`)
- Or focus on iOS/iPadOS only

#### ❌ Error: "No such module 'EnvironmentOverrides'"

**Solution**:
1. Check internet connection
2. File → Packages → Reset Package Caches
3. File → Packages → Update to Latest Package Versions
4. Clean build folder: `Cmd+Shift+K`

#### ❌ SwiftData Migration Issues

**Solution**:
- Delete the app from simulator
- Clean build folder (`Cmd+Shift+K`)
- Rebuild and run

### Project Structure Requirements

The project expects this structure:

```
WorkoutsApp/
├── WorkoutsApp/          # Main app source
│   ├── Injected/              # DI, Interactors, Repositories
│   ├── UI/                    # SwiftUI Views
│   ├── System/                # AppDelegate, System Events
│   ├── Utilities/             # Helpers, Extensions
│   ├── Models/                # Data models
│   └── Resources/             # Assets, Localizations
├── UnitTests/                 # Test files
├── Package.swift              # SPM configuration
└── WorkoutsApp.xcodeproj # Xcode project (if exists)
```

### Running Tests

```bash
# In Xcode
Cmd+U

# Or via command line
xcodebuild test -scheme WorkoutsApp \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Deep Linking Test

To test deep linking:

1. Build and run on iOS Simulator
2. Tap "Allow Push" button
3. Background the app
4. Drag `push_with_deeplink.apns` file into simulator
5. Tap the notification

Or add this code to `AppEnvironment.bootstrap()`:

```swift
DispatchQueue.main.async {
    deepLinksHandler.open(deepLink: .showCountryFlag(alpha3Code: "AFG"))
}
```

### Dependencies Overview

| Package | Version | Purpose |
|---------|---------|---------|
| EnvironmentOverrides | 0.0.4+ | Environment testing utilities |
| ViewInspector | 0.10.0+ | UI testing framework |

### Swift Language Mode

The project uses **Swift 5 language mode** for compatibility:

```swift
swiftSettings: [
    .swiftLanguageMode(.v5)
]
```

### Platform-Specific Notes

**iOS 18.0+**:
- Full support with all features
- SwiftData persistence works out of the box
- Push notifications supported

**macOS 12.0+**:
- ⚠️ Current implementation has UIKit dependencies
- Needs conditional compilation for full support
- Consider focusing on iOS/iPadOS for this demo

### Quick Start Checklist

- [ ] Install Xcode 16.0+
- [ ] Clone/download the project
- [ ] Open `.xcodeproj` file
- [ ] Wait for SPM dependencies to resolve
- [ ] Select iOS Simulator as destination
- [ ] Press `Cmd+R` to build and run
- [ ] Check that countries list loads
- [ ] Test pull-to-refresh
- [ ] Test search functionality

---

*This document was auto-generated to help AI assistants understand the Clean Architecture SwiftUI project structure and patterns.*
