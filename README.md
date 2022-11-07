# Package Generator

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmackoj%2FPackageGeneratorPlugin%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mackoj/PackageGeneratorPlugin)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmackoj%2FPackageGeneratorPlugin%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/mackoj/PackageGeneratorPlugin)

Package Generator is a Swift Package Manager Plugin for simply updating your `Package.swift` file consistently and understandably. This is a great tool for projects that are heavily modularized or use TCA and thus rely on a clean and updated `Package.swift`.

⚠️ This only support Apple Silicon computer at the moment.

* [How does it work?](#how-does-it-work)
* [Installation](#installation)
* [Basic usage](#basic-usage)
* [Configuration](#configuration)

## How does it work?

Package Generator goes to all folders set in the configuration then read all swift files to look at all the imports to create a target to add to the Package.swift.

The code analyzing part is made using [swift-syntax](https://github.com/apple/swift-syntax.git) since I didn't find a way to link it to the plugin I have to package it in a [CLI](https://github.com/mackoj/PackageGeneratorCLI) that is used to do the parsing part.

## Installation

Add to your dependencies `.package(url: "https://github.com/mackoj/PackageGeneratorPlugin.git", from: "0.3.0"),`

## Basic usage

The plugin will display messages and errors in **Xcode Report navigator**. 

| step | description | img |
| --- | --- | --- |
| 0 | To run it right click on the package you want to run it on. | ![Capture d’écran 2022-11-07 à 11 04 05](https://user-images.githubusercontent.com/661647/200282866-d509a44e-df6b-4fc5-aab1-5fe1aeba2c1c.png) |
| 1 | It will propose you to run it you can provide an optional argument(`--confFile newName.json`) in the argument pane, which will allow you to change the name of the configuration file. Once change the new configuration file name will be stored | ![Capture d’écran 2022-11-07 à 11 05 28](https://user-images.githubusercontent.com/661647/200283337-b89744f5-6b90-4a29-8744-6a5210293146.png) |
| 2 | At first launch, it will ask for permission to write files into the project directory for it to work you have to select "Allow Command to Change Files". | <img width="361" alt="Capture d’écran 2022-10-21 à 01 35 07" src="https://user-images.githubusercontent.com/661647/200274173-e3e1e1f7-9d93-4a5e-ac4e-062e6cbc5200.png"> |

_By default to prevent any surprise it will do a dry-run(not modifying your `Package.swift` but creating a `Package_generated.swift`) for you to allow you time to review it before using it._

## Configuration

To use it you have to set a configuration file at the root of your project named `packageGenerator.json`.
This file contains these keys:
- `packageDirectories`: An array of string that represents where the modules are
- `headerFileURL`: A string that represents the path of the file that will be copied at the top of the `Package.swift`
- `spaces`: An int that represents the number of spaces that the `Package.swift` generator should use when adding content
- `verbose`: A bool that represents if it should print more information in the console
- `pragmaMark`: A bool that represents if we should add `// MARK: -` in the generated file
- `dryRun`: A bool that represents if the generator should replace the `Package.swift` file or create a `Package_generated.swift`
- `mappers.targets`: An dictionary that handles target renaming the key represents a target `lastPathComponent` and the value represents the name to apply. For example in the `packageDirectories` I have `Sources/App/Helpers/Foundation` but in my code, I import `FoundationHelpers`.
- `mappers.imports`: An dictionary that represents how to map import that requires a `.product` in SPM for example `ComposableArchitecture` require to be called `.product(name: "ComposableArchitecture", package: "swift-composable-architecture")` in a `Package.swift`.
- `exclusions`: An object that represents all imports that should not be added as dependencies to a target or targets in the generated `Package.swift`
- `exclusions.apple`: An array of string that represents all Apple SDK that should not be add as dependencies to a target
- `exclusions.imports`: An array of string that represents all other SDK that should not be added as dependencies to a target
- `exclusions.targets`: An array of string that represent all targets that should not be added in the generated `Package.swift`

```json
{
  "packageDirectories": [
    "Sources/App/Clients/Analytics",
    "Sources/App/Clients/AnalyticsLive",
    "Sources/App/Daemons/Notification",
    "Sources/App/Helpers/Foundation"
  ],
  "headerFileURL": "header.swift",
  "verbose": false,
  "pragmaMark": false,
  "spaces": 2,
  "dryRun": true,
  "mappers": {
    "targets": {
      "Foundation": "FoundationHelpers"
    },
    "imports": {
      "ComposableArchitecture": ".product(name: \"ComposableArchitecture\", package: \"swift-composable-architecture\")"
    }
  },
  "exclusions": {
    "apple": [
      "ARKit",
      "AVFoundation"
    ],
    "imports": [
      "PurchasesCoreSwift"
    ],
    "targets": [
      "ParserCLI"
    ]
  }
}
```

If a new configuration filename is used as explained in #basic-usage step 1. It will be saved so that you will not be required to input the configuration fileName at each launch. 


### Header File

The content of `headerFileURL` from the configuration will be added to the top of the generated `Package.swift`
I advise adding all required `dependencies` and a least test targets, executable targets.
If a target requires parameters other than(name, dependencies, and path) it should be in there too since other parameters are not yet supported.

```swift
// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

var package = Package(
  name: "project",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v12),
    .iOS("15.0")
  ]
)

package.dependencies.append(contentsOf: [
  .package(url: "https://github.com/mackoj/PackageGeneratorPlugin.git", from: "0.3.0"),
  .package(url: "https://github.com/mackoj/SchemeGeneratorPlugin.git", from: "0.5.5"),
  .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "0.45.0"),
])

package.products.append(contentsOf: [
  .executable(name: "server", targets: ["server"]),
  .executable(name: "parse", targets: ["ParserRunner"]),
])

package.targets.append(contentsOf: [
  // MARK: -
  // MARK: Test Targets
  .testTarget(
    name: "MyProjectTests",
    dependencies: [
      "MyProject",
    ]
  ),
  
  // MARK: -
  // MARK: Executables
  .executableTarget(
    name: "server",
    path: "Sources/Backend/Sources/Run"
  ),
  .executableTarget(
    name: "ParserRunner",
    path: "Sources/App/Parsers/Runner"
  ),
])
```
