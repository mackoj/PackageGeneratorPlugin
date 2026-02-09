import Foundation
import PackagePlugin

// MARK: - Plugin Workflow

/// The main workflow for the package generator plugin
/// This is a pure function composition that orchestrates the entire process
struct PluginWorkflow {
  
  @Dependency(\.fileSystem) var fileSystem
  @Dependency(\.diagnostics) var diagnostics
  @Dependency(\.process) var process
  
  let context: PluginContext
  
  // MARK: - Main Entry Point
  
  /// Execute the complete package generation workflow
  func execute(arguments: [String]) throws {
    let packageDirectory = FilePath(context.package.directory.string)
    let tempDirectory = FilePath(context.pluginWorkDirectory.string)
    
    try packageDirectory
      |> loadOrCreateToolConfig(tempDirectory: tempDirectory, arguments: arguments)
      |> loadOrCreateConfiguration
      |> tap(validateConfiguration)
      |> tap { config in
        if config.verbose {
          diagnostics.remark("Configuration loaded successfully")
        }
      }
      |> parsePackages(packageDirectory: packageDirectory, tempDirectory: tempDirectory)
      |> processPackages
      |> generateAndWriteOutput(packageDirectory: packageDirectory)
      |> optionallyGenerateExportedFiles(packageDirectory: packageDirectory)
    
    diagnostics.remark("PackageGenerator has finished")
  }
  
  // MARK: - Configuration Loading
  
  func loadOrCreateToolConfig(
    tempDirectory: FilePath,
    arguments: [String]
  ) -> (FilePath) -> (packageDir: FilePath, toolConfig: ToolConfiguration) {
    { packageDir in
      let toolConfigPath = tempDirectory.appending("config.json")
      
      var toolConfig: ToolConfiguration
      if fileSystem.fileExists(toolConfigPath) {
        toolConfig = (try? fileSystem.readJSON(ToolConfiguration.self, from: toolConfigPath))
          ?? ToolConfiguration()
      } else {
        toolConfig = ToolConfiguration()
      }
      
      // Update config filename from arguments if provided
      if let confFileIndex = arguments.firstIndex(of: "--confFile"),
         arguments.indices.contains(confFileIndex + 1) {
        toolConfig.defaultConfigFileName = arguments[confFileIndex + 1]
      }
      
      // Save tool config
      try? fileSystem.writeJSON(toolConfig, to: toolConfigPath)
      
      return (packageDir, toolConfig)
    }
  }
  
  func loadOrCreateConfiguration(
    _ input: (packageDir: FilePath, toolConfig: ToolConfiguration)
  ) throws -> Configuration {
    let (packageDir, toolConfig) = input
    let configPath = packageDir.appending(toolConfig.defaultConfigFileName)
    
    // Create default config if it doesn't exist
    if !fileSystem.fileExists(configPath) {
      diagnostics.error("Missing configuration file at \(configPath)")
      diagnostics.error("Creating default configuration - please customize it")
      
      let defaultConfig = Configuration(
        source: .init(
          packageDirectories: NonEmptyArray([
            .init(path: "Sources/Example")
          ])!,
          headerFile: "header.swift"
        )
      )
      
      try fileSystem.writeJSON(defaultConfig, to: configPath)
      throw PluginError.configurationNotFound(path: configPath)
    }
    
    // Load existing config
    do {
      return try fileSystem.readJSON(Configuration.self, from: configPath)
    } catch {
      throw PluginError.configurationInvalid(reason: .decodingFailed(error))
    }
  }
  
  func validateConfiguration(_ config: Configuration) throws {
    // Validate header file exists
    guard fileSystem.fileExists(config.source.headerFile) else {
      throw PluginError.headerFileNotFound(path: config.source.headerFile)
    }
    
    // Validate package directories are not empty
    if config.source.packageDirectories.count == 0 {
      throw PluginError.configurationInvalid(reason: .emptyPackageDirectories)
    }
  }
  
  // MARK: - Package Parsing
  
  func parsePackages(
    packageDirectory: FilePath,
    tempDirectory: FilePath
  ) -> (Configuration) throws -> (config: Configuration, packages: [Package]) {
    { config in
      let packagesInputPath = tempDirectory.appending("\(UUID().uuidString).json")
      let parsedOutputPath = tempDirectory.appending("\(UUID().uuidString).json")
      
      // Write package directories to temp file for CLI
      let packageDirs = config.source.packageDirectories.all
      try fileSystem.writeJSON(packageDirs, to: packagesInputPath)
      
      // Build CLI arguments
      let cliArguments = [
        "--output-file-url", parsedOutputPath.rawValue,
        "--input-file-url", packagesInputPath.rawValue,
        "--package-directory", packageDirectory.rawValue,
      ] + (config.verbose ? ["--verbose"] : [])
      
      if config.verbose {
        diagnostics.remark("Running CLI: \(cliArguments.joined(separator: " "))")
      }
      
      // Run the parser CLI
      let result = try process.run(
        FilePath("package-generator-cli"),
        cliArguments
      )
      
      guard result.succeeded else {
        throw PluginError.cliExecutionFailed(
          tool: "package-generator-cli",
          status: result.terminationStatus
        )
      }
      
      // Read parsed packages
      guard fileSystem.fileExists(parsedOutputPath) else {
        diagnostics.warning("No updates to Package.swift needed")
        return (config, [])
      }
      
      let packages = try fileSystem.readJSON([Package].self, from: parsedOutputPath)
      
      // Clean up temp files unless configured to keep them
      if !config.features.keepTempFiles {
        try? fileSystem.removeFile(packagesInputPath)
        try? fileSystem.removeFile(parsedOutputPath)
      }
      
      diagnostics.remark("\(packages.count) packages found")
      
      return (config, packages)
    }
  }
  
