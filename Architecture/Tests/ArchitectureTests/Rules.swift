import LLMCheck

extension Rule {
    static let testSourcesLinkThePluginFiles = Rule(
        id: "test-sources-link-the-plugin-files",
        title: "Every Swift file in the tests' and benchmarks' `Shared` folders is a symbolic link into `Plugins/PackageGenerator`.",
        category: .structure,
        rationale: """
            A `.plugin` target cannot be imported, so the test target and the benchmarks compile the plugin's own \
            files through symbolic links in `Tests/PackageGeneratorTests/Shared` and \
            `Benchmarks/Benchmarks/GeneratorBenchmarks/Shared` (CODING_STANDARDS.md, "The tests compile the real \
            files"). A copy, or a link to anywhere else, would test and measure code the plugin no longer runs.
            """,
        howToFix: """
            Replace the file with a relative link: \
            `ln -s ../../../Plugins/PackageGenerator/Name.swift Tests/PackageGeneratorTests/Shared/Name.swift`.
            """,
        badExample: "cp Plugins/PackageGenerator/ParsedPackage.swift Tests/PackageGeneratorTests/Shared/",
        goodExample: "Shared/ParsedPackage.swift -> ../../../Plugins/PackageGenerator/ParsedPackage.swift"
    )

    static let coreFilesImportOnlyFoundation = Rule(
        id: "core-files-import-only-foundation",
        title: "A plugin file the tests link imports only Foundation.",
        category: .structure,
        rationale: """
            The generator's pure core (CODING_STANDARDS.md, "Pure core, thin shell") is compiled by the plugin, the \
            test target and the benchmarks; the last two cannot import `PackagePlugin`. Yams, the package's only dependency, belongs to \
            `yaml-converter`, not the plugin.
            """,
        howToFix: """
            Keep `PackagePlugin` in the shell: take the value the core needs as a parameter, and report warnings \
            through a closure the caller passes (it calls `Diagnostics.emit`).
            """,
        badExample: """
            // Plugins/PackageGenerator/ProductGeneration.swift
            import PackagePlugin
            Diagnostics.emit(.warning, "Dropped unresolved import '\\(dep)'")
            """,
        goodExample: """
            // Plugins/PackageGenerator/ProductGeneration.swift
            import Foundation
            func render(_ target: ParsedPackage, warn: (String) -> Void) -> String
            """
    )

    static let pluginReportsThroughDiagnostics = Rule(
        id: "plugin-reports-through-diagnostics",
        title: "The plugin reports through `Diagnostics.emit`, never `print`.",
        category: .structure,
        rationale: """
            A command plugin's standard output is not shown in Xcode's issue navigator, and in a terminal it mixes \
            with SwiftPM's own output. `Diagnostics` gives every message a severity users can filter \
            (CODING_STANDARDS.md, "Diagnostics, not print").
            """,
        howToFix: "Call `Diagnostics.emit(.remark, …)`, guarded by `config.verbosePlugin` when it is verbose-only.",
        badExample: "print(\"Resolved \\(resolvedPaths.count) targets\")",
        goodExample: """
            if config.verbosePlugin { Diagnostics.emit(.remark, "Resolved \\(resolvedPaths.count) targets") }
            """
    )

    static let externalProductsUsePackageIdentity = Rule(
        id: "external-products-use-package-identity",
        title: "The plugin never reads a package's `displayName`.",
        category: .output,
        rationale: """
            `.product(name:package:)` needs the package identity SwiftPM derives from the URL, \
            `dependency.package.id`. `displayName` is the name a package declares for itself and can differ \
            (`VitaminPlay` for `vitamin-play-apple-releases`), which produces a `Package.swift` that does not resolve \
            (CODING_STANDARDS.md, "External products use the package identity").
            """,
        howToFix: "Use `dependency.package.id`.",
        badExample: "let packageIdentity = dependency.package.displayName",
        goodExample: "let packageIdentity = dependency.package.id"
    )

    static let appleSDKFilteringIsDeferred = Rule(
        id: "apple-sdk-filtering-is-deferred",
        title: "`filterImports` does not consult `appleDefaultSDKs` or `appleDefaultSDKSet`.",
        category: .output,
        rationale: """
            Imports are matched to external products and local targets before Apple SDKs are skipped. Filtering SDK \
            names out earlier silently drops a package product that shares a name with an SDK, like `Charts` \
            (CODING_STANDARDS.md, "Apple SDK filtering happens at render time").
            """,
        howToFix: """
            Leave the import in `filterImports`' result. `renderSingleTarget` skips it once it has found no external \
            product and no local target of that name.
            """,
        badExample: """
            func filterImports(rawImports: [String], …) -> [String] {
              rawImports.filter { !appleDefaultSDKs.contains($0) }
            """,
        goodExample: """
            } else if appleDefaultSDKSet.contains(dep) {
              // Known Apple SDK: skip silently, after externalDeps and local targets were checked.
            """
    )

    static let pluginUsesURLAPIs = Rule(
        id: "plugin-uses-url-apis",
        title: "The plugin uses the URL-based `PackagePlugin` APIs, not the deprecated `Path` ones.",
        category: .pluginAPI,
        rationale: """
            `context.package.directory`, `context.pluginWorkDirectory` and `tool.path` return the deprecated \
            `PackagePlugin.Path` and warn on every build; the `URL` variants work with Foundation directly \
            (CODING_STANDARDS.md, "URL-based PackagePlugin APIs").
            """,
        howToFix: "Use `directoryURL`, `pluginWorkDirectoryURL` and `url`, then `appendingPathComponent`.",
        badExample: "let packageDir = context.package.directory",
        goodExample: "let packageDir = context.package.directoryURL"
    )

    static let testsUseSwiftTesting = Rule(
        id: "tests-use-swift-testing",
        title: "Tests use Swift Testing, never XCTest.",
        category: .testing,
        rationale: """
            The suite is Swift Testing only (CODING_STANDARDS.md, "Swift Testing only"): `@Test`, `#expect` and \
            `#require` give one failure message style, parameterised tests and parallel, randomly ordered runs.
            """,
        howToFix: "Write an `@Suite` of `@Test` functions with `#expect` and `#require`, and `import Testing`.",
        badExample: """
            import XCTest
            final class ProductTests: XCTestCase { func testName() { XCTAssertEqual(…) } }
            """,
        goodExample: """
            import Testing
            @Suite struct ProductTests { @Test func name() { #expect(…) } }
            """
    )

    static let testsAreNotDisabled = Rule(
        id: "tests-are-not-disabled",
        title: "No test or suite is `.disabled`.",
        category: .testing,
        rationale: """
            A disabled test still reads as coverage while checking nothing. A failing behaviour is either fixed, or \
            asserted as a known issue that says why.
            """,
        howToFix: "Fix the code or the test. If the bug must wait, wrap the failing part in `withKnownIssue(\"…\")`.",
        badExample: "@Test(.disabled(\"flaky\")) func rendersProducts() {",
        goodExample: "@Test func rendersProducts() {"
    )
}

/// Every rule, in the order `docs/architecture-rules.md` lists them.
let allRules: [Rule] = [
    .testSourcesLinkThePluginFiles, .coreFilesImportOnlyFoundation, .pluginReportsThroughDiagnostics,
    .externalProductsUsePackageIdentity, .appleSDKFilteringIsDeferred, .pluginUsesURLAPIs,
    .testsUseSwiftTesting, .testsAreNotDisabled,
]
