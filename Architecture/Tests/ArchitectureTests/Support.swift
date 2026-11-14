import LLMCheck

/// The PackageGeneratorPlugin repository, rooted where `.llm-check.yaml` is. Its file list and every parsed file are
/// shared by all suites, which Swift Testing runs in parallel.
func repository() throws -> Codebase { try Codebase() }

/// Where the test target and the benchmarks compile the plugin's pure files from. A `.plugin` target cannot be
/// imported.
let sharedSourceFolders = ["Tests/PackageGeneratorTests/Shared", "Benchmarks/Benchmarks/GeneratorBenchmarks/Shared"]

extension RuleCategory {
    static let structure = RuleCategory(
        "structure",
        description: "The pure core and the plugin shell. Read before you add an `import` or a file to `Plugins`."
    )
    static let output = RuleCategory(
        "output",
        description: "What ends up in the generated `Package.swift`. Read before you change dependency resolution."
    )
    static let pluginAPI = RuleCategory(
        "plugin-api",
        description: "How the plugin talks to SwiftPM. Read before you use a `PackagePlugin` API."
    )
    static let testing = RuleCategory(
        "testing",
        description: "Swift Testing, and no silenced tests. Read before you add or skip a test."
    )
}
