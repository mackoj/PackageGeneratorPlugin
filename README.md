# Package Generator

Package Generator is a Swift Package Manager Plugin for simply updating your `Package.swift` file in a consistent and understandable way. This is great tool for project that are heavely modularize or use TCA thus rely on a clean and updated `Package.swift`.

* [How does it works?](#how-does-it-works)
* [Installation](#installation)
* [Basic usage](#basic-usage)
* [Configuration](#configuration)

## How does it works?

Package Generator go to all folder set in the configuration then read all swift files in order to look at all the imports to create a target to add to the Package.swift

https://github.com/mackoj/PackageGeneratorCLI

## Installation

Add to your dependencies `.package(url: "https://github.com/mackoj/PackageGeneratorPlugin.git", from: "0.3.0"),`

## Basic usage

The plugin will display message and errors in **Xcode Report navigator**. 

| step | description | img |
| --- | --- | --- |
| 0 | To run it right click on the package you want to run it on. | ![Capture d’écran 2022-11-07 à 11 04 05](https://user-images.githubusercontent.com/661647/200282866-d509a44e-df6b-4fc5-aab1-5fe1aeba2c1c.png) |
| 1 | It will propose you to run it you can provide an optional argument(`--confFile newName.json`) in the argument pane, that will allow you to change the name of the configuration file. Once change the new configuration file name will be stored | ![Capture d’écran 2022-11-07 à 11 05 28](https://user-images.githubusercontent.com/661647/200283337-b89744f5-6b90-4a29-8744-6a5210293146.png) |
| 2 | At first lunch it will ask for permission to write files into the project directory in order for it to work you have to say yes. | <img width="361" alt="Capture d’écran 2022-10-21 à 01 35 07" src="https://user-images.githubusercontent.com/661647/200274173-e3e1e1f7-9d93-4a5e-ac4e-062e6cbc5200.png"> |

_By default in order to prevent suprise it will do a dry-run(not modifing you `Package.swift` but creating a `Package_generated.swift`) for you to allow you time to review it before using it._

## Configuration

To use it you have to set a configuration file at the root of your project named `packageGenerator.json`.
This file contain theses keys:
- `packageDirectories`: An array of string that represent where the modules are
- `headerFileURL`: A string that represent the path of the file that will be copied at the top of the `Package.swift`
- `spaces`: An int that represent the number of spaces that the `Package.swift` generator should use when adding content
- `verbose`: A bool that represent if it should print more information in the console
- `dryRun`: A bool that represent if the generator should replace the `Package.swift` file or create a `Package_generated.swift`
- `mappers.targets`: An dictionary that handle target renaming the key represent a target lastPathComponent and the value represent the name to apply. For exemple in the `packageDirectories` I have `Sources/App/Helpers/Foundation` but in my code I import `FoundationHelpers`.
- `mappers.imports`: An dictionary that represent how to map import that require a `.product` in SPM for exemple `ComposableArchitecture` require to be called `.product(name: "ComposableArchitecture", package: "swift-composable-architecture")` in a `Package.swift`.
- `exclusions`: An object that represent all imports that should not be added as dependencies to a target or targets in the generated `Package.swift`
- `exclusions.apple`: An array of string that represent all Apple SDK that should not be add as dependencies to a target
- `exclusions.imports`: An array of string that represent all other SDK that should not be add as dependencies to a target
- `exclusions.targets`: An array of string that represent all targets that should not be add in the generated `Package.swift`

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

If a new configuration filename is used as explain in #basic-usage step 1. It will be save so that you will not be requeried to input the configuration fileName at each launch. 
