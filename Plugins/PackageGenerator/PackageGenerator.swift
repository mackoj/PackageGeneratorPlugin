import Foundation
import PackagePlugin

struct PackageGenerator {
  
  static func generate(_ context: PackagePlugin.PluginContext, _ arguments: [String]) {
    let packageDirectory = FileURL(fileURLWithPath: context.package.directory.string)
    let packageTempFolder = FileURL(fileURLWithPath: context.pluginWorkDirectory.string)
    
    /// Load Tool Configuration
    let toolConfigFileURL: FileURL = packageTempFolder.appendingPathComponent("config.json")
    var toolConfig = getDefaultConfigurationName(toolConfigFileURL)
    
    /// Prepare configuration
    toolConfig = updateDefaultConfigFileName(arguments, toolConfig)
    saveToolConfig(toolConfig, toolConfigFileURL)
    let configurationFileURL = getConfigurationFileURL(packageDirectory, arguments, toolConfig.defaultConfigFileName)
    if FileManager.default.fileExists(atPath: configurationFileURL.path) == false {
      createDefaultConfiguration(configurationFileURL)
    }
    let config = loadConfiguration(configurationFileURL)
    validateConfiguration(config, configurationFileURL)
    
    if config.verbose { print(toolConfig) }
    
    /// Generate ParsedPackage
    let parsedPackageFileURL = packageTempFolder.appendingPathComponent("\(UUID().uuidString).json")
    let packagesFileURL = packageTempFolder.appendingPathComponent("\(UUID().uuidString).json")
    
    if config.verbose {
      print("packagesFileURL:", packagesFileURL.path)
      print("parsedPackageFileURL:", parsedPackageFileURL.path)
    }
    do {
      let packageDirectoriesData = try JSONEncoder().encode(config.packageDirectories)
      try packageDirectoriesData.write(to: packagesFileURL, options: [.atomic])
    } catch {
      fatalError(.error, "Failed to share data with the cli.")
    }
    
    var cliArguments: [String] = [
      "--output-file-url",
      parsedPackageFileURL.path,
      "--input-file-url",
      packagesFileURL.path,
      "--package-directory",
      packageDirectory.path,
    ]
    
    if config.verbose {
      cliArguments.append("--verbose")
    }
    
    if config.verbose {
      print("package-generator-cli", cliArguments.joined(separator: " "))
    }
    
    runCli(
      context: context,
      toolName: "package-generator-cli",
      arguments: cliArguments,
      verbose: config.verbose
    )
    
    if FileManager.default.fileExists(atPath: parsedPackageFileURL.path) == false {
      Diagnostics.emit(.warning, "No update to Package.swift needed")
    }
    
    // Load ParsedPackage
    var parsedPackages: [ParsedPackage] = []
    do {
      let data = try Data(contentsOf: parsedPackageFileURL)
      parsedPackages = try JSONDecoder().decode([ParsedPackage].self, from: data)
    } catch {
      fatalError(.error, "Failed to read at \(parsedPackageFileURL.path) or Failed to JSONDecode at \(parsedPackageFileURL.path)")
    }
    
    do {
      try FileManager.default.removeItem(at: parsedPackageFileURL)
    } catch {
      Diagnostics.emit(.warning, "Failed to removeItem at \(parsedPackageFileURL.path)")
    }
    
    do {
      try FileManager.default.removeItem(at: packagesFileURL)
    } catch {
      Diagnostics.emit(.warning, "Failed to removeItem at \(packagesFileURL.path)")
    }
    print("\(parsedPackages.count) packages found")
    
    // Clean packages
    parsedPackages = parsedPackages.map { parsedPackage in
      var parsedPackage = parsedPackage
      var localDependencies = parsedPackage.dependencies
      localDependencies.removeAll(where: config.exclusions.apple.contains(_:))
      localDependencies.removeAll(where: config.exclusions.imports.contains(_:))
      localDependencies.sort(by: <)
      parsedPackage.dependencies = localDependencies
      parsedPackage.name = config.mappers.targets[parsedPackage.name, default: parsedPackage.name]
      if config.exclusions.targets.contains(parsedPackage.name) == false {
        parsedPackages.append(parsedPackage)
      } else {
        Diagnostics.emit(.warning, "❌ Rejecting: \(parsedPackage)")
      }
      return parsedPackage
    }
    
    // UpdateIsLeaf
    if config.leafInfo == true {
      if config.verbose { print("Update leaf status in Packages...") }
      parsedPackages = updateIsLeaf(config, parsedPackages)
    }
    
    if config.unusedThreshold != nil {
      updateIsUnsused(config, parsedPackages)
    }
    
    if config.verbose { for parsedPackage in parsedPackages { print(parsedPackage) } }
    
    // Write Package.swift
    let outputFileName = config.dryRun ? "Package_generated.swift" : "Package.swift"
    if config.verbose { print("Preparing \(outputFileName)...") }
    let outputURL = packageDirectory.appendingPathComponent(outputFileName)
    if FileManager.default.fileExists(atPath: outputURL.path) {
      do {
        try FileManager.default.removeItem(at: outputURL)
      } catch {
        fatalError(.error, "Failed to remove \(outputURL.path)")
      }
      
    }
    if FileManager.default.fileExists(atPath: outputURL.path) == false {
      FileManager.default.createFile(atPath: outputURL.path, contents: nil)
    }
    
    if config.verbose { print("Generating \(outputFileName)...") }
    
    // Filling
    var outputFileHandle: FileHandle!
    
    do {
      outputFileHandle = try FileHandle(forWritingTo: outputURL)
    } catch {
      fatalError(.error, "Failed to create FileHandle for \(outputURL.path)")
    }
    guard let headerFileURL = config.headerFileURL else {
      fatalError(.error, "No header fileURL configured")
    }
    if FileManager.default.fileExists(atPath: headerFileURL.fileURL.path) == false {
      fatalError(.error, "No header file found at \(headerFileURL.fileURL.path)")
    }
    
    var headerData: Data
    do {
      headerData = try Data(contentsOf: headerFileURL.fileURL)
    } catch {
      fatalError(.error, "Failed to load header data")
    }
    
    outputFileHandle.write(headerData)
    outputFileHandle.write("// MARK: - Generated \(parsedPackages.count) packages\n\n".data(using: .utf8)!)
    
    // Write Products
    if config.verbose { print("Generating Products...") }
    generateProducts(parsedPackages, outputFileHandle, config)
    outputFileHandle.write("\n".data(using: .utf8)!)
    
    // Write Targets
    if config.verbose { print("Generating Targets...") }
    generateTargets(parsedPackages, outputFileHandle, config, packageDirectory)
    outputFileHandle.closeFile()
  }
  
