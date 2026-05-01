# PackageGenerator V2

Auto-generate complex multi-target SPM `Package.swift`. Read source imports, resolve dependencies, build targets. Works with heavily modularized projects + TCA.

- **Backward compatible**: old config format still works
- **Zero-exclusion filtering**: only links known targets + products (Apple SDKs auto-ignored)
- **Advanced analysis**: unused target detection, dependency weight, exported files
- **CLI-free config**: auto-finds `packageGenerator.yaml/yml/json`
- **Full V2 architecture**: 7 epics from design, strict schema

## Quick Start

1. **Install** (add to dependencies in your root Package.swift):
   ```swift
   .package(url: "https://github.com/mackoj/PackageGeneratorPlugin.git", from: "1.0.0")
   ```

2. **Create** config at project root. Choose YAML or JSON:
   
   **packageGenerator.yaml:**
   ```yaml
   verbose: false
   dryRun: true
   pragmaMark: true
   spaces: 4
   headerFileURL: PackageHeader.swift
   
   packageDirectoryTargets:
     - path: Sources/Core
       targets:
         - name: Core
           type: regular
         - name: CoreTests
           type: test
     
     - path: Sources/Features
       targets:
         - name: Auth
           type: regular
           parameters:
             - 'swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]'
         - name: AuthTests
           type: test
   
   mappers:
     imports:
       ComposableArchitecture: '.product(name: "ComposableArchitecture", package: "swift-composable-architecture")'
   
   exclusions:
     apple: []
     imports:
       - MyPrivateFramework
   ```

3. **Run** plugin (Xcode):
   - Right-click package → "Package Generator"
   - First run uses dry-run (generates `Package_generated.swift`)
   - Review output, then set `dryRun: false` to write to real `Package.swift`

4. **CI**: `swift package plugin --allow-writing-to-package-directory package-generator`

## Configuration Reference

### Top-Level Settings

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `verbose` | Bool | false | Print detailed diagnostics |
| `dryRun` | Bool | true | Generate `Package_generated.swift` instead of `Package.swift` |
| `pragmaMark` | Bool | false | Add `// MARK:` comments grouping targets by path |
| `generateExportedFiles` | Bool | false | Generate `exported.swift` with `@_exported import` for each target |
| `exportedFilesRelativePath` | String | null | Subdirectory for exported files (e.g., `"Generated"`) |
| `headerFileURL` | String | null | Path to file prepended to `Package.swift` |
| `spaces` | Int | 2 | Indentation spaces |
| `keepTempFiles` | Bool | false | Preserve YAML→JSON temp files (debug) |
| `leafInfo` | Bool | false | Add dependency count comments to targets |
| `unusedThreshold` | Int | null | Warn if local target used ≤ this (0 = warn if unused) |
| `silenceUnresolvedImportWarnings` | Bool | false | Don't warn about unresolved imports |

### packageDirectoryTargets

Array of directory groups. Each group declares path + targets.

```yaml
packageDirectoryTargets:
  - path: Sources/Modules
    targets:
      - name: ModuleA
        type: regular                          # regular, test, or macro
        path: null                             # override computed path if needed
        exclude: ["__Snapshots__", "Mocks"]   # exclude patterns
        parameters:                            # inline SPM target parameters
          - 'swiftSettings: [...]'
          - 'resources: [.process("Files")]'
        regularTargetName: null                # for tests: explicit link to regular target
```

**Path Resolution** (shortest-path logic):
- Regular target: `<path>/Sources/<name>` or custom `path`
- Test target: `<path>/Tests/<name>` or custom `path`
- If computed path doesn't exist, recursive search in Sources/Tests wins shortest match
- Test auto-pairs with regular via suffix strip (e.g., `ModuleATests` → `ModuleA`)

### mappers

Override import → product mapping + target renaming.

```yaml
mappers:
  imports:
    ComposableArchitecture: '.product(name: "ComposableArchitecture", package: "swift-composable-architecture")'
    Alamofire: '.product(name: "Alamofire", package: "Alamofire")'
  
  targets:
    Sources/App/Helpers/Foundation: FoundationHelpers
```

- `imports`: maps import name to SPM `.product()` format
- `targets`: maps target path to alternative name
- Auto-discovered products from root Package.swift dependencies are merged in

### exclusions

Suppress imports from Package.swift generation.

```yaml
exclusions:
  apple:                    # Additional Apple SDKs (beyond built-in list)
    - MyCustomAppleFramework
  imports:                  # Third-party frameworks to skip
    - SomePrivateLib
  targets:                  # Targets to exclude entirely
    - ParserCLI
    - HelperBinary
```

Apple frameworks (UIKit, Foundation, etc.) are auto-excluded. Use `apple` only for extras.

### Backward Compatibility

Old config format with `targetsParameters` dict still works:

