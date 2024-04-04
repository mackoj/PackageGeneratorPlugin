import Foundation

public struct PackageInformation: Codable {
  public struct PathInfo: Codable {
    public let path: String
    public let name: String
  }
  public let test: PathInfo?
  public let target: PathInfo
  
  public init(from decoder: any Decoder) throws {
    // Legacy Parser
    let stringContainer = try decoder.singleValueContainer()
    if let pathString = try? stringContainer.decode(String.self) {
      let path = URL(fileURLWithPath: pathString)
      self.target = PathInfo(path: pathString, name: path.lastPathComponent)
      self.test = nil
      return
    }
    
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.test = try container.decodeIfPresent(PackageInformation.PathInfo.self, forKey: .test)
    self.target = try container.decode(PackageInformation.PathInfo.self, forKey: .target)
  }
}
