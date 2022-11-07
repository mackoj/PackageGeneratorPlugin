import Foundation

struct ParsedPackage: Codable, CustomStringConvertible {
  var name: String
  var dependencies: [String]
  var path: String
  var fullPath: String
  var localDependencies: Int = 0
  var hasBiggestNumberOfDependencies: Bool = false

  var description: String {
    "[\(dependencies.count)|\(localDependencies)] \(name)"
  }
}
