import Foundation

struct ParsedPackage: Codable, CustomStringConvertible {
  var name: String
  var dependencies: [String]
  var path: String
  var fullPath: String
  var resources: String?
  var localDependencies: Int = 0
  var hasBiggestNumberOfDependencies: Bool = false

  var hasResources: Bool {
    resources != nil && resources!.isEmpty == false
  }
  var description: String {
    "[\(dependencies.count)|\(localDependencies)] \(name) \(hasResources == false ? "" : "/ hasResources")"
  }
}
