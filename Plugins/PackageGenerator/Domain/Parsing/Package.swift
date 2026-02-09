import Foundation

// MARK: - Package Domain Types

/// Represents a parsed Swift package with its dependencies
struct Package: Equatable, Hashable {
  let name: String
  let path: String
  let fullPath: String
  let kind: Kind
  let dependencies: Set<String>
  let metadata: Metadata
  
  enum Kind: Equatable, Hashable {
    case target
    case testTarget
    
    var isTest: Bool {
      if case .testTarget = self { return true }
      return false
    }
  }
  
  struct Metadata: Equatable, Hashable {
    let resources: String?
    let localDependencyCount: Int
    let hasBiggestNumberOfDependencies: Bool
    
    init(
      resources: String? = nil,
      localDependencyCount: Int = 0,
      hasBiggestNumberOfDependencies: Bool = false
    ) {
      self.resources = resources
      self.localDependencyCount = localDependencyCount
      self.hasBiggestNumberOfDependencies = hasBiggestNumberOfDependencies
    }
    
    var hasResources: Bool {
      resources.map { !$0.isEmpty } ?? false
    }
  }
  
  init(
    name: String,
    path: String,
    fullPath: String,
    kind: Kind,
    dependencies: Set<String>,
    metadata: Metadata = .init()
  ) {
    self.name = name
    self.path = path
    self.fullPath = fullPath
    self.kind = kind
    self.dependencies = dependencies
    self.metadata = metadata
  }
}

// MARK: - Codable Support (for CLI communication)

extension Package: Codable {
  enum CodingKeys: String, CodingKey {
    case name, path, fullPath, isTest, dependencies, resources
    case localDependencies, hasBiggestNumberOfDependencies
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    name = try container.decode(String.self, forKey: .name)
    path = try container.decode(String.self, forKey: .path)
    fullPath = try container.decode(String.self, forKey: .fullPath)
    
    let isTest = try container.decode(Bool.self, forKey: .isTest)
    kind = isTest ? .testTarget : .target
    
    let deps = try container.decode([String].self, forKey: .dependencies)
    dependencies = Set(deps)
    
    let resources = try container.decodeIfPresent(String.self, forKey: .resources)
    let localDeps = try container.decodeIfPresent(Int.self, forKey: .localDependencies) ?? 0
    let hasBiggest = try container.decodeIfPresent(Bool.self, forKey: .hasBiggestNumberOfDependencies) ?? false
    
    metadata = Metadata(
      resources: resources,
      localDependencyCount: localDeps,
      hasBiggestNumberOfDependencies: hasBiggest
    )
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    
    try container.encode(name, forKey: .name)
    try container.encode(path, forKey: .path)
    try container.encode(fullPath, forKey: .fullPath)
    try container.encode(kind.isTest, forKey: .isTest)
    try container.encode(Array(dependencies), forKey: .dependencies)
    try container.encodeIfPresent(metadata.resources, forKey: .resources)
    try container.encode(metadata.localDependencyCount, forKey: .localDependencies)
    try container.encode(metadata.hasBiggestNumberOfDependencies, forKey: .hasBiggestNumberOfDependencies)
  }
}

// MARK: - CustomStringConvertible

extension Package: CustomStringConvertible {
  var description: String {
    let depCount = dependencies.count
    let localCount = metadata.localDependencyCount
    let resources = metadata.hasResources ? " / hasResources" : ""
    return "[\(depCount)|\(localCount)] \(name)\(resources)"
  }
}

// MARK: - Dependency Graph

/// A directed graph representing package dependencies
struct DependencyGraph: Equatable {
  private let adjacencyList: [String: Set<String>]
  private let packages: [String: Package]
  
  init(packages: [Package]) {
    var adjacencyList: [String: Set<String>] = [:]
    var packageMap: [String: Package] = [:]
    
    for package in packages {
      packageMap[package.name] = package
      adjacencyList[package.name] = package.dependencies
    }
    
    self.adjacencyList = adjacencyList
    self.packages = packageMap
  }
  
  /// All package names in the graph
  var allPackageNames: Set<String> {
    Set(packages.keys)
  }
  
  /// Get dependencies for a specific package
  func dependencies(of packageName: String) -> Set<String> {
    adjacencyList[packageName] ?? []
  }
  
  /// Get only local dependencies (packages in this graph)
  func localDependencies(of packageName: String) -> Set<String> {
    dependencies(of: packageName).intersection(allPackageNames)
  }
  
