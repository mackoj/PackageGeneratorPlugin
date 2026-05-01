import Foundation
import PackagePlugin

// MARK: - Phase 3: Import Analysis

/// Filters raw imports for a target.
/// Drops: apple SDKs, explicitly excluded imports, and the target's own module name.
/// Keeps only imports found in `validTargets ∪ externalProducts` and warns on unknown ones.
/// Returns a sorted list for deterministic output.
func filterImports(
  rawImports: [String],
  targetName: String,
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
    // Skip the target's own module (self-import)
    if importName == targetName { continue }

    // Skip explicit import exclusions
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

    // Keep only known targets and external products
    if validSet.contains(importName) {
      filtered.append(importName)
    } else if !silenceWarnings {
      Diagnostics.emit(
        .warning,
        "Dropped unresolved import '\(importName)'. If it's a system framework, ignore this."
      )
    }
  }

  return filtered.sorted()
}
