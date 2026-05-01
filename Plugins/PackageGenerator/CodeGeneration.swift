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

/// Returns the pragma-mark group name for a target path.
/// Group name = second path component after Sources/ or Tests/.
func pragmaMarkGroupName(_ path: String, fallback: String) -> String {
  let parts = path.split(separator: "/").map(String.init)
  guard !parts.isEmpty else { return fallback }

  if parts.count >= 2, parts[0] == "Sources" || parts[0] == "Tests" {
    return parts[1]
  }
  if let idx = parts.firstIndex(of: "Sources"), parts.count > idx + 1 {
    return parts[idx + 1]
  }
  if let idx = parts.firstIndex(of: "Tests"), parts.count > idx + 1 {
    return parts[idx + 1]
  }
  return parts.first ?? fallback
}

/// Renders a single target as a `.target()`, `.testTarget()`, or `.macro()` block.
/// Matches V1's `fakeTargetToSwiftCode` format exactly.
func renderSingleTarget(
  _ target: ParsedPackage,
  config: ConfigurationV2,
  externalDeps: [String: String],
  leafWeights: [String: (total: Int, local: Int, isHeaviest: Bool)]
) -> String {
  let s1 = String(repeating: " ", count: config.spaces)
  let s2 = String(repeating: " ", count: config.spaces * 2)
  let s3 = String(repeating: " ", count: config.spaces * 3)

  let blockType = target.isMacro ? "macro" : (target.isTest ? "testTarget" : "target")

  // Build multi-line dependencies section — auto-discovered external deps take priority,
  // with mappers.imports already merged in by discoverExternalDeps.
  var depsStr = ""
  if !target.dependencies.isEmpty {
    let depLines = target.dependencies
      .map { dep in externalDeps[dep, default: "\"\(dep)\""] }
      .sorted(by: <)
      .map { "\(s3)\($0)" }
    depsStr = "\n\(s2)dependencies: [\n" + depLines.joined(separator: ",\n") + "\n\(s2)],"
  }

  // Leaf info comment (inline after name, before dependencies)
  var leafComment = ""
  if config.leafInfo, let w = leafWeights[target.name] {
    let emoji = w.isHeaviest ? "|🚛" : ""
    leafComment = "// [\(w.total)|\(w.local)\(emoji)]"
  }

  // Extra parameters after path (verbatim from config's targetsParameters)
  var extraParams = ""

  // Structured exclude list
  let sortedExcludes = target.exclude.sorted()
  if !sortedExcludes.isEmpty {
    let excLines = sortedExcludes.map { "\(s3)\"\($0)\"" }.joined(separator: ",\n")
    extraParams += ",\n\(s2)exclude: [\n\(excLines)\n\(s2)]"
  }

  // Remaining parameters (resources:, swiftSettings:, etc.) rendered verbatim
  for param in target.parameters ?? [] {
    let trimmed = param.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { continue }
    extraParams += ",\n\(s2)\(trimmed)"
  }

  return "\(s1).\(blockType)(\n\(s2)name: \"\(target.name)\",\(leafComment)\(depsStr)\n\(s2)path: \"\(target.path)\"\(extraParams)\n\(s1))"
}

/// Generates the products `package.products.append(contentsOf: [...])` section.
/// Includes all non-test, non-macro targets sorted alphabetically.
func generateProductsSection(
  parsedPackages: [ParsedPackage],
  config: ConfigurationV2
) -> String {
  let s1 = String(repeating: " ", count: config.spaces)

  let libs = parsedPackages
    .filter { !$0.isTest && !$0.isMacro }
    .sorted { $0.name < $1.name }

  var lines: [String] = []
  for lib in libs {
    let name = config.mappers.targets[lib.path, default: lib.name]
    lines.append("\(s1).library(name: \"\(name)\", targets: [\"\(name)\"])")
  }

  if lines.isEmpty {
    return "// MARK: - Targets\npackage.products.append(contentsOf: [\n])\n"
  }

  let body = lines.dropLast().map { $0 + "," }.joined(separator: "\n")
    + "\n" + lines.last!
  return "// MARK: - Targets\npackage.products.append(contentsOf: [\n\(body)\n])\n\n"
}

/// Generates the targets `package.targets.append(contentsOf: [...])` section
/// with optional pragma-mark grouping.
func generateTargetsSection(
  parsedPackages: [ParsedPackage],
  config: ConfigurationV2,
  externalDeps: [String: String],
  leafWeights: [String: (total: Int, local: Int, isHeaviest: Bool)]
) -> String {
  let sorted = parsedPackages.sorted { a, b in
    let ag = pragmaMarkGroupName(a.path, fallback: a.name)
    let bg = pragmaMarkGroupName(b.path, fallback: b.name)
    if ag != bg { return ag < bg }
    let ao = typeOrder(a)
    let bo = typeOrder(b)
    if ao != bo { return ao < bo }
    return a.name < b.name
  }

  var output = "// MARK: - Products\npackage.targets.append(contentsOf: [\n"
  var last = ""
  var lastGroup = ""

  for target in sorted {
    if !last.isEmpty {
      output += last + ",\n"
    }
    if config.pragmaMark {
      let group = pragmaMarkGroupName(target.path, fallback: target.name)
      if group != lastGroup {
        output += "// MARK: -\n"
        output += "// MARK: \(group)\n"
        lastGroup = group
      }
    }
    last = renderSingleTarget(target, config: config, externalDeps: externalDeps, leafWeights: leafWeights)
  }

  if !last.isEmpty {
    output += last + "\n"
  }
  output += "])\n"
  return output
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
  let productsSection = generateProductsSection(parsedPackages: parsedPackages, config: config)
  let targetsSection = generateTargetsSection(parsedPackages: parsedPackages, config: config, externalDeps: externalDeps, leafWeights: leafWeights)

  let finalContent = headerContent
    + "// MARK: - Generated \(nonTestCount) packages\n\n"
    + productsSection
    + targetsSection

  do {
    try finalContent.write(to: outputFile, atomically: true, encoding: .utf8)
    if config.verbose {
      Diagnostics.emit(.remark, "Wrote \(config.dryRun ? "dry-run" : "output") to \(outputFile.path)")
    } else {
      var summary = "Generated \(outputName) — \(nonTestCount) packages"
      if fallbackCount > 0 { summary += ", \(fallbackCount) test-target fallbacks (use verbose for details)" }
      Diagnostics.emit(.remark, summary)
    }
  } catch {
    Diagnostics.emit(.error, "Failed to write output file: \(error)")
  }
}

// MARK: - Helpers

private func typeOrder(_ target: ParsedPackage) -> Int {
  if target.isTest { return 1 }
  return 0  // regular and macro targets sort together alphabetically
}

