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
      url: "https://github.com/mackoj/PackageGeneratorCLI/releases/download/0.2.0/package-generator-cli.artifactbundle.zip",
      checksum: "46dccac64f358489ab5a0fc31064a008ebbcc6044d310c3fa044343bb74464f1"
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
