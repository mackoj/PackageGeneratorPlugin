import Foundation
import PackagePlugin

// MARK: - Phase 2: Discovery & Resolution

/// Resolves target paths using shortest-path logic.
/// If path is declared, uses it. Otherwise, searches recursively (shortest path wins).
func resolveTargetPaths(
  _ config: ConfigurationV2,
  _ context: PackagePlugin.PluginContext
) -> [String: String] {
  var resolvedPaths: [String: String] = [:]
  let packageDir = context.package.directoryURL
  
  for group in config.packageDirectoryTargets {
    let groupPath = packageDir.appendingPathComponent(group.path)
    
    for targetSpec in group.targets {
      let fullTargetPath: String
      
      if let declaredPath = targetSpec.path {
        // Use declared path
        fullTargetPath = declaredPath
      } else {
        // Infer default folder + target name
        let defaultFolder = targetSpec.type.defaultFolder
        let inferredPath = "\(group.path)/\(defaultFolder)/\(targetSpec.name)"
        
        // Check if inferred path exists
        if FileManager.default.fileExists(atPath: packageDir.appendingPathComponent(inferredPath).path) {
          fullTargetPath = inferredPath
        } else if FileManager.default.fileExists(atPath: groupPath.appendingPathComponent("\(targetSpec.name)").path) {
          // Check if group path already ends with target name
          fullTargetPath = "\(group.path)/\(targetSpec.name)"
        } else {
          // Fallback: recursive search for shortest path
          fullTargetPath = findShortestPath(
            targetName: targetSpec.name,
            in: packageDir,
            searchIn: [groupPath, packageDir.appendingPathComponent("Sources"), packageDir.appendingPathComponent("Tests")]
          ) ?? inferredPath
        }
      }
      
      resolvedPaths[targetSpec.name] = fullTargetPath
      
      if config.verbose {
        Diagnostics.emit(.remark, "Resolved target '\(targetSpec.name)' to '\(fullTargetPath)'")
      }
    }
  }
  
  return resolvedPaths
}

/// Links test targets to their corresponding regular targets.
/// Strips "Tests" suffix first; if no match, attaches to first regular target in group.
func linkTestTargets(
  _ config: ConfigurationV2,
  _ context: PackagePlugin.PluginContext
) -> [String: String] {
  var testToRegularMapping: [String: String] = [:]
  
  for group in config.packageDirectoryTargets {
    let regularTargets = group.targets.filter { $0.type == .regular }
    let testTargets = group.targets.filter { $0.type == .test }
    
    for testTarget in testTargets {
      let baseName = testTarget.regularTargetName ?? stripTestSuffix(testTarget.name)
      
      // Try to find matching regular target
      if let matchingRegular = regularTargets.first(where: { $0.name == baseName }) {
        testToRegularMapping[testTarget.name] = matchingRegular.name
      } else if let firstRegular = regularTargets.first {
        // Fallback to first regular target
        testToRegularMapping[testTarget.name] = firstRegular.name
        Diagnostics.emit(
          .warning,
          "Test target '\(testTarget.name)' has no matching regular target '\(baseName)'. Attaching to '\(firstRegular.name)'."
        )
      } else {
        Diagnostics.emit(.warning, "Test target '\(testTarget.name)' has no corresponding regular target in group.")
      }
    }
  }
  
  return testToRegularMapping
}

/// Discovers external dependencies from SPM context.
/// Queries context.package.dependencies and extracts all products.
func discoverExternalDeps(
  _ config: ConfigurationV2,
  _ context: PackagePlugin.PluginContext
) -> [String: String] {
  var externalProducts: [String: String] = [:]
  
  for dependency in context.package.dependencies {
    for product in dependency.package.products {
      let productName = product.name
      let packageName = dependency.package.displayName
      
      // Format: .product(name: "...", package: "...")
      let formattedProduct = ".product(name: \"\(productName)\", package: \"\(packageName)\")"
      externalProducts[productName] = formattedProduct
      
      if config.verbose {
        Diagnostics.emit(.remark, "Discovered external product: \(productName) from \(packageName)")
      }
    }
  }
  
  // Merge with manual mapper overrides (explicit keys overwrite)
  var merged = externalProducts
  for (key, value) in config.mappers.imports {
    merged[key] = value
  }
  
  return merged
}

/// Extracts imports for a target by shelling to package-generator-cli.
func extractTargetImports(
  targetPath: String,
  _ config: ConfigurationV2,
  _ context: PackagePlugin.PluginContext
) -> [String] {
  let packageDir = context.package.directoryURL
  let fullTargetPath = packageDir.appendingPathComponent(targetPath)
  
  // This would normally invoke package-generator-cli to parse .swift files
  // For now, return empty as a placeholder (the CLI tool would handle this)
  
  if config.verbose {
    Diagnostics.emit(.remark, "Extracting imports from target at \(fullTargetPath.path)")
  }
  
  // In the real implementation, this would:
  // 1. Invoke package-generator-cli with the target directory
  // 2. Parse the JSON output to extract import statements
  // 3. Return the list of imports
  
  return []
}

// MARK: - Helpers

private func stripTestSuffix(_ name: String) -> String {
  if name.hasSuffix("Tests") {
    return String(name.dropLast(5))
  }
  return name
}

private func findShortestPath(
  targetName: String,
  in packageDir: URL,
  searchIn directories: [URL]
) -> String? {
  var shortestPath: String? = nil
  var shortestDepth = Int.max
  
  for searchDir in directories {
    enumerateDirectories(
      at: searchDir,
      depth: 0,
      maxDepth: 10,
      targetName: targetName,
      packageDir: packageDir,
      shortestPath: &shortestPath,
      shortestDepth: &shortestDepth
    )
  }
  
  return shortestPath
}

private func enumerateDirectories(
  at directory: URL,
  depth: Int,
  maxDepth: Int,
  targetName: String,
  packageDir: URL,
  shortestPath: inout String?,
  shortestDepth: inout Int
) {
  guard depth <= maxDepth else { return }
  
  if directory.lastPathComponent == targetName {
    if depth < shortestDepth {
      shortestDepth = depth
      let fullPath = directory.path
      let packageDirStr = packageDir.path
      if let relativePath = fullPath.replacingOccurrences(of: packageDirStr + "/", with: "") as String? {
        shortestPath = relativePath
      }
    }
    return
  }
  
  do {
    let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    for item in contents {
      let itemPath = directory.appendingPathComponent(item)
      var isDir: ObjCBool = false
      if FileManager.default.fileExists(atPath: itemPath.path, isDirectory: &isDir), isDir.boolValue {
        enumerateDirectories(
          at: itemPath,
          depth: depth + 1,
          maxDepth: maxDepth,
          targetName: targetName,
          packageDir: packageDir,
          shortestPath: &shortestPath,
          shortestDepth: &shortestDepth
        )
      }
    }
  } catch {
    // Silently ignore enumeration errors
  }
}
