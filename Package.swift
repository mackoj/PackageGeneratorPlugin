// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PackageGeneratorPlugin",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .plugin(name: "PackageGenerator", targets: ["PackageGenerator"]),
  ],
  targets: [
    .binaryTarget(
      name: "package-generator-cli",
      url: "https://github.com/mackoj/PackageGeneratorCLI/releases/download/0.1.0/package-generator-cli.artifactbundle.zip",
      checksum: "b205e6d627045665046ef76c81c5d32f2f10348adc454022b6d1735e66b1c5ad"
    ),
    .plugin(
      name: "PackageGenerator",
      capability: .command(
        intent: .custom(
          verb: "package-generator",
          description: "Generate the Package.swift based on spmgen.json"
        ),
        permissions: [
          .writeToPackageDirectory(reason: "This plug-in need to update the Package.swift in the source directory folder."),
        ]
      ),
      dependencies: [
        .target(name: "package-generator-cli")
      ]
    ),
  ]
)
