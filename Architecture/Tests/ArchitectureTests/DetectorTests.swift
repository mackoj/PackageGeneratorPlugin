import LLMCheck
import Testing

/// Each detector on snippets: it finds what its rule forbids and nothing its rule allows.
@Suite struct DetectorTests {
    func scope(_ source: String, at path: String = "Plugins/PackageGenerator/File.swift") -> Scope {
        Scope(files: [SourceFile(path: path, source: source)])
    }

    @Test func coreImportsAreFound() {
        let plugin = Scope(files: [
            SourceFile(path: "Plugins/PackageGenerator/Core.swift", source: "import Foundation\nimport PackagePlugin"),
            SourceFile(path: "Plugins/PackageGenerator/Shell.swift", source: "import PackagePlugin"),
        ])
        let found = Detect.coreImports(in: plugin, files: ["Plugins/PackageGenerator/Core.swift"])
        #expect(found.map(\.location.relativePath) == ["Plugins/PackageGenerator/Core.swift"])
        #expect(found.map(\.node.moduleName) == ["PackagePlugin"])
    }

    @Test func coreImportsWithNoLinkedFilesPass() {
        #expect(Detect.coreImports(in: scope("import PackagePlugin"), files: []).isEmpty)
    }

    @Test func printCallsAreFound() {
        let found = Detect.printCalls(
            in: scope(
                """
                print("Resolved")
                Diagnostics.emit(.remark, "print(\\"fine in a string\\")")
                logger.print("not the global print")
                """))
        #expect(found.map(\.location.line) == [1])
    }

    @Test func displayNameReadsAreFound() {
        let found = Detect.displayNameReads(
            in: scope(
                """
                // `displayName` is the package's self-declared name.
                let identity = dependency.package.id
                let name = dependency.package.displayName
                """))
        #expect(found.map(\.location.line) == [3])
    }

    @Test func deprecatedPathAPIsAreFound() {
        let found = Detect.deprecatedPathAPIs(
            in: scope(
                """
                let a = context.package.directory
                let b = context.pluginWorkDirectory
                let c = try context.tool(named: "cli").path
                let d = context.package.directoryURL
                let e = context.pluginWorkDirectoryURL
                let f = outputURL.path
                let g = try context.tool(named: "cli").url
                """))
        #expect(found.map(\.location.line).sorted() == [1, 2, 3])
    }

    @Test func earlySDKFilteringIsFound() {
        let found = Detect.earlySDKFiltering(
            in: scope(
                """
                func filterImports(rawImports: [String]) -> [String] {
                  rawImports.filter { !appleDefaultSDKs.contains($0) && !appleDefaultSDKSet.contains($0) }
                }
                func renderSingleTarget() {
                  let skipped = appleDefaultSDKSet.contains(dep)
                }
                """))
        #expect(found.map(\.location.line) == [2, 2])
    }
}
