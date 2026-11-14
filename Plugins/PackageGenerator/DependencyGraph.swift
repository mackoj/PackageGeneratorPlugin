import Foundation

// MARK: - Phase 5: Dependency graph metrics
//
// Kept free of `PackagePlugin` so the test target and the benchmarks can compile this file directly.

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
    let localDeps = target.dependencies.count(where: localTargetNames.contains)
    
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
    let hasLocalDeps = target.dependencies.contains(where: localTargetNames.contains)
    
    if !hasLocalDeps && !target.isTest {
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
