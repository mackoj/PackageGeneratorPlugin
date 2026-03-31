import Foundation

public struct PackageInformation: Codable {
  public struct PathInfo: Codable {
    public let path: String
    public let name: String
    public let exclude: [String]?
    public let isMacro: Bool

    public init(path: String, name: String, exclude: [String]? = nil, isMacro: Bool = false) {
      self.path = path
      self.name = name
      self.exclude = exclude
      self.isMacro = isMacro
    }

    enum CodingKeys: CodingKey {
      case path, name, exclude, isMacro
    }

    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.path = try container.decode(String.self, forKey: .path)
      self.name = try container.decode(String.self, forKey: .name)
      self.exclude = try container.decodeIfPresent([String].self, forKey: .exclude)
      self.isMacro = try container.decodeIfPresent(Bool.self, forKey: .isMacro) ?? false
    }
  }
  public let test: PathInfo?
  public let target: PathInfo
  
  public init(target: PathInfo, test: PathInfo? = nil) {
    self.target = target
    self.test = test
  }

  enum CodingKeys: CodingKey {
    case target
    case test
  }

  public init(from decoder: any Decoder) throws {
    // Legacy Parser
    let stringContainer = try decoder.singleValueContainer()
    if let pathString = try? stringContainer.decode(String.self) {
      let path = URL(fileURLWithPath: pathString)
      self.target = PathInfo(path: pathString, name: path.lastPathComponent, exclude: nil)
      self.test = nil
      return
    }
    
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.test = try container.decodeIfPresent(PackageInformation.PathInfo.self, forKey: .test)
    self.target = try container.decode(PackageInformation.PathInfo.self, forKey: .target)
  }
}