  /// Count how many packages depend on a given package
  func usageCount(of packageName: String) -> Int {
    adjacencyList.values.filter { $0.contains(packageName) }.count
  }
  
  /// Find packages with the most local dependencies
  func packagesWithMostDependencies() -> Set<String> {
    let counts = packages.keys.map { ($0, localDependencies(of: $0).count) }
    guard let maxCount = counts.map(\.1).max(), maxCount > 0 else {
      return []
    }
    return Set(counts.filter { $0.1 == maxCount }.map(\.0))
  }
  
  /// Topological sort (for dependency order)
  func topologicalSort() -> [String]? {
    var visited: Set<String> = []
    var visiting: Set<String> = []
    var result: [String] = []
    
    func visit(_ node: String) -> Bool {
      if visited.contains(node) { return true }
      if visiting.contains(node) { return false } // Cycle detected
      
      visiting.insert(node)
      
      for dependency in dependencies(of: node) {
        if !visit(dependency) { return false }
      }
      
      visiting.remove(node)
      visited.insert(node)
      result.append(node)
      return true
    }
    
    for packageName in packages.keys {
      if !visit(packageName) {
        return nil // Cycle detected
      }
    }
    
    return result
  }
  
  /// Get the package object for a name
  func package(named name: String) -> Package? {
    packages[name]
  }
  
  /// All packages in the graph
  var allPackages: [Package] {
    Array(packages.values)
  }
}

// MARK: - Package Processing

extension Package {
  /// Apply name mapping to a package
  func withMappedName(_ mapping: [String: String]) -> Package {
    let newName = mapping[self.path] ?? self.name
    return Package(
      name: newName,
      path: self.path,
      fullPath: self.fullPath,
      kind: self.kind,
      dependencies: self.dependencies,
      metadata: self.metadata
    )
  }
  
  /// Filter dependencies based on a predicate
  func filteringDependencies(_ predicate: (String) -> Bool) -> Package {
    Package(
      name: self.name,
      path: self.path,
      fullPath: self.fullPath,
      kind: self.kind,
      dependencies: self.dependencies.filter(predicate),
      metadata: self.metadata
    )
  }
  
  /// Update metadata
  func withMetadata(_ metadata: Metadata) -> Package {
    Package(
      name: self.name,
      path: self.path,
      fullPath: self.fullPath,
      kind: self.kind,
      dependencies: self.dependencies,
      metadata: metadata
    )
  }
}

// MARK: - Pure Transformation Functions

/// Remove excluded dependencies from packages
func filterExcludedDependencies(
  appleSDKs: Set<String>,
  imports: Set<String>
) -> (Package) -> Package {
  let excluded = appleSDKs.union(imports)
  return { package in
    package.filteringDependencies { !excluded.contains($0) }
  }
}

/// Apply name mappings to packages
func applyNameMappings(_ mappings: [String: String]) -> ([Package]) -> [Package] {
  map { $0.withMappedName(mappings) }
}

/// Remove packages that should be excluded
func filterExcludedPackages(_ excludedNames: Set<String>) -> ([Package]) -> [Package] {
  filter { !excludedNames.contains($0.name) }
}

/// Sort packages by name
func sortPackagesByName(_ packages: [Package]) -> [Package] {
  packages.sorted { $0.name < $1.name }
}

/// Sort packages by path then name (for pragma marks)
func sortPackagesByPath(_ packages: [Package]) -> [Package] {
  packages.sorted { lhs, rhs in
    if lhs.fullPath == rhs.fullPath {
      return lhs.name < rhs.name
    }
    return lhs.fullPath < rhs.fullPath
  }
}

/// Enrich packages with local dependency information
func enrichWithLocalDependencyInfo(graph: DependencyGraph) -> ([Package]) -> [Package] {
  let packagesWithMost = graph.packagesWithMostDependencies()
  
  return map { package in
    let localDepCount = graph.localDependencies(of: package.name).count
    let hasMost = packagesWithMost.contains(package.name)
    
    let newMetadata = Package.Metadata(
      resources: package.metadata.resources,
      localDependencyCount: localDepCount,
      hasBiggestNumberOfDependencies: hasMost
    )
    
    return package.withMetadata(newMetadata)
  }
}

/// Find packages used less than threshold times
func findUnderusedPackages(
  graph: DependencyGraph,
  threshold: Int
) -> [(name: String, usageCount: Int)] {
  graph.allPackageNames
    .map { ($0, graph.usageCount(of: $0)) }
    .filter { $0.1 <= threshold }
    .sorted { $0.0 < $1.0 }
}
