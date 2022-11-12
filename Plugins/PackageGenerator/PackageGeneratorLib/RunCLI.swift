import Foundation

func runCli(
  context: Context,
  arguments: [String],
  verbose: Bool
) throws {
  let toolURL = context.toolURL
  
  var processArguments: [String] = []
  processArguments.append(contentsOf: arguments)
  
  let process = Process()
  process.executableURL = toolURL
  process.arguments = processArguments
  do {
    try process.run()
  } catch {
    try fatalErrorWithDiagnostics("Failed run process \(process.description)")
    exit(EXIT_FAILURE)
  }
  process.waitUntilExit()
  
  if process.terminationReason == .exit, process.terminationStatus == 0 {
  } else {
    let problem = "\(process.terminationReason):\(process.terminationStatus)"
    try fatalErrorWithDiagnostics("\(context.toolName) invocation failed: \(problem)")
    exit(EXIT_FAILURE)
  }
}