  // MARK: - Private
  
  // MARK: ToolConfiguration
  private static func getDefaultConfigurationName(_ toolConfigFileURL: FileURL) -> ToolConfiguration {
    if FileManager.default.fileExists(atPath: toolConfigFileURL.path) {
      do {
        let data = try Data(contentsOf: toolConfigFileURL)
        let toolConfig = try JSONDecoder().decode(ToolConfiguration.self, from: data)
        return toolConfig
      } catch {
        Diagnostics.emit(.error, "Failed to load ToolConfiguration file.")
      }
    }
    let toolConfig = ToolConfiguration()
    saveToolConfig(toolConfig, toolConfigFileURL)
    return toolConfig
  }
  
  private static func saveToolConfig(_ toolConfig: ToolConfiguration, _ toolConfigFileURL: FileURL) {
    do {
      let data = try JSONEncoder().encode(toolConfig)
      try data.write(to: toolConfigFileURL, options: [.atomic])
    } catch {
      Diagnostics.emit(.warning, "Failed to write ToolConfiguration file.")
    }
  }
  
  // MARK: Configuration
  private static func updateDefaultConfigFileName(_ arguments: [String], _ toolConfig: ToolConfiguration) -> ToolConfiguration {
    var toolConfig = toolConfig
    var configurationFileName = toolConfig.defaultConfigFileName
    if let cf = arguments.firstIndex(of: "--confFile") {
      let param = arguments.index(after: cf)
      if param != cf {
        let confFile = arguments[param]
        configurationFileName = confFile
      }
    }
    toolConfig.defaultConfigFileName = configurationFileName
    return toolConfig
  }
  
