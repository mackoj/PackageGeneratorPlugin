import Foundation
import PackagePlugin

// MARK: - Plugin Entry Point

/// The main plugin entry point
/// This is the "imperative shell" - it sets up dependencies and delegates to the workflow
@main
struct PackageGeneratorPlugin: CommandPlugin {
  func performCommand(
    context: PackagePlugin.PluginContext,
    arguments: [String]
  ) async throws {
    // Set up live dependencies
    try withDependencies {
      $0 = .live(context: context)
    } operation: {
      let workflow = PluginWorkflow(context: context)
      try workflow.execute(arguments: arguments)
    }
  }
}
