import Foundation
import PackagePlugin

// MARK: - Phase 3: Import Analysis

/// Filters raw imports for a target.
/// Drops: explicitly excluded imports and the target's own module name.
/// Apple SDK filtering is deferred to the rendering phase so that external package
/// products whose names collide with Apple SDK names (e.g. "Charts") are never
/// silently discarded before we've had a chance to look them up in externalDeps.
/// Returns a sorted list for deterministic output.
func filterImports(
  rawImports: [String],
  targetName: String,
  exclusions: ConfigurationV2.Exclusions,
  verbose: Bool
) -> [String] {
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

    filtered.append(importName)
  }

  return filtered.sorted()
}
