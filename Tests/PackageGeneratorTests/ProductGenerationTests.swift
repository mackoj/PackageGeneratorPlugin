import Foundation
import Testing

// The production sources under `Shared/` are symlinks to the files in
// `Plugins/PackageGenerator/`. A `.plugin` target cannot be imported, so the test
// target compiles the same files instead of a copy of them.

// MARK: - Helpers

private func lib(
  _ name: String,
  path: String? = nil,
  isTest: Bool = false,
  isMacro: Bool = false,
  libraryType: LibraryType? = nil,
  productName: String? = nil
) -> ParsedPackage {
  ParsedPackage(
    name: name,
    isTest: isTest,
    isMacro: isMacro,
    dependencies: [],
    path: path ?? "Sources/\(name)",
    fullPath: "/tmp/\(name)",
    libraryType: libraryType,
    productName: productName
  )
}

/// The `.library(...)` lines of a generated products section, without the surrounding
/// `package.products.append(contentsOf: [` scaffolding.
private func productLines(
  _ packages: [ParsedPackage],
  config: ConfigurationV2 = ConfigurationV2()
) -> [String] {
  generateProductsSection(parsedPackages: packages, config: config)
    .split(separator: "\n")
    .map(String.init)
    .filter { $0.contains(".library(") }
    .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: ",")) }
}

// MARK: - Behaviour that existing configurations rely on

@Suite("Product generation — existing behaviour")
struct ProductGenerationRegressionTests {

  @Test("A target with no overrides produces a product of the same name")
  func defaultProductMatchesTargetName() {
    #expect(productLines([lib("Foo")]) == [#".library(name: "Foo", targets: ["Foo"])"#])
  }

  @Test("Products are sorted by target name")
  func productsAreSorted() {
    let lines = productLines([lib("Charlie"), lib("Alpha"), lib("Bravo")])
    #expect(lines == [
      #".library(name: "Alpha", targets: ["Alpha"])"#,
      #".library(name: "Bravo", targets: ["Bravo"])"#,
      #".library(name: "Charlie", targets: ["Charlie"])"#,
    ])
  }

  @Test("Test and macro targets produce no product")
  func testAndMacroTargetsAreSkipped() {
    let packages = [lib("Foo"), lib("FooTests", isTest: true), lib("FooMacros", isMacro: true)]
    #expect(productLines(packages) == [#".library(name: "Foo", targets: ["Foo"])"#])
  }

  @Test("No library targets yields an empty section")
  func emptySection() {
    let out = generateProductsSection(parsedPackages: [], config: ConfigurationV2())
    #expect(out == "// MARK: - Targets\npackage.products.append(contentsOf: [\n])\n")
  }

  @Test("Indentation follows the configured `spaces`")
  func indentationFollowsSpaces() {
    let out = generateProductsSection(
      parsedPackages: [lib("Foo")],
      config: ConfigurationV2(spaces: 4)
    )
    #expect(out.contains(#"\#n    .library(name: "Foo""#))
  }

  @Test("Only the last product line omits the trailing comma")
  func trailingCommas() {
    let out = generateProductsSection(
      parsedPackages: [lib("Alpha"), lib("Bravo")],
      config: ConfigurationV2()
    )
    #expect(out.contains(#".library(name: "Alpha", targets: ["Alpha"]),"#))
    #expect(out.contains(#".library(name: "Bravo", targets: ["Bravo"])\#n])"#))
  }

  @Test("An automatic global libraryType omits `type:`")
  func globalLibraryTypeAutomatic() {
    let lines = productLines([lib("Foo")], config: ConfigurationV2(libraryType: .automatic))
    #expect(lines == [#".library(name: "Foo", targets: ["Foo"])"#])
  }

  @Test("A dynamic global libraryType applies to every product")
  func globalLibraryTypeDynamic() {
    let lines = productLines([lib("Foo")], config: ConfigurationV2(libraryType: .dynamic))
    #expect(lines == [#".library(name: "Foo", type: .dynamic, targets: ["Foo"])"#])
  }

  @Test("A static global libraryType applies to every product")
  func globalLibraryTypeStatic() {
    let lines = productLines([lib("Foo")], config: ConfigurationV2(libraryType: .static))
    #expect(lines == [#".library(name: "Foo", type: .static, targets: ["Foo"])"#])
  }

  @Test("A per-target libraryType overrides the global one")
  func perTargetLibraryTypeWins() {
    let lines = productLines(
      [lib("Foo", libraryType: .static)],
      config: ConfigurationV2(libraryType: .dynamic)
    )
    #expect(lines == [#".library(name: "Foo", type: .static, targets: ["Foo"])"#])
  }
}

