import Foundation
import PackagePlugin

@main
struct PackageGeneratorPlugin: CommandPlugin {
  func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
    PackageGenerator.generate(context, arguments)
    Diagnostics.emit(.remark, "PackageGenerator has finished")
  }
}

func fatalError(_ severity: PackagePlugin.Diagnostics.Severity, _ description: String, file: StaticString = #file, line: UInt = #line) -> Never {
  Diagnostics.emit(severity, description)
  fatalError(file: file, line: line)
}
