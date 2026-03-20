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
  dependencies: [
    .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1"),
  ],
  targets: [
    .binaryTarget(
      name: "package-generator-cli",
      url: "https://github.com/mackoj/PackageGeneratorCLI/releases/download/0.6.1/package-generator-cli-arm64-apple-macosx.artifactbundle.zip",
      checksum: "8eb833ab6ae853c82f67657c1c8fd27cbcbe30dfc7667893fe2a17a9a72622fd"
    ),
    //.binaryTarget(
    //  name: "package-generator-cli",
    //  path: "../PackageGeneratorCLI/package-generator-cli-arm64-apple-macosx.artifactbundle.zip"
    //),
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
  ]
)
