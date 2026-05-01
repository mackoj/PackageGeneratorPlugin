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
) -> (mapping: [String: String], fallbackCount: Int) {
  var testToRegularMapping: [String: String] = [:]
  var fallbackCount = 0

  for group in config.packageDirectoryTargets {
    let regularTargets = group.targets.filter { $0.type == .regular }
    let testTargets = group.targets.filter { $0.type == .test }

    for testTarget in testTargets {
      let baseName = testTarget.regularTargetName ?? stripTestSuffix(testTarget.name)

      if let matchingRegular = regularTargets.first(where: { $0.name == baseName }) {
        testToRegularMapping[testTarget.name] = matchingRegular.name
      } else if let firstRegular = regularTargets.first {
        testToRegularMapping[testTarget.name] = firstRegular.name
        fallbackCount += 1
        if config.verbose {
          Diagnostics.emit(
            .warning,
            "Test target '\(testTarget.name)' has no matching regular target '\(baseName)'. Attaching to '\(firstRegular.name)'."
          )
        }
      } else if config.verbose {
        Diagnostics.emit(.warning, "Test target '\(testTarget.name)' has no corresponding regular target in group.")
      }
    }
  }

  return (testToRegularMapping, fallbackCount)
}

/// Discovers external dependencies from SPM context.
/// Queries context.package.dependencies and extracts all products.
/// Uses `Package.id` (the URL-derived identity) rather than `displayName` (the
/// package's self-declared name) so that generated `.product(name:package:)`
/// references match the identity SPM uses to resolve packages.
func discoverExternalDeps(
  _ config: ConfigurationV2,
  _ context: PackagePlugin.PluginContext
) -> [String: String] {
  var externalProducts: [String: String] = [:]
  
  for dependency in context.package.dependencies {
    for product in dependency.package.products {
      let productName = product.name
      // `Package.id` is the URL/path-derived identity (e.g. "vitamin-play-apple-releases"),
      // which is what SPM requires in `.product(name:package:)`. `displayName` is the
      // package's self-declared name and may differ (e.g. "VitaminPlay").
      let packageIdentity = dependency.package.id
      
      // Format: .product(name: "...", package: "...")
      let formattedProduct = ".product(name: \"\(productName)\", package: \"\(packageIdentity)\")"
      externalProducts[productName] = formattedProduct
      
      if config.verbose {
        Diagnostics.emit(.remark, "Discovered external product: \(productName) from \(packageIdentity)")
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

/// Input entry passed to package-generator-cli (mirrors PackageInformation in PackageGeneratorModels).
private struct CLIInputEntry: Codable {
  struct PathInfo: Codable {
    let path: String
    let name: String
    let exclude: [String]?
  }
  let target: PathInfo
  let test: PathInfo?
}

/// Invokes `package-generator-cli` once for all targets and returns a mapping of
/// `[configTargetName: rawImports]`.  Test packages are keyed by their explicit test
/// name (e.g., "ATTRequestTests"), not by the main target name.
func runCLI(
  config: ConfigurationV2,
  context: PackagePlugin.PluginContext,
  resolvedPaths: [String: String],
  testMapping: [String: String]  // [testTargetName: mainTargetName]
) -> [String: [String]] {
  let packageDir = context.package.directoryURL
  let workDir = context.pluginWorkDirectoryURL

  // Build reverse map: mainTargetName → testTargetName (1:1 assumed per config)
  var mainToTestName: [String: String] = [:]
  var mainToTestSpec: [String: ConfigurationV2.TargetSpec] = [:]
  for group in config.packageDirectoryTargets {
    for spec in group.targets where spec.type == .test {
      if let mainName = testMapping[spec.name] {
        mainToTestName[mainName] = spec.name
        mainToTestSpec[mainName] = spec
      }
    }
  }

  let fm = FileManager.default
  var entries: [CLIInputEntry] = []
  var pairedTestNames = Set<String>()

  // Pair regular/macro targets with their test counterparts
  for group in config.packageDirectoryTargets {
    for spec in group.targets where spec.type != .test {
      let relPath = resolvedPaths[spec.name] ?? "\(group.path)/\(spec.name)"
      let absPath = packageDir.appendingPathComponent(relPath).path

      // Skip if target directory doesn't exist on disk
      guard fm.fileExists(atPath: absPath) else {
        Diagnostics.emit(.warning, "Skipping '\(spec.name)': directory not found at \(relPath)")
        continue
      }

      let targetInfo = CLIInputEntry.PathInfo(path: absPath, name: spec.name, exclude: spec.exclude)

      var testInfo: CLIInputEntry.PathInfo?
      if let testName = mainToTestName[spec.name],
         let testRelPath = resolvedPaths[testName] {
        let absTestPath = packageDir.appendingPathComponent(testRelPath).path
        if fm.fileExists(atPath: absTestPath) {
          testInfo = CLIInputEntry.PathInfo(
            path: absTestPath,
            name: testName,
            exclude: mainToTestSpec[spec.name]?.exclude
          )
          pairedTestNames.insert(testName)
        } else {
          Diagnostics.emit(.warning, "Skipping test '\(testName)': directory not found at \(testRelPath)")
        }
      }
      entries.append(CLIInputEntry(target: targetInfo, test: testInfo))
    }
  }

  // Orphan test targets (no matching regular target)
  for group in config.packageDirectoryTargets {
    for spec in group.targets where spec.type == .test && !pairedTestNames.contains(spec.name) {
      let relPath = resolvedPaths[spec.name] ?? "\(group.path)/\(spec.name)"
      let absPath = packageDir.appendingPathComponent(relPath).path
      guard fm.fileExists(atPath: absPath) else {
        Diagnostics.emit(.warning, "Skipping orphan test '\(spec.name)': directory not found at \(relPath)")
        continue
      }
      entries.append(CLIInputEntry(
        target: CLIInputEntry.PathInfo(path: absPath, name: spec.name, exclude: spec.exclude),
        test: nil
      ))
    }
  }

  // Write input JSON
  let inputURL = workDir.appendingPathComponent("cli_input.json")
  let outputURL = workDir.appendingPathComponent("cli_output.json")

  do {
    let data = try JSONEncoder().encode(entries)
    try data.write(to: inputURL, options: [.atomic])
  } catch {
    Diagnostics.emit(.error, "Failed to write CLI input: \(error)")
    return [:]
  }

  guard let tool = try? context.tool(named: "package-generator-cli") else {
    Diagnostics.emit(.error, "Could not find package-generator-cli tool")
    return [:]
  }

  // ArgumentParser converts @Option camelCase vars to kebab-case flags
  var args = [
    "--output-file-url", outputURL.path,
    "--input-file-url", inputURL.path,
    "--package-directory", packageDir.path,
  ]
  if config.verbose { args.append("--verbose") }

  let process = Process()
  process.executableURL = tool.url
  process.arguments = args

  // In non-verbose mode suppress CLI stdout/stderr; on failure the error status is still caught below
  let suppressPipe = Pipe()
  if !config.verbose {
    process.standardOutput = suppressPipe
    process.standardError = suppressPipe
  }

  do {
    try process.run()
  } catch {
    Diagnostics.emit(.error, "Failed to launch package-generator-cli: \(error)")
    return [:]
  }
  process.waitUntilExit()

  guard process.terminationStatus == 0 else {
    Diagnostics.emit(.error, "package-generator-cli exited with status \(process.terminationStatus)")
    return [:]
  }

  guard FileManager.default.fileExists(atPath: outputURL.path) else {
    Diagnostics.emit(.warning, "package-generator-cli produced no output")
    return [:]
  }

  do {
    let data = try Data(contentsOf: outputURL)
    let parsedPackages = try JSONDecoder().decode([ParsedPackage].self, from: data)

    var result: [String: [String]] = [:]
    for pkg in parsedPackages {
      if pkg.isTest {
        // CLI stores test packages under mainTargetName; remap to explicit test target name
        let testName = mainToTestName[pkg.name] ?? (pkg.name + "Tests")
        result[testName] = pkg.dependencies
      } else {
        result[pkg.name] = pkg.dependencies
      }
    }

    if !config.keepTempFiles {
      try? FileManager.default.removeItem(at: inputURL)
      try? FileManager.default.removeItem(at: outputURL)
    }

    return result
  } catch {
    Diagnostics.emit(.error, "Failed to decode CLI output: \(error)")
    return [:]
  }
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
