# Package Generator

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmackoj%2FPackageGeneratorPlugin%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mackoj/PackageGeneratorPlugin)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmackoj%2FPackageGeneratorPlugin%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/mackoj/PackageGeneratorPlugin)

⚠️ This is in beta

Package Generator is a Swift Package Manager Plugin for simply updating your `Package.swift` file consistently and understandably. This is a great tool for projects that are heavily modularized or use TCA and thus rely on a clean and updated `Package.swift`.

Package Generator adds imports that it read from the source code files to their target in `Package.swift`. This will help reduce compilation issues with SwiftUI Preview too.

* [First Launch?](#first-launch)
* [How does it work?](#how-does-it-work)
* [Installation](#installation)
* [Basic usage](#basic-usage)
* [Configuration](#configuration)
* [FAQ](#faq)

## First Launch

After [installing it](#installation) you will be able to run it but for it to work properly it needs to be [configured](#configuration). By default, it will run with `dry-run` set to true and this will create a file `Package_generated.swift` to allow you to preview what will happen. After having properly configured it and testing that the `Package_generated.swift` generate the correct content you will need to set `dry-run` to false in the configuration to write in the real `Package.swift` file.

Each time you need to add a module remember to add it to the configuration file. 

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
- `targetsParameters`: An dictionary that represent what custom parameter to add to a target

```json
{
  "packageDirectories": [
    "Sources/App/Clients/Analytics",
    "Sources/App/Clients/AnalyticsLive",
    "Sources/App/Daemons/Notification",
    "Sources/App/Helpers/Foundation"
  ],
  "headerFileURL": "header.swift",
  "targetsParameters": {
    "Analytics": ["exclude: [\"__Snapshots__\"]", "resources: [.copy(\"Fonts/\")]"],
    "target2": ["resources: [.copy(\"Dictionaries/\")]"]
  },
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

The content of `headerFileURL` from the configuration will be added to the top of the generated `Package.swift`.

I advise adding all required `dependencies` and **Test Targets**, **System Librarys**, **Executable Targets** and **Binary Targets**(https://github.com/mackoj/PackageGeneratorPlugin/issues/8).

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
  ],
  products: [
    .executable(name: "server", targets: ["server"]),
    .executable(name: "parse", targets: ["ParserRunner"]),
  ],
  dependencies: [
    .package(url: "https://github.com/mackoj/PackageGeneratorPlugin.git", from: "0.3.0"),
    .package(url: "https://github.com/mackoj/SchemeGeneratorPlugin.git", from: "0.5.5"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "0.45.0"),
  ],
  targets: [
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
  ]
)
```

## FAQ

> Why is plug-in is not visible?

This plug-in can work if you do a right click on your project package and only if the `Resolves Packages` is passing without issue. 

> Why does the plugin have an executable dependency?

Because we cannot import other packages in an SPM Plugin and we need [swift-syntax](https://github.com/apple/swift-syntax.git) to parse code and extract imports.

> It always creates an invalid `Package.swift` file.

Look at the `Report Navigator` in Xcode it might be due to imports that don't exist or that require the use of [mappers-imports](#configuration). 

> Why doesn't it use a hidden file like `.packageGenerator` for configuring the tool?

Because it would not be visible in Xcode and this file might need to be edited often. But [you can change this](#configuration) if you want by giving the `--confFile` argument when using the tool.
