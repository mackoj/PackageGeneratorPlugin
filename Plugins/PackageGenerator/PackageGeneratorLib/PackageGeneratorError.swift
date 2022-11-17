import Foundation

struct PackageGeneratorError: Error, LocalizedError, CustomStringConvertible {
  var description: String  { "Error(\(file):\(line): \(content)" }
  
  let content: String
  let file: String
  let line: UInt
  
  internal init(content: String, file: String, line: UInt) {
    self.content = content
    self.file = file
    self.line = line
  }
}
