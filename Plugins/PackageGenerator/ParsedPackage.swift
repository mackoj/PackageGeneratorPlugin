import Foundation

public struct ParsedPackage: Codable, CustomStringConvertible {
  public var name: String
  public var test: PackageInformation.PathInfo?
  public var dependencies: [String]
  public var testDependencies: [String]
  public var path: String
  public var fullPath: String
  public var resources: String?
  public var localDependencies: Int = 0
  public var hasBiggestNumberOfDependencies: Bool = false

  public var hasResources: Bool {
    resources != nil && resources!.isEmpty == false
  }

  public var description: String {
    if testDependencies.isEmpty {
      return "[\(dependencies.count)|\(localDependencies)] \(name) \(hasResources == false ? "" : "/ hasResources")"
    }
    return "[\(testDependencies.count)|\(localDependencies)] \(name)"
  }
  
  public init(name: String, test: PackageInformation.PathInfo? = nil, dependencies: [String], testDependencies: [String], path: String, fullPath: String, resources: String? = nil, localDependencies: Int = 0, hasBiggestNumberOfDependencies: Bool = false) {
    self.name = name
    self.test = test
    self.dependencies = dependencies
    self.testDependencies = testDependencies
    self.path = path
    self.fullPath = fullPath
    self.resources = resources
    self.localDependencies = localDependencies
    self.hasBiggestNumberOfDependencies = hasBiggestNumberOfDependencies
  }
}
