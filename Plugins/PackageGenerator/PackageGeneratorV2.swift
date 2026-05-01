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
    let testToRegularMapping = linkTestTargets(config, context)
    let externalDeps = discoverExternalDeps(config, context)
    
    logVerbose("Resolved \(resolvedPaths.count) targets, linked \(testToRegularMapping.count) test targets, discovered \(externalDeps.count) external products", config)
    
    // Phase 3: Import Analysis
    logVerbose("Phase 3: Import Analysis", config)
    let localTargetNames = Set(
      config.packageDirectoryTargets.flatMap { $0.targets.map { $0.name } }
    )
    let externalProductNames = Set(externalDeps.keys)
    
    // Phase 4: Code Generation - Prepare structures
    logVerbose("Phase 4: Code Generation", config)
    
    // Build parsed packages from config
    var parsedPackages: [ParsedPackage] = []
    
    for group in config.packageDirectoryTargets {
      for targetSpec in group.targets {
        guard let resolvedPath = resolvedPaths[targetSpec.name] else {
          Diagnostics.emit(.warning, "Could not resolve path for target '\(targetSpec.name)'")
          continue
        }
        
        // Extract imports (in real implementation, this would call package-generator-cli)
        let rawImports = extractTargetImports(targetPath: resolvedPath, config, context)
        
        // Filter imports
        let filtered = filterImports(
          rawImports: rawImports,
          validTargets: localTargetNames,
          externalProducts: externalProductNames,
          exclusions: config.exclusions,
          silenceWarnings: config.silenceUnresolvedImportWarnings,
          verbose: config.verbose
        )
        
        // Apply mappers
        let mapped = applyMappers(filtered, config, verbose: config.verbose)
        
        // Attach dependencies
        let dependencies = attachDependencies(
          targetName: targetSpec.name,
          imports: mapped,
          validTargets: localTargetNames,
          externalProducts: externalProductNames,
          verbose: config.verbose
        )
        
        // Merge exclude from multiple sources
        var finalExclude: [String] = []
        if let targetExclude = targetSpec.exclude {
          finalExclude.append(contentsOf: targetExclude)
        }
        if config.exclusions.targets.contains(targetSpec.name) {
          // Add any target-specific exclusions from config
        }
        
        // Parse inline parameters to extract resources
        var resources: String? = nil
        if let params = targetSpec.parameters {
          for param in params {
            if param.contains("resources:") {
              // Extract resources parameter
              resources = param
            }
          }
        }
        
        let parsed = ParsedPackage(
          name: targetSpec.name,
          isTest: targetSpec.type == .test,
          isMacro: targetSpec.type == .macro,
          dependencies: dependencies,
          path: resolvedPath,
          fullPath: context.package.directoryURL.appendingPathComponent(resolvedPath).path,
          resources: resources,
          exclude: finalExclude
        )
        
        parsedPackages.append(parsed)
        
        if config.verbose {
          Diagnostics.emit(.remark, "Created ParsedPackage: \(parsed)")
        }
      }
    }
    
    // Phase 5: Advanced Features
    logVerbose("Phase 5: Advanced Features", config)
    
    // Generate exported files
    generateExportedFiles(parsedPackages, exportedFilesRelativePath: config.exportedFilesRelativePath, config, context)
    
    // Detect unused targets
    if let threshold = config.unusedThreshold {
      detectUnusedTargets(parsedPackages, unusedThreshold: threshold, verbose: config.verbose)
    }
    
    // Compute dependency weights
    let weights = computeDependencyWeight(parsedPackages)
    
    if config.leafInfo {
      let analysis = analyzeDependencyGraph(parsedPackages)
      logVerbose("Dependency Graph Analysis: \(analysis.leafNodes.count) leaf nodes, \(analysis.heavyNodes.count) heavy nodes, avg \(String(format: "%.2f", analysis.averageDependenciesPerTarget)) deps/target", config)
    }
    
    // Code Generation - Render Output
    logVerbose("Rendering code generation output", config)
    
    // Inject header
    let header = injectHeader(headerFileURL: config.headerFileURL, context)
    
    // Group by pragma
    let pragmaGroups = groupByPragma(
      parsedPackages,
      pragmaMark: config.pragmaMark,
      verbose: config.verbose
    )
    
    // Render targets
    let targetsOutput = renderTargets(
      pragmaGroups,
      spaces: config.spaces,
      leafInfo: config.leafInfo,
      hasDependencyWeights: weights,
      pragmaMark: config.pragmaMark
    )
    
    // Write output
    writeOutput(
      header,
      targetsOutput,
      context,
      dryRun: config.dryRun,
      verbose: config.verbose
    )
    
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
  if config.verbose {
    Diagnostics.emit(.remark, message)
  }
}
