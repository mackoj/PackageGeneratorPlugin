import Foundation

func runCli(
  context: Context,
  arguments: [String],
  verbose: Bool
) {
  let toolURL = context.toolURL
  
  var processArguments: [String] = []
  processArguments.append(contentsOf: arguments)
  
  let process = Process()
  process.executableURL = toolURL
  process.arguments = processArguments
  do {
    try process.run()
  } catch {
    fatalErrorWithDiagnostics("Failed run process \(process.description)")
  }
  process.waitUntilExit()
  
  if process.terminationReason == .exit, process.terminationStatus == 0 {
  } else {
    let problem = "\(process.terminationReason):\(process.terminationStatus)"
    fatalErrorWithDiagnostics("\(context.toolName) invocation failed: \(problem)")
  }
}
