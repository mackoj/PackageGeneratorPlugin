import Foundation
@testable import PackageGeneratorLib

func createTestEnvironment() -> Context {
  let packageDirectory = FileManager.default.temporaryDirectory.appendingPathExtension(UUID().uuidString)
  let packageTempFolder = FileManager.default.temporaryDirectory.appendingPathExtension(UUID().uuidString)
  let toolURL = FileManager.default.temporaryDirectory.appendingPathExtension(UUID().uuidString)
  
  return Context(
    packageDirectory: packageDirectory,
    packageTempFolder: packageTempFolder,
    toolURL: toolURL,
    toolName: "package-generator-cli"
  )
}

func createConfigurationFile(_ url: URL, _ content: String) {
  
}

func badConfigurationFileBuilder(_ process: (inout [String: Any]) -> Void) throws -> URL {
  let confFileURL = FileManager.default.temporaryDirectory.appendingPathExtension(UUID().uuidString)
  let defaultConf = PackageGeneratorConfiguration()
  let data = try JSONEncoder().encode(defaultConf)
  var dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
  process(&dict)
  try JSONSerialization.data(withJSONObject: dict).write(to: confFileURL)
  return confFileURL
}

func correctConf() -> (PackageGeneratorConfiguration, URL) {
  let headerFileURL = FileManager.default.temporaryDirectory.appendingPathExtension(UUID().uuidString)
  let confFileURL = FileManager.default.temporaryDirectory.appendingPathExtension(UUID().uuidString)
  var conf = PackageGeneratorConfiguration()
  conf.headerFileURL = headerFileURL.path
  conf.packageDirectories.append(FileManager.default.temporaryDirectory.appendingPathExtension(UUID().uuidString).path)
  return (conf, confFileURL)
}
