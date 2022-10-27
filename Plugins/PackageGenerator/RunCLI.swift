import Foundation
import PackagePlugin

func runCli(
  context: PackagePlugin.PluginContext,
  toolName: String,
  arguments: [String],
  verbose: Bool
) {
  var tool: PluginContext.Tool!
  do {
    tool = try context.tool(named: toolName)
  } catch {
    fatalError(.error, "Failed to find tool \(toolName).")
  }
  if verbose {    
    print("toolName:", tool.path.string)
  }
  let toolURL = FileURL(fileURLWithPath: tool.path.string)
  
  var processArguments: [String] = []
  processArguments.append(contentsOf: arguments)
  
  let process = Process()
  process.executableURL = toolURL
  process.arguments = processArguments
  do {
    try process.run()
  } catch {
    Diagnostics.emit(.error, "Failed run process \(process.description).")
  }
  process.waitUntilExit()
  
  if process.terminationReason == .exit, process.terminationStatus == 0 {
  } else {
    let problem = "\(process.terminationReason):\(process.terminationStatus)"
    Diagnostics.emit(.error, "\(toolName) invocation failed: \(problem)")
  }
}
