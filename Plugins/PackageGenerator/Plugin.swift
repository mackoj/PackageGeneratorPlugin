import Foundation
import PackagePlugin

@main
struct PackageGeneratorPlugin: CommandPlugin {
  func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
    PackageGenerator.generate(context.proxy(toolName: "package-generator-cli"), arguments)
    Diagnostics.emit(.remark, "PackageGenerator has finished")
  }
}

