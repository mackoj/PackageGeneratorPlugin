import LLMCheck
import Testing

/// The rules, run on the repository. A failure prints the rule, why it exists and how to fix it.
@Suite("Architecture rules")
struct ArchitectureRules {
    static func plugin() throws -> Scope { try repository().productionCode.in("Plugins/PackageGenerator") }
    static func tests() throws -> Scope { try repository().testCode.in("Tests") }

    /// The Swift files in `sharedSourceFolders`, links included (`symbolicLinks: follow`).
    static func shared() throws -> [SourceFile] { try repository().allCode.in(sharedSourceFolders).files }

    @Test func testSourcesLinkThePluginFiles() throws {
        let sources = try Self.shared()
        #expect(sources.count >= 10)
        // `SourceFile` is not a `Finding` in swift-llm-check 0.5.0, so each offending file becomes a `Violation`.
        let unlinked = sources.filter { $0.symbolicLinkDestination?.hasPrefix("Plugins/PackageGenerator/") != true }
        expectNone(
            unlinked.map { file in
                Violation(
                    location: Location(filePath: file.path, relativePath: file.relativePath, line: 1, column: 1),
                    snippet: file.symbolicLinkDestination.map { "\(file.relativePath) -> \($0)" }
                        ?? "\(file.relativePath) is a regular file")
            },
            rule: .testSourcesLinkThePluginFiles)
    }

    @Test func coreFilesImportOnlyFoundation() throws {
        let linked = Array(Set(try Self.shared().compactMap(\.symbolicLinkDestination))).sorted()
        #expect(linked.count >= 3)
        expectNone(Detect.coreImports(in: try Self.plugin(), files: linked), rule: .coreFilesImportOnlyFoundation)
    }

    @Test func pluginReportsThroughDiagnostics() throws {
        let plugin = try Self.plugin()
        #expect(plugin.containing("Diagnostics.emit").relativePaths.count > 3)
        expectNone(Detect.printCalls(in: plugin), rule: .pluginReportsThroughDiagnostics)
    }

    @Test func externalProductsUsePackageIdentity() throws {
        expectNone(Detect.displayNameReads(in: try Self.plugin()), rule: .externalProductsUsePackageIdentity)
    }

    @Test func appleSDKFilteringIsDeferred() throws {
        let plugin = try Self.plugin()
        #expect(plugin.containing("func filterImports").relativePaths.count == 1)
        expectNone(Detect.earlySDKFiltering(in: plugin), rule: .appleSDKFilteringIsDeferred)
    }

    @Test func pluginUsesURLAPIs() throws {
        let plugin = try Self.plugin()
        #expect(plugin.containing("directoryURL").relativePaths.count > 3)
        expectNone(Detect.deprecatedPathAPIs(in: plugin), rule: .pluginUsesURLAPIs)
    }

    @Test func testsUseSwiftTesting() throws {
        let tests = try Self.tests()
        #expect(tests.containing("import Testing").relativePaths.count >= 1)
        expectNone(tests.xcTestImports, rule: .testsUseSwiftTesting)
    }

    @Test func testsAreNotDisabled() throws {
        expectNone(try Self.tests().disabledTests, rule: .testsAreNotDisabled)
    }
}

/// Keeps `docs/architecture-rules.md` in step with the rules. Regenerate with
/// `LLM_CHECK_RECORD=1 swift test --package-path Architecture`.
@Test func rulesDocumentIsUpToDate() throws {
    let catalog = RuleCatalog(allRules)
    #expect(catalog.duplicateIDs.isEmpty)
    try expectFile(
        "docs/architecture-rules.md", in: repository(),
        matches: catalog.markdown(
            title: "Architecture rules",
            introduction: """
                The mechanical part of `CODING_STANDARDS.md`, enforced by the `Architecture/` package with \
                [swift-llm-check](https://github.com/mackoj/swift-llm-check): \
                `swift test --package-path Architecture` (macOS). Generated from its rules; do not edit by hand.
                """))
}
