import Foundation
import PackagePlugin

// MARK: - Phase 3: Import Analysis

/// Filters raw imports for a target.
/// Drops: Apple SDKs, explicitly excluded imports, and the target's own module name.
/// All other imports are kept and passed through to code generation.
/// Returns a sorted list for deterministic output.
func filterImports(
  rawImports: [String],
  targetName: String,
  exclusions: ConfigurationV2.Exclusions,
  verbose: Bool
) -> [String] {
  let appleExclusions = exclusions.resolvedAppleExclusions
  let importExclusions = Set(exclusions.imports)

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

    filtered.append(importName)
  }

  return filtered.sorted()
}
