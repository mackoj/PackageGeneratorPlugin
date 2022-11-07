import Foundation

struct Context: CustomStringConvertible {
  let packageDirectory: FileURL
  let packageTempFolder: FileURL
  let toolURL: FileURL
  let toolName: String

  var description: String {
    "Context:\npackageDirectory: \(packageDirectory)\npackageTempFolder: \(packageTempFolder)\ntoolURL: \(toolURL)\ntoolName: \(toolName)"
  }
}