  private static func getConfigurationFileURL(_ packageDirectory: FileURL, _ arguments: [String], _ configurationFileName: String) -> FileURL {
    let configurationFileURL = packageDirectory.appendingPathComponent(configurationFileName)
    return configurationFileURL
  }
  
  private static func createDefaultConfiguration(_ configurationFileURL: FileURL) {
    if FileManager.default.fileExists(atPath: configurationFileURL.path) == false {
      Diagnostics.emit(.error, "Missing a configuration file at \(configurationFileURL.path)")
      Diagnostics.emit(.error, "We will generate a default one for you but you will need to customise it.")
      var defaultConf: Data!
      do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        defaultConf = try encoder.encode(PackageGeneratorConfiguration())
      } catch {
        fatalError(.error, "Failed to encode a default configuration.")
      }
      do {
        try defaultConf.write(to: configurationFileURL, options: [.atomic])
      } catch {
        fatalError(.error, "Failed to encode write a default configuration at \(configurationFileURL.path)")
      }
    }
  }
  
  private static func loadConfiguration(_ configurationFileURL: FileURL) -> PackageGeneratorConfiguration{
    var data: Data
    do {
      data = try Data(contentsOf: configurationFileURL)
      if data.isEmpty {
        fatalError(.error, "Failed to read Data from file \(configurationFileURL.path)")
      }
    } catch {
      fatalError(.error, "Failed to read Data from file \(configurationFileURL.path)\n\(dump(error))")
    }
    var config: PackageGeneratorConfiguration
    do {
      config = try JSONDecoder().decode(PackageGeneratorConfiguration.self, from: data)
    } catch {
      Diagnostics.emit(.error, "packageDirectories might be empty")
      Diagnostics.emit(.error, String(data: data, encoding: String.Encoding.utf8) ?? "<nil>")
      fatalError(.error, "Failed to decode JSON file \(configurationFileURL.path)\n\(dump(error))")
    }
    
    if config.verbose { print(config) }
    return config
  }
  
  private static func validateConfiguration(_ config: PackageGeneratorConfiguration, _ configurationFileURL: FileURL) {
    if config.headerFileURL == nil || config.headerFileURL?.fileURL.path.isEmpty == true {
      fatalError(.error, "headerFileURL in \(configurationFileURL.path) should not be empty")
    }
    if config.packageDirectories.isEmpty {
      fatalError(.error, "packageDirectories in \(configurationFileURL.path) should not be empty")
    }
  }
  
  // MARK: ParsedPackage Processing
  private static func updateIsUnsused(_ configuration: PackageGeneratorConfiguration, _ inputParsedPackages: [ParsedPackage]) {
    let unusedThreshold = configuration.unusedThreshold ?? defaultUnusedThreshold
    let names = Set<String>(inputParsedPackages.map { $0.name })
    for name in names {
      var usedCount = 0
      for pkg in inputParsedPackages {
        if pkg.dependencies.contains(name) {
          usedCount += 1
        }
      }
      if usedCount <= unusedThreshold {
        print("📦 \(name) is used \(usedCount) times")
      }
    }
  }
  
  private static func updateIsLeaf(_ configuration: PackageGeneratorConfiguration, _ inputParsedPackages: [ParsedPackage]) -> [ParsedPackage] {
    let names = Set<String>(inputParsedPackages.map { $0.name })
    var parsedPackages = inputParsedPackages
    var biggest: Int = 0
    for index in 0..<parsedPackages.count {
      let dependencies = Set<String>(parsedPackages[index].dependencies)
      let intersec = dependencies.intersection(names)
      parsedPackages[index].localDependencies = intersec.count
      biggest = max(biggest, intersec.count)
    }
    for index in 0..<parsedPackages.count {
      if parsedPackages[index].localDependencies == biggest {
        parsedPackages[index].hasBiggestNumberOfDependencies = true
      }
    }
    return parsedPackages
  }
  
  // MARK: Generate
  private static func generateProducts(_ parsedPackages: [ParsedPackage], _ outputFileHandle: FileHandle, _ configuration: PackageGeneratorConfiguration) {
    outputFileHandle.write("// MARK: - Targets\n".data(using: .utf8)!)
    outputFileHandle.write("package.products.append(contentsOf: [\n".data(using: .utf8)!)
    
    var last: String = ""
    for parsedPackage in parsedPackages.sorted(by: \.name, order: <) {
      if last.isEmpty == false {
        outputFileHandle.write("\(last),\n".data(using: .utf8)!)
      }
      let name = configuration.mappers.targets[parsedPackage.name, default: parsedPackage.name]
      let spaces = String(repeating: " ", count: configuration.spaces)
      last = "\(spaces).library(name: \"" + name + "\", targets: [\"" + name + "\"])"
    }
    outputFileHandle.write("\(last)\n])\n".data(using: .utf8)!)
  }
  
  private static func generateTargets(_ parsedPackages: [ParsedPackage], _ outputFileHandle: FileHandle, _ configuration: PackageGeneratorConfiguration, _ packageDirectory: URL) {
    outputFileHandle.write("// MARK: - Products\n".data(using: .utf8)!)
    outputFileHandle.write("package.targets.append(contentsOf: [\n".data(using: .utf8)!)
    
    let sourceCodePath = packageDirectory.appendingPathComponent("Sources")
    var last: String = ""
    var lastCommonPath: String = ""
    for parsedPackage in parsedPackages {
      if last.isEmpty == false {
        outputFileHandle.write("\(last),\n".data(using: .utf8)!)
      }
      
      let packageFolder = parsedPackage.fullPath
      last = fakeTargetToSwiftCode(parsedPackage, configuration)
      if configuration.pragmaMark == true, let linePath = URL(string: packageFolder, relativeTo: sourceCodePath) {
        if let newLastCommon = generateHeader(lastCommonPath, linePath.relativePath) {
          outputFileHandle.write("// MARK: -\n".data(using: .utf8)!)
          outputFileHandle.write("// MARK: \(newLastCommon)\n".data(using: .utf8)!)
          lastCommonPath = newLastCommon
        }
      }
    }
    outputFileHandle.write("\(last)\n])\n".data(using: .utf8)!)
  }
  
  private static func fakeTargetToSwiftCode(_ fakeTarget: ParsedPackage, _ configuration: PackageGeneratorConfiguration) -> String {
    let spaces = String(repeating: " ", count: configuration.spaces)
    let localDependencies = fakeTarget.dependencies
    var dependencies = ""
    if localDependencies.isEmpty == false {
      dependencies = "\n\(spaces)\(spaces)dependencies: [\n" + localDependencies.map{ "\(spaces)\(spaces)\(spaces)\(configuration.mappers.imports[$0, default: "\"\($0)\""])" }.sorted(by: <).joined(separator: ",\n") + "\n\(spaces)\(spaces)],"
    }
    var resource = ""
    if let resourcesPath = fakeTarget.resources {
      resource = ",\n\(spaces)\(spaces)resources: [.process(\"" + resourcesPath + "/\")]"
    }
    
    let isLeaf = "// [\(fakeTarget.dependencies.count)|\(fakeTarget.localDependencies)" + (fakeTarget.hasBiggestNumberOfDependencies ? "|🚛]" : "]")
    return """
   \(spaces).target(
   \(spaces)\(spaces)name: "\(fakeTarget.name)",\(isLeaf)\(dependencies)
   \(spaces)\(spaces)path: "\(fakeTarget.path)"\(resource)
   \(spaces))
   """
  }
  
  private static func generateHeader(_ lastCommon: String, _ line: String) -> String? {
    let withoutSource = line.replacingOccurrences(of: "Sources/", with: "")
    let nbSlashes = withoutSource.count(of: "/")
    var futureLastCommon = ""
    
    if nbSlashes == 0 {
      futureLastCommon = withoutSource
    } else {
      let lastIdxSlash = withoutSource.lastIndex(of: "/")!
      let withoutLastSlash = withoutSource[..<lastIdxSlash]
      if lastCommon == withoutLastSlash { return nil }
      futureLastCommon = String(withoutLastSlash)
    }
    
    if lastCommon != futureLastCommon { return futureLastCommon }
    return nil
  }
}
