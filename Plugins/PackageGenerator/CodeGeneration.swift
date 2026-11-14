import Foundation
import PackagePlugin

// MARK: - Phase 4: Code Generation

/// Injects the header file content at the top of the output.
func injectHeader(
  headerFileURL: String?,
  _ context: PackagePlugin.PluginContext
) -> String {
  guard let headerPath = headerFileURL else { return "" }
  let headerFileURL = context.package.directoryURL.appendingPathComponent(headerPath)
  do {
    let content = try String(contentsOf: headerFileURL, encoding: .utf8)
    return content.hasSuffix("\n") ? content : content + "\n"
  } catch {
    Diagnostics.emit(.warning, "Failed to read header file at \(headerPath): \(error)")
    return ""
  }
}

/// Writes the complete generated output to Package.swift (or Package_generated.swift for dry runs).
func writeOutput(
  _ headerContent: String,
  _ parsedPackages: [ParsedPackage],
  config: ConfigurationV2,
  externalDeps: [String: String],
  context: PackagePlugin.PluginContext,
  leafWeights: [String: (total: Int, local: Int, isHeaviest: Bool)],
  fallbackCount: Int = 0
) {
  let packageDir = context.package.directoryURL
  let outputName = config.dryRun ? "Package_generated.swift" : "Package.swift"
  let outputFile = packageDir.appendingPathComponent(outputName)

  let nonTestCount = parsedPackages.filter { !$0.isTest }.count
  let finalContent = headerContent + renderPackageContent(
    parsedPackages,
    config: config,
    externalDeps: externalDeps,
    leafWeights: leafWeights,
    warn: { Diagnostics.emit(.warning, $0) }
  )

  do {
    try finalContent.write(to: outputFile, atomically: true, encoding: .utf8)
    if config.verbosePlugin {
    } else {
      var summary = "Generated \(outputName) — \(nonTestCount) packages"
      if fallbackCount > 0 { summary += ", \(fallbackCount) test-target fallbacks (use verbose for details)" }
      Diagnostics.emit(.remark, summary)
    }
  } catch {
    Diagnostics.emit(.error, "Failed to write output file: \(error)")
  }
}
