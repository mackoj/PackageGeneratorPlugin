import Foundation
import PackagePlugin

// MARK: - Phase 4: Code Generation

/// Injects the header file content at the top of the output.
/// Reads headerFileURL and prepends it to the output.
func injectHeader(
  headerFileURL: String?,
  _ context: PackagePlugin.PluginContext
) -> String {
  guard let headerPath = headerFileURL else {
    return ""
  }
  
  let packageDir = context.package.directoryURL
  let headerFileURL = packageDir.appendingPathComponent(headerPath)
  
  do {
    let content = try String(contentsOf: headerFileURL, encoding: .utf8)
    return content + "\n\n"
  } catch {
    Diagnostics.emit(.warning, "Failed to read header file at \(headerPath): \(error)")
    return ""
  }
}

/// Groups targets by pragma mark sections.
/// Sorts by: parent directory path, then type (regular→test→macro), then alphabetically.
struct PragmaGroup {
  let groupName: String
  let targets: [ParsedPackage]
}

func groupByPragma(
  _ targets: [ParsedPackage],
  pragmaMark: Bool,
  verbose: Bool
) -> [PragmaGroup] {
  if !pragmaMark {
    // No grouping, return single group
    return [PragmaGroup(groupName: "", targets: targets)]
  }
  
  // Sort targets by: path, then type, then name
  let sorted = targets.sorted { a, b in
    let aPath = (a.path as NSString).deletingLastPathComponent
    let bPath = (b.path as NSString).deletingLastPathComponent
    
    if aPath != bPath {
      return aPath < bPath
    }
    
    // Sort by type (regular < test < macro)
    let aTypeOrder = targetTypeOrder(a)
    let bTypeOrder = targetTypeOrder(b)
    if aTypeOrder != bTypeOrder {
      return aTypeOrder < bTypeOrder
    }
    
    // Sort alphabetically by name
    return a.name < b.name
  }
  
  // Group by parent path
  var groups: [String: [ParsedPackage]] = [:]
  for target in sorted {
    let parentPath = (target.path as NSString).deletingLastPathComponent
    let groupName = (parentPath as NSString).lastPathComponent
    if groups[groupName] == nil {
      groups[groupName] = []
    }
    groups[groupName]?.append(target)
  }
  
  // Convert to PragmaGroups in order
  let sortedGroupNames = groups.keys.sorted()
  let pragmaGroups = sortedGroupNames.map { groupName in
    PragmaGroup(groupName: groupName, targets: groups[groupName] ?? [])
  }
  
  if verbose {
    Diagnostics.emit(.remark, "Grouped \(targets.count) targets into \(pragmaGroups.count) pragma sections")
  }
  
  return pragmaGroups
}

/// Renders .target(), .testTarget(), and .macro() SPM blocks with proper indentation.
func renderTargets(
  _ pragmaGroups: [PragmaGroup],
  spaces: Int,
  leafInfo: Bool,
  hasDependencyWeights: [String: (total: Int, local: Int, isHeaviest: Bool)] = [:],
  pragmaMark: Bool
) -> String {
  let indent = String(repeating: " ", count: spaces)
  let indent2 = String(repeating: " ", count: spaces * 2)
  var output = ""
  
  var currentGroup = ""
  
  for pragmaGroup in pragmaGroups {
    // Add pragma mark if group name changed
    if pragmaMark && !pragmaGroup.groupName.isEmpty && pragmaGroup.groupName != currentGroup {
      if !output.isEmpty {
        output += "\n"
      }
      output += "\(indent)// MARK: - \(pragmaGroup.groupName)\n"
      currentGroup = pragmaGroup.groupName
    }
    
    for target in pragmaGroup.targets {
      output += renderSingleTarget(
        target,
        indent: indent2,
        leafInfo: leafInfo,
        weights: hasDependencyWeights
      )
      output += ",\n"
    }
  }
  
  // Remove trailing comma and newline if present
  if output.hasSuffix(",\n") {
    output = String(output.dropLast(2))
    output += "\n"
  }
  
  return output
}

/// Renders a single target as a .target() or .testTarget() or .macro() block.
private func renderSingleTarget(
  _ target: ParsedPackage,
  indent: String,
  leafInfo: Bool,
  weights: [String: (total: Int, local: Int, isHeaviest: Bool)]
) -> String {
  let blockType = target.isMacro ? "macro" : (target.isTest ? "testTarget" : "target")
  var params: [String] = []
  
  params.append("name: \"\(target.name)\"")
  
  // Add path if different from default
  let defaultPath = target.isTest ? "Tests" : "Sources"
  if !target.path.contains(defaultPath) {
    params.append("path: \"\(target.path)\"")
  }
  
  // Add dependencies
  if !target.dependencies.isEmpty {
    let depList = target.dependencies.map { "\"\($0)\"" }.joined(separator: ", ")
    params.append("dependencies: [\(depList)]")
  }
  
  // Add exclude if present
  if !target.exclude.isEmpty {
    let excludeList = target.exclude.map { "\"\($0)\"" }.joined(separator: ", ")
    params.append("exclude: [\(excludeList)]")
  }
  
  // Add resources if present
  if target.hasResources {
    params.append("resources: \(target.resources ?? "[]")")
  }
  
  let paramsStr = params.joined(separator: ", ")
  var line = "\(indent).\(blockType)(\(paramsStr))"
  
  // Add leaf info comment if enabled
  if leafInfo, let weight = weights[target.name] {
    let emoji = weight.isHeaviest ? " 🚛" : ""
    line += " // [\(weight.total)|\(weight.local)]\(emoji)"
  }
  
  return line
}

/// Writes the generated Package.swift to disk.
/// If dryRun=true, writes to Package_generated.swift. Otherwise, writes to Package.swift.
func writeOutput(
  _ headerContent: String,
  _ targetsContent: String,
  outputFileName: String = "Package.swift",
  _ context: PackagePlugin.PluginContext,
  dryRun: Bool,
  verbose: Bool
) {
  let packageDir = context.package.directoryURL
  let outputName = dryRun ? "Package_generated.swift" : outputFileName
  let outputFile = packageDir.appendingPathComponent(outputName)
  
  let finalContent = headerContent + targetsContent
  
  do {
    try finalContent.write(to: outputFile, atomically: true, encoding: .utf8)
    
    if verbose {
      Diagnostics.emit(.remark, "Wrote \(dryRun ? "dry-run" : "output") to \(outputFile.path)")
    } else {
      Diagnostics.emit(.remark, "Generated \(outputName)")
    }
  } catch {
    Diagnostics.emit(.error, "Failed to write output file: \(error)")
  }
}

// MARK: - Helpers

private func targetTypeOrder(_ target: ParsedPackage) -> Int {
  if target.isMacro {
    return 2
  } else if target.isTest {
    return 1
  } else {
    return 0
  }
}
