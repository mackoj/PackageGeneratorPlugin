# Point-Free Architecture Guide

This document explains the architectural principles and patterns used in the PackageGenerator plugin.

## Table of Contents

- [Overview](#overview)
- [Core Principles](#core-principles)
- [Architecture Layers](#architecture-layers)
- [Point-Free Patterns](#point-free-patterns)
- [Effect System](#effect-system)
- [Testing Strategy](#testing-strategy)
- [Contributing](#contributing)

## Overview

The PackageGenerator follows the **Functional Core, Imperative Shell** architecture pattern, also known as the **Point-Free** architecture. This approach separates pure business logic from side effects, making the codebase:

- **Testable**: Pure functions are trivially testable
- **Composable**: Small functions combine to create complex behaviors
- **Maintainable**: Each piece has a single, clear responsibility
- **Debuggable**: Function composition creates clear data flow

## Core Principles

### 1. Pure Functions

All business logic is implemented as pure functions that:
- Take input and return output without side effects
- Always produce the same output for the same input
- Don't mutate state or access global variables

```swift
// ✅ Pure function
func filterExcludedPackages(_ excluded: Set<String>) -> ([Package]) -> [Package] {
  filter { !excluded.contains($0.name) }
}

// ❌ Impure function (side effects)
func filterExcludedPackages(_ packages: [Package]) -> [Package] {
  print("Filtering packages...")  // Side effect!
  return packages.filter { !excluded.contains($0.name) }
}
```

### 2. Function Composition

Build complex operations by composing simple functions:

```swift
// Using >>> operator
let processPackages = filterExcluded
  >>> applyMappings
  >>> sortBy(\.name)
  >>> enrichWithDependencyInfo

// Using |> operator (left-to-right application)
let result = packages
  |> filterExcluded
  |> applyMappings
  |> sortBy(\.name)
```

### 3. Immutability

Transform values instead of mutating them:

```swift
// ✅ Immutable transformation
func withMappedName(_ mapping: [String: String]) -> Package {
  Package(
    name: mapping[self.path] ?? self.name,
    // ... copy other properties
  )
}

// ❌ Mutation
func applyNameMapping(_ mapping: [String: String]) {
  self.name = mapping[self.path] ?? self.name  // Mutates self!
}
```

### 4. Effect Isolation

All side effects (I/O, logging, process execution) are isolated in effect types:

```swift
struct FileSystemEffect {
  var readFile: (FilePath) throws -> Data
  var writeFile: (FilePath, Data) throws -> Void
  // ...
}
```

## Architecture Layers

### Layer 1: Imperative Shell (`Plugin.swift`)

The thinnest possible layer that handles side effects:

```swift
@main
struct PackageGeneratorPlugin: CommandPlugin {
  func performCommand(
    context: PluginContext,
    arguments: [String]
  ) async throws {
    try withDependencies {
      $0 = .live(context: context)
    } operation: {
      let workflow = PluginWorkflow(context: context)
      try workflow.execute(arguments: arguments)
    }
  }
}
```

**Responsibilities:**
- Set up dependencies
- Delegate to workflow
- Handle async boundaries

**Rules:**
- Minimal logic
- No business rules
- No data transformations

### Layer 2: Workflow Composition (`PluginWorkflow.swift`)

Orchestrates the entire process using function composition:

```swift
func execute(arguments: [String]) throws {
  try packageDirectory
    |> loadOrCreateToolConfig(...)
    |> loadOrCreateConfiguration
    |> tap(validateConfiguration)
    |> parsePackages(...)
    |> processPackages
    |> generateAndWriteOutput(...)
    |> optionallyGenerateExportedFiles(...)
}
```

**Responsibilities:**
- Define execution flow
- Compose functions
- Coordinate effects

**Rules:**
- No primitive operations
- Delegates to domain layer
- Uses effect types, not implementations

### Layer 3: Domain Logic

Pure functions that implement business rules:

#### Configuration Domain

```swift
Domain/Configuration/
├── Configuration.swift       # Type definitions
├── ConfigurationValidator.swift
└── ConfigurationDefaults.swift
```

#### Parsing Domain

```swift
Domain/Parsing/
├── Package.swift            # Package type and pure functions
└── DependencyGraph.swift    # Graph algorithms
```

#### Generation Domain

```swift
Domain/Generation/
└── CodeGeneration.swift     # Pure code generation functions
```

**Responsibilities:**
- Implement business logic
- Define domain types
- Pure transformations only

**Rules:**
- No side effects
- No dependencies on effects
- Fully testable

### Layer 4: Effects

Abstraction over side effects:

```swift
Effects/
├── FileSystem.swift         # File I/O
├── Diagnostics.swift        # Logging/reporting
└── Process.swift            # Process execution
```

**Responsibilities:**
- Wrap side effects
- Provide live and mock implementations
- Enable testing

**Rules:**
- Protocol-based or struct-based
- Live and test implementations
- No business logic

### Layer 5: Utilities

Reusable point-free utilities:

```swift
Utilities/
├── Functional.swift         # Point-free operators and combinators
├── Dependencies.swift       # Dependency injection
├── Sequence+Extensions.swift
└── String+Extensions.swift
```

## Point-Free Patterns

### Function Composition Operators

#### Forward Composition (`>>>`)

Combines functions left-to-right:

```swift
let pipeline = f >>> g >>> h
// Equivalent to: { h(g(f($0))) }
```

#### Backward Composition (`<<<`)

Combines functions right-to-left:

```swift
let pipeline = h <<< g <<< f
// Equivalent to: { h(g(f($0))) }
```

#### Pipe Operator (`|>`)

Applies a value to a function:

```swift
let result = value |> f |> g |> h
// Equivalent to: h(g(f(value)))
```

### Higher-Order Functions

#### map

Transform each element:

```swift
let transform = map(Package.withMappedName)
let mapped = packages |> transform
```

#### filter

Select elements matching predicate:

```swift
let filterTests = filter { !$0.kind.isTest }
let nonTests = packages |> filterTests
```

#### reduce

Combine elements into single value:

```swift
let countDeps = reduce(0) { count, pkg in
  count + pkg.dependencies.count
}
let total = packages |> countDeps
```

### Predicate Combinators

#### not

Negate a predicate:

```swift
let isNotExcluded = not(isExcluded)
packages |> filter(isNotExcluded)
```

#### and / or

Combine predicates:

```swift
let isValid = and(hasName, hasPath)
packages |> filter(isValid)
```

### Conditional Application

#### when

Apply function conditionally:

```swift
let process = when(config.leafInfo) {
  $0 |> enrichWithDependencyInfo(graph: graph)
}
packages |> process
```

#### ifElse

Choose between two transformations:

```swift
let sort = ifElse(
  { config.formatting.pragmaMarks },
  then: sortByPath,
  else: sortByName
)
packages |> sort
```

### Side Effect Management

#### tap

Perform side effect without changing value:

```swift
packages
  |> tap { diagnostics.remark("\($0.count) packages") }
  |> processPackages
```

## Effect System

### Dependency Injection

The plugin uses a lightweight dependency injection system:

```swift
// Define dependencies
struct Dependencies {
  var fileSystem: FileSystemEffect
  var diagnostics: DiagnosticsEffect
  var process: ProcessEffect
}

// Access in code
@Dependency(\.fileSystem) var fileSystem
@Dependency(\.diagnostics) var diagnostics

// Set for production
try withDependencies {
  $0 = .live(context: context)
} operation: {
  // Code runs with live dependencies
}

// Set for testing
withDependencies {
  $0.fileSystem = .mock(files: [...])
  $0.diagnostics = .silent
} operation: {
  // Code runs with mocked dependencies
}
```

### Effect Types

#### FileSystemEffect

```swift
struct FileSystemEffect {
  var fileExists: (FilePath) -> Bool
  var readFile: (FilePath) throws -> Data
  var writeFile: (FilePath, Data) throws -> Void
  // ...
}
```

**Testing:**
```swift
let mockFS = FileSystemEffect.mock(files: [
  "config.json": configData
])
```

#### DiagnosticsEffect

```swift
struct DiagnosticsEffect {
  var emit: (Severity, String) -> Void
  var warning: (String) -> Void
  var error: (String) -> Void
  var remark: (String) -> Void
}
```

**Testing:**
```swift
var messages: [(Severity, String)] = []
let mockDiag = DiagnosticsEffect.mock { severity, msg in
  messages.append((severity, msg))
}
```

#### ProcessEffect

```swift
struct ProcessEffect {
  var run: (FilePath, [String]) throws -> ProcessResult
}
```

**Testing:**
```swift
let mockProcess = ProcessEffect.mock(
  result: .init(terminationStatus: 0, terminationReason: .exit)
)
```

## Testing Strategy

### Pure Function Tests

Pure functions are trivially testable:

```swift
func testFilterExcludedPackages() {
  let packages = [
    Package(name: "A", ...),
    Package(name: "B", ...),
    Package(name: "C", ...)
  ]
  
  let excluded = Set(["B"])
  let filtered = packages |> filterExcludedPackages(excluded)
  
  XCTAssertEqual(filtered.count, 2)
  XCTAssertEqual(filtered.map(\.name), ["A", "C"])
}
```

### Effect-Based Tests

Test workflows with mocked effects:

```swift
func testWorkflowWithMockEffects() throws {
  var writtenFiles: [FilePath: Data] = [:]
  var diagnostics: [String] = []
  
  try withDependencies {
    $0.fileSystem = .mock(files: [
      "config.json": configData,
      "header.swift": headerData
    ])
    $0.fileSystem.writeFile = { path, data in
      writtenFiles[path] = data
    }
    $0.diagnostics = .mock { _, msg in
      diagnostics.append(msg)
    }
  } operation: {
    let workflow = PluginWorkflow(context: mockContext)
    try workflow.execute(arguments: [])
  }
  
  XCTAssertTrue(writtenFiles.keys.contains("Package.swift"))
  XCTAssertTrue(diagnostics.contains("PackageGenerator has finished"))
}
```

### Property-Based Testing

Pure functions enable property-based testing:

```swift
func testPackageFilteringPreservesInvariants() {
  // Property: Filtering is idempotent
  let packages = generateRandomPackages()
  let excluded = Set(["A", "B"])
  
  let filtered1 = packages |> filterExcludedPackages(excluded)
  let filtered2 = filtered1 |> filterExcludedPackages(excluded)
  
  XCTAssertEqual(filtered1, filtered2)
}
```

## Contributing

### Adding New Features

1. **Domain First**: Implement pure logic in domain layer
2. **Effects If Needed**: Add new effect types for new capabilities
3. **Compose**: Wire up in workflow using `>>>` and `|>`
4. **Test**: Add tests for pure functions and workflows

### Code Style

- **Prefer point-free style** for transformations
- **Use descriptive names** for partial application
- **Keep functions small** (< 20 lines)
- **Document with examples** for complex compositions

### Example: Adding a New Feature

```swift
// 1. Add domain type
struct ValidationReport {
  let warnings: [String]
  let errors: [String]
}

// 2. Add pure function
func validatePackages(config: Configuration) -> ([Package]) -> ValidationReport {
  { packages in
    var warnings: [String] = []
    // ... validation logic
    return ValidationReport(warnings: warnings, errors: [])
  }
}

// 3. Compose in workflow
func execute(arguments: [String]) throws {
  try packageDirectory
    |> loadConfiguration
    |> parsePackages
    |> tap { packages in
      let report = packages |> validatePackages(config: config)
      report.warnings.forEach(diagnostics.warning)
    }
    |> processPackages
    // ...
}

// 4. Test
func testValidatePackages() {
  let packages = [/* test data */]
  let report = packages |> validatePackages(config: testConfig)
  XCTAssertEqual(report.warnings.count, 2)
}
```

## Further Reading

- [Point-Free Videos](https://www.pointfree.co/) - Source of these patterns
- [Functional Swift](https://www.objc.io/books/functional-swift/) - Functional programming in Swift
- [Railway Oriented Programming](https://fsharpforfunandprofit.com/rop/) - Error handling in functional style

---

**Questions?** Open an issue or discussion on GitHub!
