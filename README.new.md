# Package Generator - Point-Free Edition

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmackoj%2FPackageGeneratorPlugin%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mackoj/PackageGeneratorPlugin)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmackoj%2FPackageGeneratorPlugin%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/mackoj/PackageGeneratorPlugin)

> **⚡️ Now with Point-Free Architecture!** This is a complete rewrite following functional programming principles for better testability, composability, and maintainability.

Package Generator is a Swift Package Manager plugin that automatically generates and updates your `Package.swift` file by analyzing your source code and extracting dependencies.

Perfect for heavily modularized projects or applications using TCA (The Composable Architecture) that rely on a clean, up-to-date `Package.swift`.

## ✨ What's New in Point-Free Edition

- **🔨 Point-Free Architecture**: Pure functions composed with `>>>` and `|>` operators
- **🎯 Type-Safe Configuration**: Properly nested configuration with compile-time validation
- **🧪 Fully Testable**: Effect isolation makes every component trivially testable
- **📦 Better Error Handling**: Type-safe errors with clear messages
- **🎨 Improved Code Generation**: Cleaner, more maintainable generation logic
- **📚 JSON Schema Support**: IDE autocomplete for configuration files

## 📋 Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Advanced Usage](#advanced-usage)
- [Architecture](#architecture)
- [Migration Guide](#migration-guide)
- [CI Integration](#ci-integration)
- [FAQ](#faq)

## ✨ Features

- ✅ **Automatic Dependency Resolution**: Scans Swift files and extracts `import` statements
- ✅ **Automatic Target Generation**: Creates `.target()` declarations with proper dependencies
- ✅ **Product Generation**: Generates `.library()` products for all non-test targets
- ✅ **Export File Generation**: Optionally creates `@_exported import` files for local dependencies
- ✅ **Smart Exclusions**: Filters out Apple SDKs and third-party dependencies
- ✅ **Name Mapping**: Maps directory paths to custom target names
- ✅ **Import Mapping**: Handles `.product()` declarations for external dependencies
- ✅ **Dry Run Mode**: Preview changes before applying them
- ✅ **Pragma Marks**: Organize targets with `// MARK:` comments
- ✅ **Dependency Analysis**: Find underused packages and dependency graphs

## 📦 Installation

Add to your `Package.swift` dependencies:

```swift
dependencies: [
  .package(url: "https://github.com/mackoj/PackageGeneratorPlugin.git", from: "1.0.0"),
]
```

## 🚀 Quick Start

### 1. Create a Header File

Create `header.swift` at your project root with your package metadata:

```swift
// swift-tools-version:5.7
import PackageDescription

var package = Package(
  name: "MyProject",
  platforms: [.macOS(.v12), .iOS(.v15)],
  products: [
    .executable(name: "MyApp", targets: ["MyApp"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0"),
  ],
  targets: [
    // Executable targets
    .executableTarget(name: "MyApp", path: "Sources/App"),
    
    // Test targets
    .testTarget(name: "MyProjectTests", dependencies: ["MyProject"]),
  ]
)
```

### 2. Create Configuration File

Create `packageGenerator.json` at your project root:

```json
{
  "$schema": "./packageGenerator.schema.json",
  "source": {
    "packageDirectories": [
      "Sources/Features/Home",
      "Sources/Features/Settings",
      "Sources/Core/Networking"
    ],
    "headerFile": "header.swift"
  },
  "output": {
    "mode": "dryRun",
    "formatting": {
      "indentation": 2,
      "pragmaMarks": false
    }
  },
  "exclusion": {
    "apple": "default"
  },
  "verbose": false
}
```

### 3. Run the Plugin

**In Xcode:**
1. Right-click on your package in the Project Navigator
2. Select "Package Generator" from the plugin menu
3. Click "Allow Command to Change Files" when prompted

**From Command Line:**
```bash
swift package plugin --allow-writing-to-package-directory package-generator
```

### 4. Review and Apply

The plugin runs in dry-run mode by default, creating `Package_generated.swift`. Review the output, then set `"mode": "live"` in your configuration to apply changes to `Package.swift`.

## ⚙️ Configuration

### Complete Configuration Example

See [`packageGenerator.example.json`](./packageGenerator.example.json) for a complete example.

### Configuration Structure

```json
{
  "source": {
    "packageDirectories": [...],  // Required: Paths to scan
    "headerFile": "header.swift"  // Required: Header file path
  },
  "output": {
    "mode": "dryRun" | "live",    // Output mode
    "formatting": {
      "indentation": 2 | { "type": "spaces", "count": 2 },
      "pragmaMarks": false          // Add // MARK: comments
    }
  },
  "mapping": {
    "targets": {...},               // Path → Name mappings
    "imports": {...}                // Import → Product mappings
  },
  "exclusion": {
    "apple": "default" | [...],    // Apple SDKs to exclude
    "imports": [...],               // Imports to exclude
    "targets": [...]                // Targets to exclude
  },
  "features": {
    "exportedFiles": {...},         // Generate @_exported files
    "leafInfo": false,              // Add dependency comments
    "unusedThreshold": null,        // Report underused packages
    "keepTempFiles": false,         // Keep temp files for debugging
    "targetParameters": {...}       // Per-target parameters
  },
  "verbose": false
}
```

### Key Configuration Options

#### Source Configuration

```json
"source": {
  "packageDirectories": [
    "Sources/MyFeature",           // Simple path
    {                              // Or structured format
      "target": {
        "path": "Sources/MyFeature",
        "name": "MyFeature"
      },
      "test": {
        "path": "Tests/MyFeatureTests",
        "name": "MyFeatureTests"
      }
    }
  ],
  "headerFile": "header.swift"
}
```

#### Output Mode

```json
"output": {
  "mode": "dryRun",                // Creates Package_generated.swift
  // OR
  "mode": "live",                  // Overwrites Package.swift
  // OR
  "mode": {
    "type": "dryRun",
    "fileName": "Package_preview.swift"  // Custom filename
  }
}
```

#### Import Mapping

For dependencies that require `.product()` declarations:

```json
"mapping": {
  "imports": {
    "ComposableArchitecture": {
      "product": "ComposableArchitecture",
      "package": "swift-composable-architecture"
    }
  }
}
```

#### Exported Files

Generate `@_exported import` files for better ergonomics:

```json
"features": {
  "exportedFiles": {
    "relativePath": "Generated"    // Optional: subdirectory for files
  }
}
```

This creates files like:

```swift
// Sources/MyFeature/Generated/exported.swift
// This file is auto-generated by PackageGeneratorPlugin

@_exported import Dependency1
@_exported import Dependency2
```

## 🏗 Architecture

This plugin follows the **Point-Free** architecture pattern:

### Functional Core, Imperative Shell

```
┌─────────────────────────────────────┐
│      Plugin.swift (Shell)           │  ← Side effects happen here
│  - File I/O                          │
│  - Process execution                 │
│  - Diagnostics                       │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│   PluginWorkflow (Composition)      │  ← Pure function composition
│   Config |> Parse |> Process |>     │
│   Generate |> Write                  │
└────────────┬────────────────────────┘
             │
       ┌─────┴─────┬──────────┐
       ▼           ▼          ▼
  ┌────────┐  ┌────────┐  ┌──────────┐
  │Config  │  │Parsing │  │Generation│  ← Pure domain logic
  │Domain  │  │Domain  │  │Domain    │
  └────────┘  └────────┘  └──────────┘
```

### Key Principles

1. **Pure Functions**: All business logic is pure and testable
2. **Function Composition**: Use `>>>` and `|>` operators to compose workflows
3. **Effect Isolation**: All side effects in dedicated, mockable types
4. **Type Safety**: Rich types prevent invalid states
5. **Immutability**: Transform values instead of mutating state

### Example: Point-Free Style

```swift
// Before (Imperative)
var packages = loadPackages()
packages = packages.filter { !excluded.contains($0.name) }
packages = packages.map { applyMapping($0) }
packages = packages.sorted { $0.name < $1.name }

// After (Point-Free)
let packages = loadedPackages
  |> filter(not(isExcluded))
  |> map(applyMapping)
  |> sortBy(\.name)
```

## 📖 Migration Guide

### From Legacy Configuration

The configuration format has changed. Old format:

```json
{
  "packageDirectories": ["Sources/App"],
  "headerFileURL": "header.swift",
  "spaces": 2,
  "dryRun": true,
  "pragmaMark": false,
  ...
}
```

New format:

```json
{
  "source": {
    "packageDirectories": ["Sources/App"],
    "headerFile": "header.swift"
  },
  "output": {
    "mode": "dryRun",
    "formatting": {
      "indentation": 2,
      "pragmaMarks": false
    }
  },
  ...
}
```

See the [Migration Guide](./MIGRATION.md) for detailed instructions.

## 🔄 CI Integration

```yaml
# .github/workflows/generate-package.yml
name: Generate Package.swift

on: [pull_request]

jobs:
  generate:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Generate Package.swift
        run: |
          swift package plugin --allow-writing-to-package-directory package-generator
      - name: Check for changes
        run: |
          git diff --exit-code Package.swift || \
            (echo "Package.swift is out of date!" && exit 1)
```

## ❓ FAQ

**Q: Why can't I see the plugin in Xcode?**

A: Ensure `swift package resolve` completes without errors. Plugins only appear after successful package resolution.

**Q: Why does the plugin use an external CLI tool?**

A: SPM plugins cannot import other packages. We use [swift-syntax](https://github.com/apple/swift-syntax) via an external CLI to parse Swift files.

**Q: Can I customize the configuration filename?**

A: Yes! Pass `--confFile myconfig.json` when running the plugin.

**Q: How do I debug configuration issues?**

A: Set `"verbose": true` and check Xcode's Report Navigator for detailed logs.

**Q: What's the performance impact?**

A: The plugin is fast - it only runs when you explicitly invoke it, not on every build.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [swift-syntax](https://github.com/apple/swift-syntax)
- Inspired by [Point-Free](https://www.pointfree.co/) functional programming principles
- Original implementation by [@mackoj](https://github.com/mackoj)

---

**Made with ❤️ using Point-Free principles**
