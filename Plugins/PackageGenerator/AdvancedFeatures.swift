import Foundation
import PackagePlugin

// MARK: - Phase 5: Advanced Features

/// Generates exported.swift files for targets with @_exported imports.
/// For each target, creates a file with @_exported import statements for its dependencies.
func generateExportedFiles(
  _ targets: [ParsedPackage],
  exportedFilesRelativePath: String?,
  _ config: ConfigurationV2,
  _ context: PackagePlugin.PluginContext
) {
  guard config.generateExportedFiles else { return }
  
  let packageDir = context.package.directoryURL
  
  for target in targets where !target.isTest {
    guard !target.dependencies.isEmpty else { continue }
    
    let exportedFileName = "exported.swift"
    let exportedPath: String
    
    if let relativePath = exportedFilesRelativePath {
      exportedPath = "\(target.path)/\(relativePath)/\(exportedFileName)"
    } else {
      exportedPath = "\(target.path)/\(exportedFileName)"
    }
    
    let exportedFileURL = packageDir.appendingPathComponent(exportedPath)
    
    // Create directory if needed
    let exportedDir = exportedFileURL.deletingLastPathComponent()
    do {
      try FileManager.default.createDirectory(
        at: exportedDir,
        withIntermediateDirectories: true,
        attributes: nil
      )
    } catch {
      Diagnostics.emit(.warning, "Failed to create directory for exported files: \(error)")
      continue
    }
    
    // Generate content
    var content = "// This file is auto-generated. Do not edit.\n\n"
    for dep in target.dependencies {
      content += "@_exported import \(dep)\n"
    }
    
    do {
      try content.write(to: exportedFileURL, atomically: true, encoding: .utf8)
      if config.verbosePlugin {
      }
    } catch {
      Diagnostics.emit(.warning, "Failed to write exported file for target '\(target.name)': \(error)")
    }
  }
}

/// Detects unused targets based on usage count vs threshold.
/// Warns if a target is used <= unusedThreshold times.
func detectUnusedTargets(
  _ targets: [ParsedPackage],
  unusedThreshold: Int?,
  verbose: Bool
) {
  guard let threshold = unusedThreshold else { return }
  
  // Build a map of how many times each target is used
  var usageCount: [String: Int] = [:]
  
  for target in targets {
    usageCount[target.name] = 0
  }
  
  for target in targets {
    for dep in target.dependencies {
      usageCount[dep, default: 0] += 1
    }
  }
  
  // Check for unused targets
  for target in targets {
    let count = usageCount[target.name] ?? 0
    if count <= threshold {
      Diagnostics.emit(
        .warning,
        "📦 \(target.name) is used \(count) times"
      )
    }
  }
}

/// Computes dependency weights for each target.
/// Returns a dictionary with total and local dependency counts.
/// Marks the target with the highest number of local dependencies.
func computeDependencyWeight(
  _ targets: [ParsedPackage]
) -> [String: (total: Int, local: Int, isHeaviest: Bool)] {
  var weights: [String: (total: Int, local: Int, isHeaviest: Bool)] = [:]
  
  let localTargetNames = Set(targets.map { $0.name })
  var maxLocalDeps = 0
  var heaviestTarget: String? = nil
  
  // First pass: compute weights
  for target in targets {
    let totalDeps = target.dependencies.count
    let localDeps = target.dependencies.filter { localTargetNames.contains($0) }.count
    
    weights[target.name] = (total: totalDeps, local: localDeps, isHeaviest: false)
    
    if localDeps > maxLocalDeps {
      maxLocalDeps = localDeps
      heaviestTarget = target.name
    }
  }
  
  // Second pass: mark heaviest
  if let heaviest = heaviestTarget {
    weights[heaviest]?.isHeaviest = true
  }
  
  return weights
}

/// Analyzes the dependency graph and provides architectural insights.
/// (Helper for understanding module coupling)
func analyzeDependencyGraph(_ targets: [ParsedPackage]) -> DependencyGraphAnalysis {
  let localTargetNames = Set(targets.map { $0.name })
  
  var analysis = DependencyGraphAnalysis()
  
  for target in targets {
    let localDeps = target.dependencies.filter { localTargetNames.contains($0) }
    
    if localDeps.isEmpty && !target.isTest {
      analysis.leafNodes.append(target.name)
    }
    
    if target.dependencies.count > 5 {
      analysis.heavyNodes.append((target.name, target.dependencies.count))
    }
    
    analysis.totalDependencies += target.dependencies.count
  }
  
  return analysis
}

// MARK: - Supporting Types

struct DependencyGraphAnalysis {
  var leafNodes: [String] = []
  var heavyNodes: [(String, Int)] = []
  var totalDependencies: Int = 0
  
  var averageDependenciesPerTarget: Double {
    guard !leafNodes.isEmpty || !heavyNodes.isEmpty else { return 0 }
    let targetCount = leafNodes.count + heavyNodes.count
    return targetCount > 0 ? Double(totalDependencies) / Double(targetCount) : 0
  }
}
