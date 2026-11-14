import Foundation
import LLMCheck

/// The PackageGeneratorPlugin repository, rooted where `.llm-check.yaml` is. Its file list and every parsed file are
/// shared by all suites, which Swift Testing runs in parallel.
func repository() throws -> Codebase { try Codebase() }

/// Where the test target and the benchmarks compile the plugin's pure files from. A `.plugin` target cannot be
/// imported.
let sharedSourceFolders = ["Tests/PackageGeneratorTests/Shared", "Benchmarks/Benchmarks/GeneratorBenchmarks/Shared"]

/// A Swift file in one of `sharedSourceFolders`, and where it points when it is a symbolic link.
struct SharedSource: Sendable {
    /// From the repository root, like `Tests/PackageGeneratorTests/Shared/ParsedPackage.swift`.
    let relativePath: String
    /// The link's destination from the repository root, like `Plugins/PackageGenerator/ParsedPackage.swift`, or `nil`
    /// when the file is a regular file.
    let destination: String?

    /// The Swift files in `sharedSourceFolders` of `codebase`, read from the file system: `Codebase` excludes the
    /// folders so that the rules read each file once, under its real path.
    static func all(in codebase: Codebase) throws -> [SharedSource] {
        let fileManager = FileManager.default
        let root = codebase.root.standardizedFileURL.path + "/"
        return try sharedSourceFolders.flatMap { relativeFolder in
            let folder = codebase.root.appendingPathComponent(relativeFolder)
            return try fileManager.contentsOfDirectory(atPath: folder.path).sorted()
                .filter { $0.hasSuffix(".swift") }
                .map { name in
                    let link = folder.appendingPathComponent(name)
                    let target = try? fileManager.destinationOfSymbolicLink(atPath: link.path)
                    let destination = target.map {
                        URL(fileURLWithPath: $0, relativeTo: folder).standardizedFileURL.path
                            .replacingOccurrences(of: root, with: "")
                    }
                    return SharedSource(relativePath: "\(relativeFolder)/\(name)", destination: destination)
                }
        }
    }
}

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
