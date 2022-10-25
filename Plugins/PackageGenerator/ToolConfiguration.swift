import Foundation

struct ToolConfiguration: Codable, CustomStringConvertible {
  var defaultConfigFileName: String
  var lastHash: String?

  var description: String {
    """
ToolConfiguration:
defaultConfigFileName: \(defaultConfigFileName)
lastHash: \(lastHash ?? "nil")
"""
  }
  
  init(_ defaultConfigFileName: String = "packageGenerator.json", _ lastHash: String? = nil) {
    self.defaultConfigFileName = defaultConfigFileName
    self.lastHash = lastHash
  }
}