  // MARK: - Package Processing
  
  func processPackages(
    _ input: (config: Configuration, packages: [Package])
  ) -> (config: Configuration, packages: [Package]) {
    let (config, packages) = input
    
    let processed = packages
      |> map(filterExcludedDependencies(
        appleSDKs: config.exclusion.apple.sdks,
        imports: config.exclusion.imports
      ))
      |> applyNameMappings(config.mapping.targets)
      |> filterExcludedPackages(config.exclusion.targets)
      |> when(config.features.leafInfo) {
        let graph = DependencyGraph(packages: $0)
        return $0 |> enrichWithLocalDependencyInfo(graph: graph)
      }
      |> tap { packages in
        if let threshold = config.features.unusedThreshold {
          let graph = DependencyGraph(packages: packages)
          let underused = findUnderusedPackages(graph: graph, threshold: threshold)
          for (name, count) in underused {
            diagnostics.remark("📦 \(name) is used \(count) times")
          }
        }
      }
      |> tap { packages in
        // Warn about unused target parameters
        let configuredTargets = Set(config.features.targetParameters.keys)
        let actualTargets = Set(packages.map(\.name))
        let unused = configuredTargets.subtracting(actualTargets)
        
        for targetName in unused {
          diagnostics.warning(
            "🗑️ Consider removing \"\(targetName)\" from targetParameters - target not found"
          )
        }
      }
    
    if config.verbose {
      for package in processed {
        diagnostics.remark(package.description)
      }
    }
    
    return (config, processed)
  }
  
  // MARK: - Code Generation & Output
  
  func generateAndWriteOutput(
    packageDirectory: FilePath
  ) -> ((config: Configuration, packages: [Package])) throws -> (config: Configuration, packages: [Package]) {
    { input in
      let (config, packages) = input
      
      let outputPath = packageDirectory.appending(config.output.mode.fileName)
      
      if config.verbose {
        diagnostics.remark("Generating \(config.output.mode.fileName)...")
      }
      
      // Remove old file if exists
      if fileSystem.fileExists(outputPath) {
        try fileSystem.removeFile(outputPath)
      }
      
      // Read header file
      let headerData = try fileSystem.readFile(config.source.headerFile)
      guard let header = String(data: headerData, encoding: .utf8) else {
        throw PluginError.headerFileInvalid(path: config.source.headerFile)
      }
      
      // Generate content
      let content = generatePackageSwiftContent(
        header: header,
        packages: packages,
        config: config
      )
      
      // Write output
      guard let outputData = content.data(using: .utf8) else {
        throw PluginError.encodingFailed
      }
      
      try fileSystem.writeFile(outputPath, outputData)
      
      diagnostics.remark("Generated \(config.output.mode.fileName) with \(packages.count) packages")
      
      return (config, packages)
    }
  }
  
  // MARK: - Exported Files Generation
  
  func optionallyGenerateExportedFiles(
    packageDirectory: FilePath
  ) -> ((config: Configuration, packages: [Package])) throws -> Void {
    { input in
      let (config, packages) = input
      
      guard config.features.exportedFiles != nil else {
        return
      }
      
      if config.verbose {
        diagnostics.remark("Generating exported files...")
      }
      
      let graph = DependencyGraph(packages: packages)
      
      for package in packages where !package.kind.isTest {
        let localDeps = graph.localDependencies(of: package.name)
        
        guard !localDeps.isEmpty else { continue }
        
        let exportPath = exportedFilePath(
          packagePath: package.path,
          relativePath: config.features.exportedFiles?.relativePath,
          isDryRun: config.output.mode.isDryRun
        )
        
        let fullPath = packageDirectory.appending(exportPath.rawValue)
        let directory = fullPath.deletingLastComponent
        
        // Create directory if needed
        if !fileSystem.fileExists(directory) {
          try fileSystem.createDirectory(directory)
        }
        
        // Generate content
        let content = generateExportedFileContent(
          package: package,
          localDependencies: localDeps
        )
        
        // Write file
        if let data = content.data(using: .utf8) {
          if fileSystem.fileExists(fullPath) {
            try fileSystem.removeFile(fullPath)
          }
          try fileSystem.writeFile(fullPath, data)
          
          if config.verbose {
            diagnostics.remark(
              "Generated exported file for \(package.name) with \(localDeps.count) dependencies"
            )
          }
        }
      }
    }
  }
}

// MARK: - Tool Configuration

struct ToolConfiguration: Codable {
  var defaultConfigFileName: String
  var lastHash: String?
  
  init(
    defaultConfigFileName: String = "packageGenerator.json",
    lastHash: String? = nil
  ) {
    self.defaultConfigFileName = defaultConfigFileName
    self.lastHash = lastHash
  }
}

// MARK: - Plugin Errors

enum PluginError: Error, CustomStringConvertible {
  case configurationNotFound(path: FilePath)
  case configurationInvalid(reason: ValidationError)
  case headerFileNotFound(path: FilePath)
  case headerFileInvalid(path: FilePath)
  case cliExecutionFailed(tool: String, status: Int32)
  case encodingFailed
  
  enum ValidationError {
    case emptyPackageDirectories
    case decodingFailed(Error)
  }
  
  var description: String {
    switch self {
    case .configurationNotFound(let path):
      return "Configuration file not found at \(path)"
    case .configurationInvalid(let reason):
      return "Invalid configuration: \(reason)"
    case .headerFileNotFound(let path):
      return "Header file not found at \(path)"
    case .headerFileInvalid(let path):
      return "Header file at \(path) is not valid UTF-8"
    case .cliExecutionFailed(let tool, let status):
      return "CLI tool \(tool) failed with status \(status)"
    case .encodingFailed:
      return "Failed to encode output as UTF-8"
    }
  }
}
