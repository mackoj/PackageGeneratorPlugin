# Architecture rules

The mechanical part of `CODING_STANDARDS.md`, enforced by the `Architecture/` package with [swift-llm-check](https://github.com/mackoj/swift-llm-check): `swift test --package-path Architecture` (macOS). Generated from its rules; do not edit by hand.

## structure

The pure core and the plugin shell. Read before you add an `import` or a file to `Plugins`.

### Every Swift file in the tests' and benchmarks' `Shared` folders is a symbolic link into `Plugins/PackageGenerator`.

`test-sources-link-the-plugin-files`: A `.plugin` target cannot be imported, so the test target and the benchmarks compile the plugin's own files through symbolic links in `Tests/PackageGeneratorTests/Shared` and `Benchmarks/Benchmarks/GeneratorBenchmarks/Shared` (CODING_STANDARDS.md, "The tests compile the real files"). A copy, or a link to anywhere else, would test and measure code the plugin no longer runs.

**How to fix:** Replace the file with a relative link: `ln -s ../../../Plugins/PackageGenerator/Name.swift Tests/PackageGeneratorTests/Shared/Name.swift`.

Bad:

```swift
cp Plugins/PackageGenerator/ParsedPackage.swift Tests/PackageGeneratorTests/Shared/
```

Good:

```swift
Shared/ParsedPackage.swift -> ../../../Plugins/PackageGenerator/ParsedPackage.swift
```

### A plugin file the tests link imports only Foundation.

`core-files-import-only-foundation`: The generator's pure core (CODING_STANDARDS.md, "Pure core, thin shell") is compiled by the plugin, the test target and the benchmarks; the last two cannot import `PackagePlugin`. Yams, the package's only dependency, belongs to `yaml-converter`, not the plugin.

**How to fix:** Keep `PackagePlugin` in the shell: take the value the core needs as a parameter, and report warnings through a closure the caller passes (it calls `Diagnostics.emit`).

Bad:

```swift
// Plugins/PackageGenerator/ProductGeneration.swift
import PackagePlugin
Diagnostics.emit(.warning, "Dropped unresolved import '\(dep)'")
```

Good:

```swift
// Plugins/PackageGenerator/ProductGeneration.swift
import Foundation
func render(_ target: ParsedPackage, warn: (String) -> Void) -> String
```

### The plugin reports through `Diagnostics.emit`, never `print`.

`plugin-reports-through-diagnostics`: A command plugin's standard output is not shown in Xcode's issue navigator, and in a terminal it mixes with SwiftPM's own output. `Diagnostics` gives every message a severity users can filter (CODING_STANDARDS.md, "Diagnostics, not print").

**How to fix:** Call `Diagnostics.emit(.remark, …)`, guarded by `config.verbosePlugin` when it is verbose-only.

Bad:

```swift
print("Resolved \(resolvedPaths.count) targets")
```

Good:

```swift
if config.verbosePlugin { Diagnostics.emit(.remark, "Resolved \(resolvedPaths.count) targets") }
```

## output

What ends up in the generated `Package.swift`. Read before you change dependency resolution.

### The plugin never reads a package's `displayName`.

`external-products-use-package-identity`: `.product(name:package:)` needs the package identity SwiftPM derives from the URL, `dependency.package.id`. `displayName` is the name a package declares for itself and can differ (`VitaminPlay` for `vitamin-play-apple-releases`), which produces a `Package.swift` that does not resolve (CODING_STANDARDS.md, "External products use the package identity").

**How to fix:** Use `dependency.package.id`.

Bad:

```swift
let packageIdentity = dependency.package.displayName
```

Good:

```swift
let packageIdentity = dependency.package.id
```

### `filterImports` does not consult `appleDefaultSDKs` or `appleDefaultSDKSet`.

`apple-sdk-filtering-is-deferred`: Imports are matched to external products and local targets before Apple SDKs are skipped. Filtering SDK names out earlier silently drops a package product that shares a name with an SDK, like `Charts` (CODING_STANDARDS.md, "Apple SDK filtering happens at render time").

**How to fix:** Leave the import in `filterImports`' result. `renderSingleTarget` skips it once it has found no external product and no local target of that name.

Bad:

```swift
func filterImports(rawImports: [String], …) -> [String] {
  rawImports.filter { !appleDefaultSDKs.contains($0) }
```

Good:

```swift
} else if appleDefaultSDKSet.contains(dep) {
  // Known Apple SDK: skip silently, after externalDeps and local targets were checked.
```

## plugin-api

How the plugin talks to SwiftPM. Read before you use a `PackagePlugin` API.

### The plugin uses the URL-based `PackagePlugin` APIs, not the deprecated `Path` ones.

`plugin-uses-url-apis`: `context.package.directory`, `context.pluginWorkDirectory` and `tool.path` return the deprecated `PackagePlugin.Path` and warn on every build; the `URL` variants work with Foundation directly (CODING_STANDARDS.md, "URL-based PackagePlugin APIs").

**How to fix:** Use `directoryURL`, `pluginWorkDirectoryURL` and `url`, then `appendingPathComponent`.

Bad:

```swift
let packageDir = context.package.directory
```

Good:

```swift
let packageDir = context.package.directoryURL
```

## testing

Swift Testing, and no silenced tests. Read before you add or skip a test.

### Tests use Swift Testing, never XCTest.

`tests-use-swift-testing`: The suite is Swift Testing only (CODING_STANDARDS.md, "Swift Testing only"): `@Test`, `#expect` and `#require` give one failure message style, parameterised tests and parallel, randomly ordered runs.

**How to fix:** Write an `@Suite` of `@Test` functions with `#expect` and `#require`, and `import Testing`.

Bad:

```swift
import XCTest
final class ProductTests: XCTestCase { func testName() { XCTAssertEqual(…) } }
```

Good:

```swift
import Testing
@Suite struct ProductTests { @Test func name() { #expect(…) } }
```

### No test or suite is `.disabled`.

`tests-are-not-disabled`: A disabled test still reads as coverage while checking nothing. A failing behaviour is either fixed, or asserted as a known issue that says why.

**How to fix:** Fix the code or the test. If the bug must wait, wrap the failing part in `withKnownIssue("…")`.

Bad:

```swift
@Test(.disabled("flaky")) func rendersProducts() {
```

Good:

```swift
@Test func rendersProducts() {
```
