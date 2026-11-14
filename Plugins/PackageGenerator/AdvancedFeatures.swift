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
  
  for target in targets where !target.isTest && !target.isExecutable {
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
