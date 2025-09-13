import Foundation

public enum TargetType: String, Codable {
  case target
  case testTarget
  case executableTarget
  case systemLibrary
  case binaryTarget
}

public struct ParsedPackage: Codable, CustomStringConvertible {
  public var name: String
  public var isTest: Bool
  public var targetType: TargetType
  public var dependencies: [String]
  public var path: String
  public var fullPath: String
  public var resources: String?
  public var localDependencies: Int = 0
  public var hasBiggestNumberOfDependencies: Bool = false

  public var hasResources: Bool {
    resources != nil && resources!.isEmpty == false
  }

  public var description: String {
    return "[\(dependencies.count)|\(localDependencies)] \(name) (\(targetType.rawValue)) \(hasResources == false ? "" : "/ hasResources")"
  }
  
  public init(name: String, isTest: Bool, targetType: TargetType? = nil, dependencies: [String], path: String, fullPath: String, resources: String? = nil, localDependencies: Int = 0, hasBiggestNumberOfDependencies: Bool = false) {
    self.name = name
    self.isTest = isTest
    // Auto-determine target type based on isTest if not explicitly provided
    if let targetType = targetType {
      self.targetType = targetType
    } else {
      self.targetType = isTest ? .testTarget : .target
    }
    self.dependencies = dependencies
    self.path = path
    self.fullPath = fullPath
    self.resources = resources
    self.localDependencies = localDependencies
    self.hasBiggestNumberOfDependencies = hasBiggestNumberOfDependencies
  }
}
