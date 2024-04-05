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
<<<<<<< Updated upstream
      url: "https://github.com/mackoj/PackageGeneratorCLI/releases/download/0.4.0/package-generator-cli-arm64-apple-macosx.artifactbundle.zip",
      checksum: "8087731a742d7b834cdf33eb07ce11fcc054fb90c3b4f919b6080d54878d0dd5"
=======
      url: "https://github.com/mackoj/PackageGeneratorCLI/releases/download/0.4.2/package-generator-cli-arm64-apple-macosx.artifactbundle.zip",
      checksum: "ddf169bfe8b9260d40069671b8e7282b2655679d2b404d080af2a3935025fb7f"
>>>>>>> Stashed changes
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