```yaml
# OLD FORMAT (still supported)
targetsParameters:
  ModuleA:
    - 'exclude: ["__Snapshots__"]'
    - 'resources: [.process("Files")]'
  ModuleB:
    - 'swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]'

# NEW FORMAT (recommended)
packageDirectoryTargets:
  - path: Sources/Modules
    targets:
      - name: ModuleA
        type: regular
        parameters:
          - 'exclude: ["__Snapshots__"]'
          - 'resources: [.process("Files")]'
      - name: ModuleB
        type: regular
        parameters:
          - 'swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]'
```

Both formats generate identical output. Inline `parameters` is preferred (simpler migration path).

## Advanced Features

### Exported Files

Generate `exported.swift` re-exporting local dependencies:

```yaml
generateExportedFiles: true
exportedFilesRelativePath: Generated
```

For target `Auth` importing `Core`, generates:
```swift
// Generated/exported.swift
@_exported import Core
```

Useful for reducing boilerplate in modular architectures.

### Pragma Mark Grouping

Group targets by path with section comments:

```yaml
pragmaMark: true
```

Output:
```swift
// MARK: -
// MARK: Core
.target(name: "Core", ...),
.testTarget(name: "CoreTests", ...),

// MARK: -
// MARK: Features
.target(name: Auth", ...),
.testTarget(name: "AuthTests", ...),
```

### Dependency Weight

Show dependency count + mark heaviest:

```yaml
leafInfo: true
```

Output:
```swift
.target(name: "Core", dependencies: [...]),      // 3|2
.target(name: "Auth", dependencies: [...]),      // 5|3 🚛
```

First number = total deps, second = local deps. 🚛 = highest local count.

### Unused Target Detection

Warn about targets never imported:

```yaml
unusedThreshold: 0
```

Logs: `📦 UnusedModule is used 0 times`

## Examples

### Large Modular Project

```yaml
verbose: false
dryRun: false
pragmaMark: true
generateExportedFiles: true
exportedFilesRelativePath: Generated
headerFileURL: PackageHeader.swift
spaces: 4
leafInfo: true
unusedThreshold: 1

packageDirectoryTargets:
  - path: Packages/Core
    targets:
      - name: Foundation
        type: regular
      - name: Models
        type: regular
        parameters:
          - 'resources: [.process("Assets.xcassets")]'
      - name: CoreTests
        type: test
  
  - path: Packages/Features
    targets:
      - name: Auth
        type: regular
        parameters:
          - 'swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]'
      - name: Cart
        type: regular
      - name: FeaturesTests
        type: test

mappers:
  imports:
    ComposableArchitecture: '.product(name: "ComposableArchitecture", package: "swift-composable-architecture")'

exclusions:
  imports:
    - CrashlyticsCore
```

### TCA + SwiftUI Project

```yaml
dryRun: false
pragmaMark: true
spaces: 4
headerFileURL: PackageHeader.swift

packageDirectoryTargets:
  - path: Sources/App
    targets:
      - name: AppCore
        type: regular
        parameters:
          - 'swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]'
          - 'swiftSettings: [.defaultIsolation(MainActor.self)]'
      - name: AppUI
        type: regular
      - name: AppTests
        type: test

  - path: Sources/Features/Home
    targets:
      - name: HomeFeature
        type: regular
      - name: HomeUI
        type: regular
      - name: HomeTests
        type: test

mappers:
  imports:
    ComposableArchitecture: '.product(name: "ComposableArchitecture", package: "swift-composable-architecture")'
```

## Diagnostics

Errors appear in Xcode Report Navigator:

- `❌ Error: Config file not found` — no `packageGenerator.{yaml,yml,json}` at root
- `❌ Error: YAML decode failed` — invalid YAML syntax
- `ℹ️ Dropped unresolved import 'SomeLib'` — import not in local targets + external products
- `📦 UnusedModule is used 0 times` — target never imported by others

Use `verbose: true` for detailed tracing.

## FAQ

**Q: Why is my target path not found?**  
A: Check `packageDirectoryTargets[].path`. Plugin uses shortest-path logic in Sources/ and Tests/. If multiple folders match target name, shortest depth wins.

**Q: My old config broke after upgrade.**  
A: V2 supports old `targetsParameters` dict—no changes needed. Migrate to inline `parameters` when ready.

**Q: How do I exclude Apple frameworks?**  
A: They're auto-excluded via the built-in list in `AppleSDKs.swift`. The `exclusions.apple` config key is no longer needed and is silently ignored if present in old configs.

**Q: Can I use both YAML and JSON?**  
A: Yes. Plugin auto-detects by filename. Change file extension to switch formats.

**Q: What if a test target doesn't match a regular target?**  
A: Falls back to first available regular target in same group.

## CI/CD

```bash
# Generate with all validations
swift package plugin --allow-writing-to-package-directory package-generator

# With custom config file
swift package plugin --allow-writing-to-package-directory package-generator --confFile myconfig.yaml
```

Fails if Package.swift has errors or config invalid.

## Troubleshooting

- **Plugin not visible in Xcode?** Run "Resolve Packages" in Package.swift.
- **YAML not working?** Ensure `Yams` dependency in plugin Package.swift.
- **dry-run keeps running?** Check `dryRun: false` in config + check error logs.

## License

MIT
