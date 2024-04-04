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
      url: "https://github.com/mackoj/PackageGeneratorCLI/releases/download/0.4.1/package-generator-cli-arm64-apple-macosx.artifactbundle.zip",
      checksum: "8db033df8c4e6dbb56c96b0988c8b609d924b6f8008db711fcc61c67846c0fe5"
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
  ]
)
