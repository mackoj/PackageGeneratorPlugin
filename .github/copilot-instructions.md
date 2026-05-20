# PackageGeneratorPlugin — Copilot Instructions

## What This Project Is

A Swift Package Manager **Command Plugin** that auto-generates `Package.swift` for heavily modularized SPM projects. It reads source files, extracts imports via a companion binary (`package-generator-cli`), resolves dependencies, and writes the output.

It is **not a library**. There is no test target. Testing is done via dry-run in consumer projects.

## Build & Run

```bash
# Build the package (plugin + yaml-converter tool)
swift build

# Run the plugin in a consumer project
swift package plugin --allow-writing-to-package-directory package-generator

# With explicit config file
swift package plugin --allow-writing-to-package-directory package-generator --confFile myconfig.yaml

# Dry run (writes Package_generated.swift instead of Package.swift)
# Set dryRun: true in config, then:
swift package plugin --allow-writing-to-package-directory package-generator
diff Package.swift Package_generated.swift
```

## Architecture

### Targets

- **`Package Generator`** plugin — `Plugins/PackageGenerator/` — the SPM command plugin
- **`yaml-converter`** executable — `Tools/YamlConverter/` — converts YAML→JSON using Yams; invoked as a subprocess by the plugin
- **`package-generator-cli`** binary — ARM64-only artifact bundle from GitHub releases; does the actual Swift import extraction from source files

### Plugin Pipeline (`PackageGeneratorV2.swift` orchestrates)

| Phase | File | What it does |
|-------|------|-------------|
| Config load | `ConfigLoader.swift` | Finds `packageGenerator.{yaml,yml,json}`, converts YAML via `yaml-converter` subprocess, decodes into `ConfigurationV2` |
| 2 — Discovery | `TargetResolution.swift` | `resolveTargetPaths` (shortest-path logic), `linkTestTargets` (strips "Tests" suffix), `discoverExternalDeps` (reads SPM graph), `runCLI` (invokes `package-generator-cli`) |
| 3 — Import Analysis | `ImportAnalysis.swift` | `filterImports` — drops self-imports and explicit exclusions; Apple SDK filtering is intentionally **deferred** to render phase |
| 4 — Code Generation | `CodeGeneration.swift` | `renderSingleTarget`, `generateProductsSection`, `generateTargetsSection`, `writeOutput` |
| 5 — Advanced Features | `AdvancedFeatures.swift` | `generateExportedFiles`, `detectUnusedTargets`, `computeDependencyWeight` |

Entry point: `Plugin.swift` → `PackageGeneratorV2.generate(config:context:)`

### Configuration (`ConfigurationV2.swift`)

Config is decoded from JSON (YAML is converted first). The decoder merges the legacy `targetsParameters` dict into inline `parameters` on each target **in memory only** — the on-disk config file is never modified.

## Key Conventions

### PackagePlugin API Usage
- Always use `context.package.directoryURL` (not the deprecated `directory`)
- Always use `context.pluginWorkDirectoryURL` for temp files
- Always use `URL`-based APIs with `appendingPathComponent` / `deletingLastPathComponent`

### External Dependency Identity
Use `dependency.package.id` (URL-derived identity, e.g. `"vitamin-play-apple-releases"`) **not** `dependency.package.displayName` (self-declared name, may differ). This is what SPM requires in `.product(name:package:)`.

```swift
// Correct
let packageIdentity = dependency.package.id

// Wrong — displayName can differ from the URL-derived identity
let packageIdentity = dependency.package.displayName
```

### Apple SDK Filtering is Deferred
`filterImports` (Phase 3) does **not** filter Apple SDKs. This is intentional: filtering happens in `renderSingleTarget` (Phase 4), after checking `externalDeps` first. This prevents silently dropping external products whose names collide with Apple SDK names (e.g., `Charts`).

### Parameter Injection is Verbatim
`parameters` strings from config are written directly into `Package.swift` without parsing or validation:
```swift
for param in target.parameters ?? [] {
    extraParams += ",\n\(s2)\(param.trimmingCharacters(in: .whitespacesAndNewlines))"
}
```

### Dependency Resolution Priority (in `renderSingleTarget`)
1. `externalDeps` map → `.product(name:package:)` reference
2. `allLocalTargetNames` set → `"TargetName"` string literal
3. Apple SDK built-in list (`AppleSDKs.swift`) → silently skipped
4. Otherwise → warning emitted, dep skipped

### Swift 6 Strict Concurrency
The package uses `swiftLanguageModes: [.v6]`. All new code must comply with Swift 6 strict concurrency rules.

### Code Structure
Top-level functions at file scope (not in types) is the pattern for all phase functions. `PackageGeneratorV2` is the only struct, with `static func generate`.

### YAML Temp Files
YAML configs are converted to a temp file named `.packageGenerator_temp_<UUID>.json` in the package directory. Cleaned up automatically unless `keepTempFiles: true`.

### Config Search Order
`--confFile` arg → `packageGenerator.yaml` → `packageGenerator.yml` → `packageGenerator.json`

### Binary Target
`package-generator-cli` is ARM64-only (`arm64-apple-macosx`). To test against a local build, swap the `.binaryTarget` in `Package.swift` to use a local `path:` (the commented-out block is already there).
