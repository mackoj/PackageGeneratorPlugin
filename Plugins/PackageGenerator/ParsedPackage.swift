import Foundation

public struct ParsedPackage: Codable, CustomStringConvertible {
  public var name: String
  public var isTest: Bool
  public var dependencies: [String]
  public var path: String
  public var fullPath: String
  public var resources: String?
  public var exclude: [String] = []
  public var localDependencies: Int = 0
  public var hasBiggestNumberOfDependencies: Bool = false

  enum CodingKeys: String, CodingKey {
    case name
    case isTest
    case dependencies
    case path
    case fullPath
    case resources
    case exclude
    case localDependencies
    case hasBiggestNumberOfDependencies
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.name = try container.decode(String.self, forKey: .name)
    self.isTest = try container.decode(Bool.self, forKey: .isTest)
    self.dependencies = try container.decodeIfPresent([String].self, forKey: .dependencies) ?? []
    self.path = try container.decode(String.self, forKey: .path)
    self.fullPath = try container.decode(String.self, forKey: .fullPath)
    self.resources = try container.decodeIfPresent(String.self, forKey: .resources)
    self.exclude = try container.decodeIfPresent([String].self, forKey: .exclude) ?? []
    self.localDependencies = try container.decodeIfPresent(Int.self, forKey: .localDependencies) ?? 0
    self.hasBiggestNumberOfDependencies = try container.decodeIfPresent(Bool.self, forKey: .hasBiggestNumberOfDependencies) ?? false
  }

  public var hasResources: Bool {
    resources != nil && resources!.isEmpty == false
  }

  public var description: String {
    return "[\(dependencies.count)|\(localDependencies)] \(name) \(hasResources == false ? "" : "/ hasResources")"
  }
  
  public init(name: String, isTest: Bool, dependencies: [String], path: String, fullPath: String, resources: String? = nil, localDependencies: Int = 0, hasBiggestNumberOfDependencies: Bool = false, exclude: [String] = []) {
    self.name = name
    self.isTest = isTest
    self.dependencies = dependencies
    self.path = path
    self.fullPath = fullPath
    self.resources = resources
    self.localDependencies = localDependencies
    self.hasBiggestNumberOfDependencies = hasBiggestNumberOfDependencies
    self.exclude = exclude
  }
}
