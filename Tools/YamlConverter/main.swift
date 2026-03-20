import Foundation
import Yams

enum ConverterError: LocalizedError {
  case missingArgument(String)
  case unsupportedFormat(String)
  case invalidInput(String)

  var errorDescription: String? {
    switch self {
    case .missingArgument(let name):
      return "Missing required argument: \(name)"
    case .unsupportedFormat(let name):
      return "Unsupported format: \(name)"
    case .invalidInput(let message):
      return message
    }
  }
}

struct ConverterArguments {
  let inputFileURL: URL
  let outputFileURL: URL
  let inputFormat: String
  let outputFormat: String
}

do {
  let arguments = try parseArguments(CommandLine.arguments)
  let inputData = try Data(contentsOf: arguments.inputFileURL)
  let outputData: Data

  switch (arguments.inputFormat, arguments.outputFormat) {
  case ("json", "json"), ("yaml", "yaml"):
    outputData = inputData
  case ("json", "yaml"):
    let object = try JSONSerialization.jsonObject(with: inputData, options: [.fragmentsAllowed])
    let yaml = try Yams.dump(object: object)
    outputData = Data(yaml.utf8)
  case ("yaml", "json"):
    guard let inputString = String(data: inputData, encoding: .utf8) else {
      throw ConverterError.invalidInput("Input data is not valid UTF-8.")
    }
    guard let object = try Yams.load(yaml: inputString) else {
      throw ConverterError.invalidInput("YAML input did not produce a value.")
    }
    outputData = try JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed, .prettyPrinted, .sortedKeys])
  default:
    throw ConverterError.unsupportedFormat("\(arguments.inputFormat) -> \(arguments.outputFormat)")
  }

  try outputData.write(to: arguments.outputFileURL, options: [.atomic])
} catch {
  FileHandle.standardError.write("\(error.localizedDescription)\n".data(using: .utf8)!)
  exit(EXIT_FAILURE)
}

func parseArguments(_ arguments: [String]) throws -> ConverterArguments {
  func value(after flag: String) throws -> String {
    guard let index = arguments.firstIndex(of: flag), index < arguments.index(before: arguments.endIndex) else {
      throw ConverterError.missingArgument(flag)
    }
    return arguments[arguments.index(after: index)]
  }

  let inputFileURL = URL(fileURLWithPath: try value(after: "--input-file-url"))
  let outputFileURL = URL(fileURLWithPath: try value(after: "--output-file-url"))
  let inputFormat = try value(after: "--input-format").lowercased()
  let outputFormat = try value(after: "--output-format").lowercased()
  return ConverterArguments(
    inputFileURL: inputFileURL,
    outputFileURL: outputFileURL,
    inputFormat: inputFormat,
    outputFormat: outputFormat
  )
}
