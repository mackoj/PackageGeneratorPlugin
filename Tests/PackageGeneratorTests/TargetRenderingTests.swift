import Foundation
import Testing

// Rendering of the targets section and of the whole generated file. The sources are the plugin's own files, linked
// under `Shared/`.

private func target(
  _ name: String,
  path: String? = nil,
  isTest: Bool = false,
  isMacro: Bool = false,
  dependencies: [String] = [],
  exclude: [String] = [],
  parameters: [String]? = nil,
  additionalDependencies: [String]? = nil
) -> ParsedPackage {
  ParsedPackage(
    name: name,
    isTest: isTest,
    isMacro: isMacro,
    dependencies: dependencies,
    path: path ?? "Sources/\(name)",
    fullPath: "/tmp/\(name)",
    exclude: exclude,
    parameters: parameters,
    additionalDependencies: additionalDependencies
  )
}

private func render(
  _ targets: [ParsedPackage],
  config: ConfigurationV2 = ConfigurationV2(),
  externalDeps: [String: String] = [:]
) -> (text: String, warnings: [String]) {
  var warnings: [String] = []
  let text = renderPackageContent(
    targets,
    config: config,
    externalDeps: externalDeps,
    leafWeights: computeDependencyWeight(targets),
    warn: { warnings.append($0) }
  )
  return (text, warnings)
}

@Suite("Target rendering")
struct TargetRenderingTests {

  @Test("A whole file renders byte for byte")
  func wholeFile() {
    // Given
    let targets = [
      target("Feature", path: "Sources/Features/Feature", dependencies: ["Charts", "Core", "SwiftUI"],
             exclude: ["b", "a"], parameters: ["  resources: [.process(\"R\")]  ", ""],
             additionalDependencies: [#""Extra""#]),
      target("Core", path: "Sources/Core/Core"),
      target("CoreTests", path: "Tests/Core/CoreTests", isTest: true, dependencies: ["Core", "Nimble"]),
      target("Macros", path: "Sources/Core/Macros", isMacro: true),
    ]
    let externalDeps = ["Charts": #".product(name: "Charts", package: "swift-charts")"#]

    // When
    let (text, warnings) = render(targets, config: ConfigurationV2(pragmaMark: true), externalDeps: externalDeps)

    // Then
    #expect(warnings == ["Dropped unresolved import 'Nimble'. If it's a system framework, ignore this."])
    #expect(text == """
      // MARK: - Generated 3 packages

      // MARK: - Targets
      package.products.append(contentsOf: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Feature", targets: ["Feature"])
      ])

      // MARK: - Products
      package.targets.append(contentsOf: [
      // MARK: -
      // MARK: Core
        .target(
          name: "Core",
          path: "Sources/Core/Core"
        ),
        .macro(
          name: "Macros",
          path: "Sources/Core/Macros"
        ),
        .testTarget(
          name: "CoreTests",
          dependencies: [
            "Core"
          ],
          path: "Tests/Core/CoreTests"
        ),
      // MARK: -
      // MARK: Features
        .target(
          name: "Feature",
          dependencies: [
            "Core",
            .product(name: "Charts", package: "swift-charts"),
            "Extra"
          ],
          path: "Sources/Features/Feature",
          exclude: [
            "a",
            "b"
          ],
          resources: [.process("R")]
        )
      ])

      """)
  }

  @Test("An external product wins over an Apple SDK of the same name")
  func externalProductBeatsSDK() {
    let (text, warnings) = render(
      [target("App", dependencies: ["Charts"])],
      externalDeps: ["Charts": #".product(name: "Charts", package: "swift-charts")"#])
    #expect(text.contains(#".product(name: "Charts", package: "swift-charts")"#))
    #expect(warnings.isEmpty)
  }

  @Test("Apple SDKs are skipped silently and unknown imports are dropped with a warning")
  func sdkAndUnknownImports() {
    let (text, warnings) = render([target("App", dependencies: ["SwiftUI", "Unknown"])])
    #expect(!text.contains("dependencies:"))
    #expect(warnings == ["Dropped unresolved import 'Unknown'. If it's a system framework, ignore this."])
  }

  @Test("Leaf info marks the target with the most local dependencies")
  func leafInfo() {
    let (text, _) = render(
      [target("A"), target("B", dependencies: ["A"]), target("C", dependencies: ["A", "B", "SwiftUI"])],
      config: ConfigurationV2(leafInfo: true))
    #expect(text.contains(#"name: "A",// [0|0]"#))
    #expect(text.contains(#"name: "B",// [1|1]"#))
    #expect(text.contains(#"name: "C",// [3|2|🚛]"#))
  }

  @Test("Indentation follows `spaces` and the package count mark can be omitted")
  func spacesAndCountMark() {
    let (text, _) = render([target("A")], config: ConfigurationV2(includePackageCountMark: false, spaces: 4))
    #expect(text.hasPrefix("// MARK: - Targets\n"))
    #expect(text.contains("    .target(\n        name: \"A\","))
  }

  @Test("Pragma mark group names come from the folder after Sources or Tests")
  func groupNames() {
    #expect(pragmaMarkGroupName("Sources/Core/Core", fallback: "x") == "Core")
    #expect(pragmaMarkGroupName("Packages/App/Sources/Feature/Feature", fallback: "x") == "Feature")
    #expect(pragmaMarkGroupName("Packages/App/Tests/FeatureTests", fallback: "x") == "FeatureTests")
    #expect(pragmaMarkGroupName("Modules/Thing", fallback: "x") == "Modules")
    #expect(pragmaMarkGroupName("", fallback: "x") == "x")
  }

  @Test("filterImports drops self-imports and exclusions, keeps SDKs, and sorts")
  func filtering() {
    var remarks: [String] = []
    let filtered = filterImports(
      rawImports: ["Zed", "App", "SwiftUI", "Hidden", "Core"],
      targetName: "App",
      exclusions: .init(imports: ["Hidden"]),
      remark: { remarks.append($0) })
    #expect(filtered == ["Core", "SwiftUI", "Zed"])
    #expect(remarks == ["Skipped excluded import: Hidden"])
  }
}
