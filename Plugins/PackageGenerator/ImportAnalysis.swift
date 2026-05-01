import Foundation
import PackagePlugin

// MARK: - Phase 3: Import Analysis

/// Filters imports using strict set intersection.
/// Only keeps imports that exist as local targets or external products.
/// Auto-drops Apple SDKs unless explicitly configured.
func filterImports(
  rawImports: [String],
  validTargets: Set<String>,
  externalProducts: Set<String>,
  exclusions: ConfigurationV2.Exclusions,
  silenceWarnings: Bool,
  verbose: Bool
) -> [String] {
  let appleExclusions = exclusions.resolvedAppleExclusions
  let importExclusions = Set(exclusions.imports)
  let validSet = validTargets.union(externalProducts)
  
  var filtered: [String] = []
  
  for importName in rawImports {
    // Skip self-imports
    if validTargets.contains(importName) && rawImports.filter({ $0 == importName }).count == 1 {
      // This is a self-import, skip it
      continue
    }
    
    // Skip explicit exclusions
    if importExclusions.contains(importName) {
      if verbose {
        Diagnostics.emit(.remark, "Skipped excluded import: \(importName)")
      }
      continue
    }
    
    // Skip Apple SDKs
    if appleExclusions.contains(importName) {
      if verbose {
        Diagnostics.emit(.remark, "Skipped Apple SDK: \(importName)")
      }
      continue
    }
    
    // Only keep if in valid set
    if validSet.contains(importName) {
      filtered.append(importName)
    } else if !silenceWarnings {
      Diagnostics.emit(
        .warning,
        "ℹ️ Dropped unresolved import '\(importName)'. If this is a system framework, ignore this. Otherwise, ensure it is linked in the root Package.swift."
      )
    }
  }
  
  return filtered
}

/// Applies mapper transformations to imports and target names.
/// Rename imports per mappers.imports, rename target paths per mappers.targets.
func applyMappers(
  _ imports: [String],
  _ config: ConfigurationV2,
  verbose: Bool
) -> [String] {
  var mapped = imports
  
  // Apply import mappers
  mapped = mapped.map { importName -> String in
    if let renamed = config.mappers.imports[importName] {
      if verbose {
        Diagnostics.emit(.remark, "Mapped import '\(importName)' to '\(renamed)'")
      }
      return renamed
    }
    return importName
  }
  
  return mapped
}

/// Attaches filtered dependencies to each target.
/// For each target, returns the list of valid dependencies.
func attachDependencies(
  targetName: String,
  imports: [String],
  validTargets: Set<String>,
  externalProducts: Set<String>,
  verbose: Bool
) -> [String] {
  var dependencies: [String] = []
  
  for importName in imports {
    // Check if it's a local target
    if validTargets.contains(importName) && importName != targetName {
      dependencies.append(importName)
    }
    // Check if it's an external product
    else if externalProducts.contains(importName) {
      dependencies.append(importName)
    }
  }
  
  if verbose && !dependencies.isEmpty {
    Diagnostics.emit(.remark, "Target '\(targetName)' depends on: \(dependencies.joined(separator: ", "))")
  }
  
  return dependencies
}
