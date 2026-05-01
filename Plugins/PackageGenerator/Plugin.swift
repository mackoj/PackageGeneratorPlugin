import Foundation
import PackagePlugin

@main
struct PackageGeneratorPlugin: CommandPlugin {
  func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
    // Parse --confFile argument if provided
    var configPath: String?
    for (index, arg) in arguments.enumerated() {
      if arg == "--confFile" && index + 1 < arguments.count {
        configPath = arguments[index + 1]
        break
      }
    }

    // Resolve yaml-converter tool URL from plugin context
    let yamlConverterURL = (try? context.tool(named: "yaml-converter"))?.url

    do {
      // Load config (auto-finds packageGenerator.yaml/yml/json if not explicit)
      let config = try ConfigLoader.load(
        from: context.package.directoryURL,
        explicitPath: configPath,
        yamlConverterURL: yamlConverterURL
      )

      // Generate Package.swift using V2 architecture
      PackageGeneratorV2.generate(config: config, context: context)

      Diagnostics.emit(.remark, "✅ PackageGenerator V2 finished successfully")
    } catch ConfigLoader.LoadError.fileNotFound {
      Diagnostics.emit(.error, "❌ Config file not found. Searched for packageGenerator.{yaml,yml,json}")
      // Generate default template
      do {
        try ConfigLoader.createDefault(at: context.package.directoryURL)
        Diagnostics.emit(.warning, "📝 Created default packageGenerator.json template. Configure it, then re-run.")
      } catch {
        Diagnostics.emit(.error, "Failed to create default config: \(error)")
      }
    } catch {
      Diagnostics.emit(.error, "❌ Generation failed: \(error)")
      throw error
    }
  }
}
