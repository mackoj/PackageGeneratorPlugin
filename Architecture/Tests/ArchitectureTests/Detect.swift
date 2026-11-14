import LLMCheck
import SwiftSyntax

/// The detectors, separate from the codebase so `DetectorTests` can run them on snippets.
enum Detect {
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

    /// `appleDefaultSDKs` or `appleDefaultSDKSet` referenced inside a function named `filterImports`.
    static func earlySDKFiltering(in scope: Scope) -> [Match<Syntax>] {
        scope.references(to: "appleDefaultSDKs", "appleDefaultSDKSet").filter { match in
            sequence(first: match.node, next: \.parent).contains {
                $0.as(FunctionDeclSyntax.self)?.name.text == "filterImports"
            }
        }
    }

    private static func memberAccesses(named names: Set<String>, in scope: Scope) -> [Match<MemberAccessExprSyntax>] {
        scope.containing(Array(names)).nodes(of: MemberAccessExprSyntax.self) {
            $0.node.base != nil && names.contains($0.node.declName.baseName.text)
        }
    }
}
