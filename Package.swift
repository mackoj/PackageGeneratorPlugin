// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "PackageGeneratorPlugin",
  platforms: [
    .macOS(.v12),
  ],
  products: [
    .plugin(name: "PackageGenerator", targets: ["Package Generator"]),
    .library(name: "PackageGeneratorLib", targets: ["PackageGeneratorLib"]),
  ],
  targets: [
    .binaryTarget(
      name: "package-generator-cli",
      url: "https://github.com/mackoj/PackageGeneratorCLI/releases/download/0.3.0/package-generator-cli.artifactbundle.zip",
      checksum: "a411312bd07e5234578fd460c215ef63a1799f49a7aa39ac81f8b77e708ae0de"
    ),
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
        .target(name: "package-generator-cli")
      ],
      path: "Plugins/PackageGenerator"
    ),
    .target(
      name: "PackageGeneratorLib"
    ),
    .testTarget(
      name: "PackageGeneratorTests",
      dependencies: [
        "PackageGeneratorLib"
      ]
    )
  ]
)
