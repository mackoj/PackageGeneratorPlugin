import Foundation

/// Normalized internal representation of a target.
struct NormalizedTarget {
  let name: String
  let type: ConfigurationV2.TargetSpec.TargetType
  let path: String
  let exclude: Set<String>
  let parameters: [String]
  let isMacro: Bool
  
  var isTest: Bool {
    type == .test
  }
}

/// Resolved target with calculated dependencies.
struct ResolvedTarget {
  let target: NormalizedTarget
  let testTarget: NormalizedTarget?
  let dependencies: [String]
  let externalDependencies: [String]
  
  var allDependencies: [String] {
    (dependencies + externalDependencies).sorted()
  }
}

/// External dependency product reference.
struct ExternalProduct {
  let name: String
  let package: String
  
  var formattedReference: String {
    ".product(name: \"\(name)\", package: \"\(package)\")"
  }
}

/// Dependency graph analysis.
struct DependencyAnalysis {
  let targetsByName: [String: ResolvedTarget]
  let unusedTargets: [String]
  let dependencyWeights: [String: (total: Int, local: Int)]
  let heaviestLocalTarget: String?
}
