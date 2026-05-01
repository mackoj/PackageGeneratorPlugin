import Foundation
import PackagePlugin

/// Loads + parses configuration file. Auto-finds packageGenerator.yaml/yml/json.
/// Supports YAML via temporary conversion.
enum ConfigLoader {
  enum LoadError: Error {
    case fileNotFound
    case invalidFormat
    case decodingFailed(Error)
  }
  
  /// Load config, auto-detecting file format and location.
  static func load(
    from directory: Foundation.URL,
    explicitPath: String? = nil,
    yamlConverterURL: Foundation.URL? = nil
  ) throws -> ConfigurationV2 {
    let configURL = try findConfigFile(in: directory, explicit: explicitPath)
    let jsonURL: Foundation.URL
    
    if configURL.pathExtension.lowercased() == "yaml" || configURL.pathExtension.lowercased() == "yml" {
      // Convert YAML to JSON via yaml-converter CLI
      jsonURL = try convertYAMLToJSON(configURL, using: yamlConverterURL, workDir: directory)
    } else {
      jsonURL = configURL
    }
    
    let data = try Foundation.Data(contentsOf: jsonURL)
    let config = try JSONDecoder().decode(ConfigurationV2.self, from: data)
    
    // Clean up temp JSON if it was converted
    if jsonURL.path != configURL.path {
      try? FileManager.default.removeItem(at: jsonURL)
    }
    
    return config
  }
  
  /// Find config file in order of precedence: --confFile arg > .yaml > .yml > .json
  private static func findConfigFile(
    in directory: Foundation.URL,
    explicit: String? = nil
  ) throws -> Foundation.URL {
    if let explicit = explicit {
      let url = directory.appendingPathComponent(explicit)
      guard FileManager.default.fileExists(atPath: url.path) else {
        throw LoadError.fileNotFound
      }
      return url
    }
    
    for name in ["packageGenerator.yaml", "packageGenerator.yml", "packageGenerator.json"] {
      let url = directory.appendingPathComponent(name)
      if FileManager.default.fileExists(atPath: url.path) {
        return url
      }
    }
    
    throw LoadError.fileNotFound
  }
  
  /// Convert YAML to temporary JSON via yaml-converter executable.
  private static func convertYAMLToJSON(
    _ yamlURL: Foundation.URL,
    using converterURL: Foundation.URL?,
    workDir: Foundation.URL
  ) throws -> Foundation.URL {
    let tempJSON = workDir.appendingPathComponent(".packageGenerator_temp_\(UUID().uuidString).json")
    
    let converter = converterURL ?? workDir.appendingPathComponent("yaml-converter")
    let task = Process()
    task.executableURL = converter
    task.arguments = [
      "--input-file-url", yamlURL.path,
      "--output-file-url", tempJSON.path,
      "--input-format", "yaml",
      "--output-format", "json",
    ]
    
    try task.run()
    task.waitUntilExit()
    
    guard task.terminationStatus == 0 else {
      throw LoadError.invalidFormat
    }
    
    return tempJSON
  }
  
  /// Generate default config file if none exists.
  static func createDefault(at directory: Foundation.URL) throws {
    let template = ConfigurationV2()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let json = try encoder.encode(template)
    let configURL = directory.appendingPathComponent("packageGenerator.json")
    try json.write(to: configURL)
  }
}
