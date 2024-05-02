// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PackageGeneratorPlugin",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .plugin(name: "PackageGenerator", targets: ["Package Generator"]),
  ],
//  dependencies: [
//    .package(path: "/Users/mac-JMACKO01/Developer/PackageGeneratorCLI"),
//  ],
  targets: [
    .binaryTarget(
      name: "package-generator-cli",
      path: "../PackageGeneratorCLI/package-generator-cli-arm64-apple-macosx.artifactbundle.zip"
    ),
//    .binaryTarget(
//      name: "package-generator-cli",
//      url: "https://github.com/mackoj/PackageGeneratorCLI/releases/download/0.4.2/package-generator-cli-arm64-apple-macosx.artifactbundle.zip",
//      checksum: "ddf169bfe8b9260d40069671b8e7282b2655679d2b404d080af2a3935025fb7f"
//    ),
    .plugin(
      name: "Package Generator",
      capability: .command(
        intent: .custom(
          verb: "package-generator",
          description: "Generate the Package.swift based on packageGenerator.json"
        ),
        permissions: [
          .writeToPackageDirectory(reason: "This plug-in need to update the Package.swift in the package folder."),
        ]
      ),
      dependencies: [
//        .product(name: "package-generator-cli", package: "PackageGeneratorCLI"),
        .target(name: "package-generator-cli"),
      ],
      path: "Plugins/PackageGenerator"
    ),
  ]
)
