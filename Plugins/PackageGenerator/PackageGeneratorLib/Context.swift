import Foundation

struct Context: CustomStringConvertible {
  var packageDirectory: FileURL
  var packageTempFolder: FileURL
  var toolURL: FileURL
  var toolName: String
  var targetsName: [String] // cannot be empty

  var description: String {
    """
    Context:
    packageDirectory: \(packageDirectory)
    packageTempFolder: \(packageTempFolder)
    toolURL: \(toolURL)
    toolName: \(toolName)
    targetsName: \(targetsName)
    """
  }
}
