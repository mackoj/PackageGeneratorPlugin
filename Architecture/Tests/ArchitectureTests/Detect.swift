import LLMCheck
import SwiftSyntax

/// The detectors, separate from the codebase so `DetectorTests` can run them on snippets.
enum Detect {
    /// Shared test sources that are regular files, or links that do not point into `Plugins/PackageGenerator`.
    static func unlinkedTestSources(_ sources: [SharedSource]) -> [Violation] {
        sources.filter { source in
            guard let destination = source.destination else { return true }
            return !destination.hasPrefix("Plugins/PackageGenerator/")
        }
        .map { source in
            Violation(
                location: Location(
                    filePath: source.relativePath, relativePath: source.relativePath, line: 1, column: 1),
                snippet: source.destination.map { "\(source.relativePath) -> \($0)" }
                    ?? "\(source.relativePath) is a regular file")
        }
    }

    /// Imports other than Foundation in `files`, the plugin files that the tests link.
    static func coreImports(in plugin: Scope, files: [String]) -> [Match<ImportDeclSyntax>] {
        guard !files.isEmpty else { return [] }
        return plugin.in(files).imports.filter { $0.node.moduleName != "Foundation" }
    }

    /// Calls to the global `print`.
    static func printCalls(in scope: Scope) -> [Match<FunctionCallExprSyntax>] {
        scope.calls(named: "print").filter { $0.node.calledExpression.is(DeclReferenceExprSyntax.self) }
    }

    /// `x.displayName` in code. Comments that explain why it is avoided pass.
    static func displayNameReads(in scope: Scope) -> [Match<MemberAccessExprSyntax>] {
        memberAccesses(named: ["displayName"], in: scope)
    }

    /// The deprecated `Path` accessors: `.directory`, `.pluginWorkDirectory`, and `.path` on a `tool(named:)` result.
    static func deprecatedPathAPIs(in scope: Scope) -> [Match<MemberAccessExprSyntax>] {
        let directories = memberAccesses(named: ["directory", "pluginWorkDirectory"], in: scope)
        let toolPaths = memberAccesses(named: ["path"], in: scope.containing("tool(named:")).filter { match in
            guard let base = match.node.base else { return false }
            return base.trimmedDescription.contains("tool(named:")
        }
        return directories + toolPaths
    }

    /// `appleDefaultSDKs` referenced inside a function named `filterImports`.
    static func earlySDKFiltering(in scope: Scope) -> [Match<Syntax>] {
        scope.references(to: "appleDefaultSDKs").filter { match in
            sequence(first: match.node, next: \.parent).contains {
                $0.as(FunctionDeclSyntax.self)?.name.text == "filterImports"
            }
        }
    }

    /// `import XCTest`.
    static func xcTestImports(in scope: Scope) -> [Match<ImportDeclSyntax>] {
        scope.imports(of: "XCTest")
    }

    /// The `.disabled(…)` trait, wherever a test or suite takes it.
    static func disabledTests(in scope: Scope) -> [Match<FunctionCallExprSyntax>] {
        scope.calls(named: "disabled").filter { call in
            call.node.receiver == nil && call.node.calledExpression.is(MemberAccessExprSyntax.self)
        }
    }

    private static func memberAccesses(named names: Set<String>, in scope: Scope) -> [Match<MemberAccessExprSyntax>] {
        scope.containing(Array(names)).nodes(of: MemberAccessExprSyntax.self) {
            $0.node.base != nil && names.contains($0.node.declName.baseName.text)
        }
    }
}
