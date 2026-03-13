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
  targets: [
    .binaryTarget(
      name: "package-generator-cli",
      url: "https://github.com/mackoj/PackageGeneratorCLI/releases/download/0.6.0/package-generator-cli-arm64-apple-macosx.artifactbundle.zip",
      checksum: "6b62ef97d1d930281a4a65e9e47b1aec9d7dc90d2cb5282085cf8e705e5ec743"
    ),
    //.binaryTarget(
    //  name: "package-generator-cli",
    //  path: "../PackageGeneratorCLI/package-generator-cli-arm64-apple-macosx.artifactbundle.zip"
    //),
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
        .target(name: "package-generator-cli"),
      ],
      path: "Plugins/PackageGenerator"
    ),
  ]
)
