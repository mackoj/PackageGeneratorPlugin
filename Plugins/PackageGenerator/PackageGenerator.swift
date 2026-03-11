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
    let resolvedPackageDirectories = config.resolvedPackageDirectories
    let sanitizedPackageDirectories = sanitizePackageInformations(resolvedPackageDirectories, packageDirectory: packageDirectory)
    let normalizedPath: (String) -> String = { rawPath in
      normalizePath(rawPath, relativeTo: packageDirectory)
    }
    let excludesByPath = sanitizedPackageDirectories.reduce(into: [String: [String]]()) { acc, info in
      acc[normalizedPath(info.target.path)] = info.target.exclude ?? []
      if let testInfo = info.test {
        acc[normalizedPath(testInfo.path)] = testInfo.exclude ?? []
      }
    }
    validateConfiguration(config, configurationFileURL)
    
    logVerbose("Tool configuration: \(toolConfig)", config)
    
    /// Generate ParsedPackage
    let parsedPackageFileURL = packageTempFolder.appendingPathComponent("\(UUID().uuidString).json")
    let packagesFileURL = packageTempFolder.appendingPathComponent("\(UUID().uuidString).json")
    
    logVerbose("packagesFileURL: \(packagesFileURL.path)", config)
    logVerbose("parsedPackageFileURL: \(parsedPackageFileURL.path)", config)
    do {
      let packageDirectoriesData = try JSONEncoder().encode(sanitizedPackageDirectories)
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
    
    logVerbose("swift run package-generator-cli \(cliArguments.map { "\""+$0+"\"" }.joined(separator: " "))", config)
    
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
    parsedPackages = parsedPackages.map { parsedPackage in
      var parsedPackage = parsedPackage
      let normalizedFullPath = FileURL(fileURLWithPath: parsedPackage.fullPath).standardized.path
      if let excludes = excludesByPath[normalizedFullPath] {
        parsedPackage.exclude = excludes
      }
      return parsedPackage
    }
    
    if config.keepTempFiles == false {
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
    } else {
      logInfo("Keeping temporary files due to configuration.")
    }
    logInfo("Parsed \(parsedPackages.count) packages from package-generator-cli output.")
    
    // Clean packages
    let appleExclusions = config.exclusions.resolvedAppleExclusions
    let importExclusions = Set(config.exclusions.imports)
    parsedPackages = parsedPackages.map { parsedPackage in
      var parsedPackage = parsedPackage
      var localDependencies = parsedPackage.dependencies
      localDependencies.removeAll(where: appleExclusions.contains(_:))
      localDependencies.removeAll(where: importExclusions.contains(_:))
      localDependencies.sort(by: <)

      let mappedName = config.mappers.targets[parsedPackage.path, default: parsedPackage.name]
      let candidateNamesToFilter = Set([parsedPackage.name, mappedName])
      let removedSelfImports = localDependencies.filter { candidateNamesToFilter.contains($0) }
      if removedSelfImports.isEmpty == false {
        localDependencies.removeAll(where: { candidateNamesToFilter.contains($0) })
        logWarning("Filtered self-import(s) \(Array(Set(removedSelfImports))) for \"\(mappedName)\" at \(parsedPackage.path)")
      }

      parsedPackage.dependencies = localDependencies
      parsedPackage.name = mappedName
      if config.exclusions.targets.contains(parsedPackage.name) == false {
        parsedPackages.append(parsedPackage)
      } else {
        Diagnostics.emit(.warning, "❌ Rejecting: \(parsedPackage)")
      }
      return parsedPackage
    }
    
    // UpdateIsLeaf
    if config.leafInfo == true {
      logVerbose("Update leaf status in Packages...", config)
      parsedPackages = updateIsLeaf(config, parsedPackages)
    }
    
    if config.unusedThreshold != nil {
      updateIsUnsused(config, parsedPackages)
    }
    
    if let targetNames = config.targetsParameters?.keys, targetNames.isEmpty == false {
      let tNames = Set(targetNames)
      let parsedPackagesNames = parsedPackages.map(\.name)
      let toRemove = tNames.subtracting(parsedPackagesNames)
      if toRemove.isEmpty == false {
        for targetToRemove in toRemove {
          Diagnostics.warning("🗑️ Please consider removing \"\(targetToRemove)\" from targetsParameters configuration because this target is not found")
        }
      }
    }

    if config.verbose {
      for parsedPackage in parsedPackages {
        logVerbose("Parsed package: \(parsedPackage)", config)
      }
    }
    
    // Write Package.swift
    let outputFileName = config.dryRun ? "Package_generated.swift" : "Package.swift"
    logVerbose("Preparing \(outputFileName)...", config)
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
    
    logVerbose("Generating \(outputFileName)...", config)
    
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
    let generatedLibraryCount = parsedPackages.filter { parsedPackage in !parsedPackage.isTest }.count
    outputFileHandle.write("// MARK: - Generated \(generatedLibraryCount) packages\n\n".data(using: .utf8)!)
    
    // Write Products
    logVerbose("Generating Products...", config)
    generateProducts(parsedPackages, outputFileHandle, config)
    outputFileHandle.write("\n".data(using: .utf8)!)
    
    // Write Targets
    logVerbose("Generating Targets...", config)
    var sortedParsedPackages = parsedPackages.sorted(by: \.name, order: <)
    if config.pragmaMark {
      sortedParsedPackages = parsedPackages.sorted(by: (\.fullPath, order: <), (\.name, order: <))
    }
    generateTargets(sortedParsedPackages, outputFileHandle, config, packageDirectory)
    outputFileHandle.closeFile()
    
    // Generate exported.swift files if enabled
    if config.generateExportedFiles {
      logVerbose("Generating exported.swift files...", config)
      generateExportedFiles(parsedPackages, config, packageDirectory)
    }
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
    
    logVerbose("Configuration: \(config)", config)
    return config
  }
  
  private static func validateConfiguration(_ config: PackageGeneratorConfiguration, _ configurationFileURL: FileURL) {
    if config.headerFileURL == nil || config.headerFileURL?.fileURL.path.isEmpty == true {
      fatalError(.error, "headerFileURL in \(configurationFileURL.path) should not be empty")
    }
    if config.resolvedPackageDirectories.isEmpty {
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
        logInfo("📦 \(name) is used \(usedCount) times")
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

  private static func sanitizePackageInformations(
    _ packageInformations: [PackageInformation],
    packageDirectory: FileURL
  ) -> [PackageInformation] {
    let sourcesRoot = packageDirectory.appendingPathComponent("Sources").standardized.path
    let testsRoot = packageDirectory.appendingPathComponent("Tests").standardized.path
    let targetNames = Set(packageInformations.map { $0.target.name })
    let testNames = Set(packageInformations.compactMap { $0.test?.name })
    let testBaseNames = Set(testNames.compactMap { baseName(for: $0) })
    let sourceDirectoryMap = buildDirectoryMap(for: targetNames, under: [sourcesRoot, testsRoot])
    let testDirectoryMap = buildDirectoryMap(for: testNames.union(testBaseNames), under: [testsRoot])
    return packageInformations.map { information in
      let sanitizedTarget = sanitizePathInfo(
        information.target,
        packageDirectory: packageDirectory,
        defaultFolder: "Sources",
        directoryMap: sourceDirectoryMap,
        fallbackRoot: sourcesRoot
      )
      let sanitizedTest = information.test.map {
        sanitizePathInfo(
          $0,
          packageDirectory: packageDirectory,
          defaultFolder: "Tests",
          directoryMap: testDirectoryMap,
          fallbackRoot: testsRoot
        )
      }
      return PackageInformation(target: sanitizedTarget, test: sanitizedTest)
    }
  }

  private static func sanitizePathInfo(
    _ pathInfo: PackageInformation.PathInfo,
    packageDirectory: FileURL,
    defaultFolder: String,
    directoryMap: [String: String],
    fallbackRoot: String
  ) -> PackageInformation.PathInfo {
    let normalized = normalizePath(pathInfo.path, relativeTo: packageDirectory)
    if directoryExists(at: normalized) {
      return pathInfo.updatingPath(normalized)
    }
    if let trimmed = dropDefaultFolderIfNeeded(from: normalized, folder: defaultFolder),
       directoryExists(at: trimmed) {
      return pathInfo.updatingPath(trimmed)
    }
    if let mapped = directoryMap[pathInfo.name], directoryExists(at: mapped) {
      return pathInfo.updatingPath(mapped)
    }
    if let stripped = baseName(for: pathInfo.name),
       let mapped = directoryMap[stripped],
       directoryExists(at: mapped) {
      return pathInfo.updatingPath(mapped)
    }
    if let fallback = findDirectory(named: pathInfo.name, under: fallbackRoot) {
      return pathInfo.updatingPath(fallback)
    }
    return pathInfo.updatingPath(normalized)
  }

  private static func normalizePath(_ rawPath: String, relativeTo packageDirectory: FileURL) -> String {
    let url: FileURL
    if rawPath.hasPrefix("/") {
      url = FileURL(fileURLWithPath: rawPath)
    } else {
      url = packageDirectory.appendingPathComponent(rawPath)
    }
    return url.standardized.path
  }

  private static func dropDefaultFolderIfNeeded(from path: String, folder: String) -> String? {
    guard folder.isEmpty == false else { return nil }
    var url = URL(fileURLWithPath: path).standardized
    let targetName = url.lastPathComponent
    url.deleteLastPathComponent()
    guard url.lastPathComponent == folder else { return nil }
    url.deleteLastPathComponent()
    return url.appendingPathComponent(targetName).standardized.path
  }

  private static func directoryExists(at path: String) -> Bool {
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
  }

  private static func buildDirectoryMap(for names: Set<String>, under rootPaths: [String]) -> [String: String] {
    guard names.isEmpty == false else { return [:] }
    var map: [String: String] = [:]
    for rootPath in rootPaths {
      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: rootPath, isDirectory: &isDirectory), isDirectory.boolValue,
            let enumerator = FileManager.default.enumerator(atPath: rootPath) else {
        continue
      }
      for case let entry as String in enumerator {
        let candidate = (rootPath as NSString).appendingPathComponent(entry)
        var candidateIsDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: candidate, isDirectory: &candidateIsDir), candidateIsDir.boolValue {
          let name = URL(fileURLWithPath: candidate).lastPathComponent
          if names.contains(name), map[name] == nil {
            map[name] = FileURL(fileURLWithPath: candidate).standardized.path
          }
        }
      }
    }
    return map
  }

  private static func findDirectory(named name: String, under rootPath: String) -> String? {
    guard name.isEmpty == false else { return nil }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: rootPath, isDirectory: &isDirectory), isDirectory.boolValue,
          let enumerator = FileManager.default.enumerator(atPath: rootPath) else {
      return nil
    }
    for case let entry as String in enumerator {
      let candidate = (rootPath as NSString).appendingPathComponent(entry)
      var candidateIsDir: ObjCBool = false
      if FileManager.default.fileExists(atPath: candidate, isDirectory: &candidateIsDir), candidateIsDir.boolValue {
        if URL(fileURLWithPath: candidate).lastPathComponent == name {
          return FileURL(fileURLWithPath: candidate).standardized.path
        }
      }
    }
    return nil
  }

  private static func baseName(for name: String) -> String? {
    let suffix = "Tests"
    guard name.hasSuffix(suffix) else { return nil }
    let stripped = String(name.dropLast(suffix.count))
    return stripped.isEmpty ? nil : stripped
  }

  // MARK: Generate
  private static func generateProducts(_ parsedPackages: [ParsedPackage], _ outputFileHandle: FileHandle, _ configuration: PackageGeneratorConfiguration) {
    outputFileHandle.write("// MARK: - Targets\n".data(using: .utf8)!)
    outputFileHandle.write("package.products.append(contentsOf: [\n".data(using: .utf8)!)
    
    var last: String = ""
    for parsedPackage in parsedPackages.sorted(by: \.name, order: <) {
      if parsedPackage.isTest { continue }
      if last.isEmpty == false {
        outputFileHandle.write("\(last),\n".data(using: .utf8)!)
      }
      let name = configuration.mappers.targets[parsedPackage.path, default: parsedPackage.name]
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
    let name = fakeTarget.name + (fakeTarget.isTest ? "Tests" : "")
    let localDependencies = fakeTarget.dependencies
    var dependencies = ""
    if localDependencies.isEmpty == false {
      dependencies = "\n\(spaces)\(spaces)dependencies: [\n" + localDependencies.map{ "\(spaces)\(spaces)\(spaces)\(configuration.mappers.imports[$0, default: "\"\($0)\""])" }.sorted(by: <).joined(separator: ",\n") + "\n\(spaces)\(spaces)],"
    }

    let targetParametersList = configuration.targetsParameters?[name] ?? []
    var remainingParameters: [String] = []
    var parameterExcludes: [String] = []
    for parameter in targetParametersList {
      let trimmed = parameter.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.hasPrefix("exclude") {
        if let parsed = parseExcludeValues(from: trimmed) {
          parameterExcludes.append(contentsOf: parsed)
        }
        continue
      }
      remainingParameters.append(parameter)
    }
    let combinedExcludes = Set(fakeTarget.exclude + parameterExcludes).sorted(by: <)
    var otherParameters = ""
    if combinedExcludes.isEmpty == false {
      let formatted = combinedExcludes
        .map { "\(spaces)\(spaces)\(spaces)\"\($0)\"" }
        .joined(separator: ",\n")
      otherParameters += """
,\n\(spaces)\(spaces)exclude: [
\(formatted)
\(spaces)\(spaces)]
"""
    }
    if remainingParameters.isEmpty == false {
      otherParameters += ",\n" + remainingParameters.map { "\(spaces)\(spaces)\($0)" }.joined(separator: ",\n")
    }
    
    var isLeaf = "// [\(fakeTarget.dependencies.count)|\(fakeTarget.localDependencies)" + (fakeTarget.hasBiggestNumberOfDependencies ? "|🚛]" : "]")
    if configuration.leafInfo != true { isLeaf = "" }
    
    return """
   \(spaces).\(fakeTarget.isTest ? "testTarget" : "target")(
   \(spaces)\(spaces)name: "\(name)",\(isLeaf)\(dependencies)
   \(spaces)\(spaces)path: "\(fakeTarget.path)"\(otherParameters)
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

  // MARK: - Generate Exported Files
  private static func generateExportedFiles(_ parsedPackages: [ParsedPackage], _ configuration: PackageGeneratorConfiguration, _ packageDirectory: URL) {
    let sourcesDirectory = packageDirectory
    
    for parsedPackage in parsedPackages {
      // Skip test targets
      if parsedPackage.isTest { continue }
      
      // Only generate exported.swift for packages that have local dependencies
      if parsedPackage.dependencies.isEmpty { continue }
      
      var packagePath = sourcesDirectory.appendingPathComponent(parsedPackage.path)
      
      // Append the relative path if provided
      if let relativePath = configuration.exportedFilesRelativePath, !relativePath.isEmpty {
        packagePath = packagePath.appendingPathComponent(relativePath)
      }
      
      // Create the package directory if it doesn't exist
      do {
        try FileManager.default.createDirectory(at: packagePath, withIntermediateDirectories: true, attributes: nil)
      } catch {
        if configuration.verbose {
          Diagnostics.emit(.warning, "Failed to create directory at \(packagePath.path): \(error)")
        }
        continue
      }
      
      // Generate the content for exported.swift
      var exportedContent = "// This file is auto-generated by PackageGeneratorPlugin\n"
      exportedContent += "// It exports all local dependencies for this package\n\n"
      
      // Add @_exported import statements for each local dependency
      let sortedDependencies = parsedPackage.dependencies.sorted()
      for dependency in sortedDependencies {
        exportedContent += "@_exported import \(dependency)\n"
      }
      
      // Write the exported.swift file (or exported_generated.swift in dry run mode)
      let fileName = configuration.dryRun ? "exported_generated.swift" : "exported.swift"
      let finalExportedFileURL = packagePath.appendingPathComponent(fileName)
      
      do {
        if FileManager.default.fileExists(atPath: finalExportedFileURL.path) {
          try FileManager.default.removeItem(at: finalExportedFileURL)
        }
        try exportedContent.write(to: finalExportedFileURL, atomically: true, encoding: .utf8)
        logVerbose("Generated \(fileName) for \(parsedPackage.name) with \(sortedDependencies.count) dependencies.", configuration)
      } catch {
        Diagnostics.emit(.warning, "Failed to write \(fileName) for package \(parsedPackage.name): \(error)")
      }
    }
  }

  private static func logInfo(_ message: String) {
    print("[PackageGenerator] \(message)")
  }

  private static func logVerbose(_ message: String, _ configuration: PackageGeneratorConfiguration) {
    if configuration.verbose {
      logInfo(message)
    }
  }

  private static func logWarning(_ message: String) {
    print("[PackageGenerator WARNING] \(message)")
  }
}

private extension PackageInformation.PathInfo {
  func updatingPath(_ path: String) -> PackageInformation.PathInfo {
    PackageInformation.PathInfo(path: path, name: name, exclude: exclude)
  }
}
