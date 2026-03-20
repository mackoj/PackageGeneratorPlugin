import Foundation

enum ConfigurationFileFormat {
  case json
  case yaml

  init(configurationFileURL: FileURL) {
    switch configurationFileURL.pathExtension.lowercased() {
    case "yaml", "yml":
      self = .yaml
    default:
      self = .json
    }
  }

  var usesYAMLConverter: Bool {
    self == .yaml
  }

  var cliArgument: String {
    switch self {
    case .json:
      return "json"
    case .yaml:
      return "yaml"
    }
  }
}
