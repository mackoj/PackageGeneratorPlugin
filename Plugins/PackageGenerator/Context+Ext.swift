import Foundation
import PackagePlugin

extension PackagePlugin.PluginContext {
  func proxy(toolName: String) -> Context {
    var tool: PluginContext.Tool!
    do {
      tool = try self.tool(named: toolName)
    } catch {
      fatalErrorWithDiagnostics("Failed to find tool \(toolName).")
    }
    return Context(
      packageDirectory: FileURL(fileURLWithPath: self.package.directory.string),
      packageTempFolder: FileURL(fileURLWithPath: self.pluginWorkDirectory.string),
      toolURL: FileURL(fileURLWithPath: tool.path.string),
      toolName: toolName
    )
  }
}