// MARK: - Renaming a product independently of its target

@Suite("Product generation — product naming")
struct ProductNamingTests {

  @Test("`productName` renames the product but not the target it points at")
  func productNameRenamesOnlyTheProduct() {
    let lines = productLines([lib("FooCore", productName: "Foo")])
    #expect(lines == [#".library(name: "Foo", targets: ["FooCore"])"#])
  }

  @Test("`productName` composes with a dynamic libraryType")
  func productNameWithDynamic() {
    let lines = productLines([lib("FooCore", libraryType: .dynamic, productName: "Foo")])
    #expect(lines == [#".library(name: "Foo", type: .dynamic, targets: ["FooCore"])"#])
  }

  @Test("`mappers.targets` renames the product and keeps the real target name")
  func mappersTargetsRenamesOnlyTheProduct() {
    let config = ConfigurationV2(
      mappers: .init(targets: ["Sources/App/Helpers/Foundation": "FoundationHelpers"])
    )
    let lines = productLines([lib("Foundation", path: "Sources/App/Helpers/Foundation")], config: config)
    #expect(lines == [#".library(name: "FoundationHelpers", targets: ["Foundation"])"#])
  }

  @Test("`productName` takes precedence over a `mappers.targets` entry")
  func productNameBeatsMapper() {
    let config = ConfigurationV2(mappers: .init(targets: ["Sources/FooCore": "FromMapper"]))
    let lines = productLines([lib("FooCore", productName: "FromTargetSpec")], config: config)
    #expect(lines == [#".library(name: "FromTargetSpec", targets: ["FooCore"])"#])
  }

  @Test("A mapper entry for a different path leaves the product untouched")
  func unrelatedMapperEntryIsIgnored() {
    let config = ConfigurationV2(mappers: .init(targets: ["Sources/Other": "Renamed"]))
    #expect(productLines([lib("Foo")], config: config) == [#".library(name: "Foo", targets: ["Foo"])"#])
  }

  @Test("Sorting uses the target name, not the product name")
  func sortingUsesTargetName() {
    // Product names are deliberately in the opposite order to the target names.
    let lines = productLines([
      lib("Alpha", productName: "Zulu"),
      lib("Bravo", productName: "Yankee"),
    ])
    #expect(lines == [
      #".library(name: "Zulu", targets: ["Alpha"])"#,
      #".library(name: "Yankee", targets: ["Bravo"])"#,
    ])
  }
}

// MARK: - Configuration decoding

@Suite("TargetSpec decoding")
struct TargetSpecDecodingTests {

  private func decode(_ json: String) throws -> ConfigurationV2 {
    try JSONDecoder().decode(ConfigurationV2.self, from: Data(json.utf8))
  }

  @Test("A configuration written before `productName` existed still decodes")
  func backwardCompatibleDecoding() throws {
    let config = try decode(#"""
    {
      "packageDirectoryTargets": [
        { "path": "Sources", "targets": [ { "name": "Foo" } ] }
      ]
    }
    """#)
    let spec = try #require(config.packageDirectoryTargets.first?.targets.first)
    #expect(spec.name == "Foo")
    #expect(spec.productName == nil)
    #expect(spec.libraryType == nil)
  }

  @Test("`productName` and `libraryType` decode from the target spec")
  func decodesProductName() throws {
    let config = try decode(#"""
    {
      "packageDirectoryTargets": [
        {
          "path": "Sources",
          "targets": [
            { "name": "FooCore", "libraryType": "dynamic", "productName": "Foo" }
          ]
        }
      ]
    }
    """#)
    let spec = try #require(config.packageDirectoryTargets.first?.targets.first)
    #expect(spec.productName == "Foo")
    #expect(spec.libraryType == .dynamic)
  }

  @Test("`productName` survives the legacy `targetsParameters` migration")
  func survivesLegacyMigration() throws {
    // The legacy path rebuilds every TargetSpec; a dropped field there would be
    // silently lost for anyone still using `targetsParameters`.
    let config = try decode(#"""
    {
      "packageDirectoryTargets": [
        {
          "path": "Sources",
          "targets": [
            { "name": "FooCore", "libraryType": "dynamic", "productName": "Foo" }
          ]
        }
      ],
      "targetsParameters": { "FooCore": ["resources: [.process(\"Assets\")]"] }
    }
    """#)
    let spec = try #require(config.packageDirectoryTargets.first?.targets.first)
    #expect(spec.productName == "Foo")
    #expect(spec.libraryType == .dynamic)
    #expect(spec.parameters == ["resources: [.process(\"Assets\")]"])
  }
}
