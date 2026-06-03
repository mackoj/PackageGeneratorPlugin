import Foundation
import PackagePlugin

// MARK: - PackageGeneratorV2: Main Orchestrator

/// Main V2 generator that orchestrates all phases.
/// Coordinates target discovery, import analysis, and code generation.
struct PackageGeneratorV2 {
  
  /// Executes the full V2 generation pipeline.
  static func generate(
    config: ConfigurationV2,
    context: PackagePlugin.PluginContext
  ) {
    logVerbose("Starting PackageGeneratorV2 pipeline", config)

    // Phase 2: Discovery & Resolution
    logVerbose("Phase 2: Discovery & Resolution", config)
    let resolvedPaths = resolveTargetPaths(config, context)
    let (testToRegularMapping, fallbackCount) = linkTestTargets(config, context)
    let externalDeps = discoverExternalDeps(config, context)
    logVerbose("Resolved \(resolvedPaths.count) targets, linked \(testToRegularMapping.count) test targets, discovered \(externalDeps.count) external products", config)

    // Phase 3: Import Analysis — invoke CLI once for all targets
    logVerbose("Phase 3: Import Analysis (CLI invocation)", config)
    let cliResults = runCLI(
      config: config,
      context: context,
      resolvedPaths: resolvedPaths,
      testMapping: testToRegularMapping
    )
    logVerbose("CLI returned results for \(cliResults.count) targets", config)

    // Phase 4: Code Generation — build ParsedPackage list
    logVerbose("Phase 4: Code Generation", config)
    var parsedPackages: [ParsedPackage] = []
    let exclusionTargetSet = Set(config.exclusions.targets)

    for group in config.packageDirectoryTargets {
      for targetSpec in group.targets {
        // Skip excluded targets
        if exclusionTargetSet.contains(targetSpec.name) { continue }

        guard let resolvedPath = resolvedPaths[targetSpec.name] else {
          Diagnostics.emit(.warning, "Could not resolve path for target '\(targetSpec.name)'")
          continue
        }

        let rawImports = cliResults[targetSpec.name] ?? []

        let filtered = filterImports(
          rawImports: rawImports,
          targetName: targetSpec.name,
          exclusions: config.exclusions,
          verbose: config.verbosePlugin
        )

        let parsed = ParsedPackage(
          name: targetSpec.name,
          isTest: targetSpec.type == .test,
          isMacro: targetSpec.type == .macro,
          dependencies: filtered,
          path: resolvedPath,
          fullPath: context.package.directoryURL.appendingPathComponent(resolvedPath).path,
          exclude: targetSpec.exclude ?? [],
          parameters: targetSpec.parameters,
          additionalDependencies: targetSpec.additionalDependencies
        )

        parsedPackages.append(parsed)

        if config.verbosePlugin {
          Diagnostics.emit(.remark, "ParsedPackage '\(parsed.name)': \(parsed.dependencies.count) deps, \(parsed.parameters?.count ?? 0) params")
        }
      }
    }

    // Phase 5: Advanced Features
    logVerbose("Phase 5: Advanced Features", config)
    generateExportedFiles(parsedPackages, exportedFilesRelativePath: config.exportedFilesRelativePath, config, context)

    if let threshold = config.unusedThreshold {
      detectUnusedTargets(parsedPackages, unusedThreshold: threshold, verbose: config.verbosePlugin)
    }

    let weights = computeDependencyWeight(parsedPackages)

    if config.leafInfo {
      let analysis = analyzeDependencyGraph(parsedPackages)
      logVerbose("Dependency graph: \(analysis.leafNodes.count) leaf nodes, \(analysis.heavyNodes.count) heavy, avg \(String(format: "%.2f", analysis.averageDependenciesPerTarget)) deps/target", config)
    }

    // Render & Write
    logVerbose("Rendering output", config)
    let header = injectHeader(headerFileURL: config.headerFileURL, context)
    writeOutput(header, parsedPackages, config: config, externalDeps: externalDeps, context: context, leafWeights: weights, fallbackCount: fallbackCount)

    logVerbose("PackageGeneratorV2 pipeline completed", config)
  }
  
  /// Alternative entry point that accepts a path to a ConfigurationV2 JSON file.
  static func generate(
    configPath: String,
    context: PackagePlugin.PluginContext
  ) {
    let packageDir = context.package.directoryURL
    let configURL = packageDir.appendingPathComponent(configPath)
    
    do {
      let data = try Data(contentsOf: configURL)
      let decoder = JSONDecoder()
      let config = try decoder.decode(ConfigurationV2.self, from: data)
      generate(config: config, context: context)
    } catch {
      Diagnostics.emit(.error, "Failed to load configuration from \(configPath): \(error)")
    }
  }
}

// MARK: - Logging Helper

private func logVerbose(_ message: String, _ config: ConfigurationV2) {
  if config.verbosePlugin {
    Diagnostics.emit(.remark, message)
  }
}
