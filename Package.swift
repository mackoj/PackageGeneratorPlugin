// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PackageGeneratorPlugin",
  platforms: [
    .macOS(.v13),
  ],
  products: [
    .plugin(name: "PackageGenerator", targets: ["Package Generator"]),
  ],
  dependencies: [
    .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1"),
    // .package(path: "/Users/mac-JMACKO01/Developer/PackageGeneratorCLI"),
  ],
  targets: [
// The code that is used in the official version
   .binaryTarget(
     name: "package-generator-cli",
     url: "https://github.com/mackoj/PackageGeneratorCLI/releases/download/0.7.0/package-generator-cli-arm64-apple-macosx.artifactbundle.zip",
     checksum: "a74560dd57e08a9e444ce0b1a3200a63a665a189ac5f55717d615763f0076717"
   ),

// To test after building the artifact
//      .binaryTarget(
//        name: "package-generator-cli",
//        path: "../PackageGeneratorCLI/package-generator-cli-arm64-apple-macosx.artifactbundle.zip"
//      ),
    .executableTarget(
      name: "yaml-converter",
      dependencies: [
        .product(name: "Yams", package: "Yams"),
      ],
      path: "Tools/YamlConverter"
    ),
    .plugin(
      name: "Package Generator",
      capability: .command(
        intent: .custom(
          verb: "package-generator",
          description: "Generate the Package.swift based on the packageGenerator config"
        ),
        permissions: [
          .writeToPackageDirectory(reason: "This plug-in need to update the Package.swift in the package folder."),
        ]
      ),
      dependencies: [
        .target(name: "package-generator-cli"),
        .target(name: "yaml-converter"),
      ],
      path: "Plugins/PackageGenerator"
    ),
    // A `.plugin` target cannot be imported, so this target compiles the
    // PackagePlugin-free generator sources directly (symlinked under `Shared/`).
    .testTarget(
      name: "PackageGeneratorTests",
      path: "Tests/PackageGeneratorTests"
    ),
  ],
  swiftLanguageModes: [.v6]
)
