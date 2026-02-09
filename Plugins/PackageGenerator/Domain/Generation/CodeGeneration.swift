import Foundation

// MARK: - Target Generation

/// Generate Swift code for a single target
func generateTargetCode(
  package: Package,
  config: Configuration,
  importMappings: [String: Configuration.Mapping.ImportMapping]
) -> String {
  let indent = config.output.formatting.indentation.string()
  let indent2 = config.output.formatting.indentation.string(count: 2)
  let indent3 = config.output.formatting.indentation.string(count: 3)
  
  let targetType = package.kind.isTest ? "testTarget" : "target"
  let targetName = package.name + (package.kind.isTest ? "Tests" : "")
  
  // Generate leaf info comment if enabled
  let leafInfo = config.features.leafInfo
    ? " // [\(package.dependencies.count)|\(package.metadata.localDependencyCount)" +
      (package.metadata.hasBiggestNumberOfDependencies ? "|🚛]" : "]")
    : ""
  
  // Generate dependencies
  let dependenciesCode = generateDependenciesCode(
    dependencies: Array(package.dependencies).sorted(),
    importMappings: importMappings,
    indent: indent3
  )
  
  // Generate target parameters
  let parametersCode = generateTargetParameters(
    targetName: targetName,
    parameters: config.features.targetParameters[targetName] ?? [],
    indent: indent2
  )
  
  return """
  \(indent).\(targetType)(
  \(indent2)name: "\(targetName)",\(leafInfo)\(dependenciesCode)
  \(indent2)path: "\(package.path)"\(parametersCode)
  \(indent))
  """
}

/// Generate dependencies array code
func generateDependenciesCode(
  dependencies: [String],
  importMappings: [String: Configuration.Mapping.ImportMapping],
  indent: String
) -> String {
  guard !dependencies.isEmpty else { return "" }
  
  let mappedDeps = dependencies.map { dep in
    importMappings[dep]?.swiftCode ?? "\"\(dep)\""
  }
  
  let depsString = mappedDeps
    .map { "\(indent)\($0)" }
    .joined(separator: ",\n")
  
  let indent2 = String(indent.dropLast(indent.count / 3 * 2))
  
  return """
  
  \(indent2)dependencies: [
  \(depsString)
  \(indent2)],
  """
}

/// Generate target parameters code
func generateTargetParameters(
  targetName: String,
  parameters: [String],
  indent: String
) -> String {
  guard !parameters.isEmpty else { return "" }
  
  return ",\n" + parameters
    .map { "\(indent)\($0)" }
    .joined(separator: ",\n")
}

// MARK: - Pragma Mark Generation

/// Generate pragma mark comments for sections
func generatePragmaMarks(
  packages: [Package],
  sourceRoot: FilePath
) -> [(index: Int, mark: String)] {
  var lastCommonPath = ""
  var marks: [(Int, String)] = []
  
  for (index, package) in packages.enumerated() {
    if let mark = generateMarkForPackage(
      package: package,
      lastCommonPath: &lastCommonPath,
      sourceRoot: sourceRoot
    ) {
      marks.append((index, mark))
    }
  }
  
  return marks
}

func generateMarkForPackage(
  package: Package,
  lastCommonPath: inout String,
  sourceRoot: FilePath
) -> String? {
  let relativePath = package.fullPath
    .replacingOccurrences(of: "Sources/", with: "")
  
  let slashCount = relativePath.filter { $0 == "/" }.count
  
  let futureLastCommon: String
  if slashCount == 0 {
    futureLastCommon = relativePath
  } else {
    guard let lastSlashIndex = relativePath.lastIndex(of: "/") else {
      return nil
    }
    let withoutLastSlash = String(relativePath[..<lastSlashIndex])
    futureLastCommon = withoutLastSlash
  }
  
  guard lastCommonPath != futureLastCommon else {
    return nil
  }
  
  lastCommonPath = futureLastCommon
  return futureLastCommon
}

// MARK: - Products Generation

/// Generate products array code
func generateProductsCode(packages: [Package], config: Configuration) -> String {
  let indent = config.output.formatting.indentation.string()
  let indent2 = config.output.formatting.indentation.string(count: 2)
  
  let nonTestPackages = packages
    .filter { !$0.kind.isTest }
    .sorted { $0.name < $1.name }
  
  let productLines = nonTestPackages.map { package in
    "\(indent).library(name: \"\(package.name)\", targets: [\"\(package.name)\"])"
  }
  
  return """
  // MARK: - Products
  package.products.append(contentsOf: [
  \(productLines.joined(separator: ",\n"))
  ])
  
  """
}

// MARK: - Targets Generation

/// Generate complete targets section
func generateTargetsCode(packages: [Package], config: Configuration) -> String {
  let indent = config.output.formatting.indentation.string()
  
  // Sort packages appropriately
  let sortedPackages = config.output.formatting.pragmaMarks
    ? sortPackagesByPath(packages)
    : sortPackagesByName(packages)
  
  // Generate pragma marks if enabled
  let marks = config.output.formatting.pragmaMarks
    ? generatePragmaMarks(packages: sortedPackages, sourceRoot: "Sources")
    : []
  
  // Generate target code for each package
  var targetCodes: [(index: Int, code: String)] = []
  for (index, package) in sortedPackages.enumerated() {
    let code = generateTargetCode(
      package: package,
      config: config,
      importMappings: config.mapping.imports
    )
    targetCodes.append((index, code))
  }
  
  // Interleave pragma marks with target codes
  var result: [String] = []
  var markIndex = 0
  
  for (index, code) in targetCodes {
    // Insert pragma mark if needed
    while markIndex < marks.count && marks[markIndex].index == index {
      result.append("// MARK: -")
      result.append("// MARK: \(marks[markIndex].mark)")
      markIndex += 1
    }
    
    result.append(code)
  }
  
  let targetsBody = result.joined(separator: ",\n")
  
  return """
  // MARK: - Targets
  package.targets.append(contentsOf: [
  \(targetsBody)
  ])
  """
}

// MARK: - Exported Files Generation

/// Generate exported.swift file content for a package
func generateExportedFileContent(
  package: Package,
  localDependencies: Set<String>
) -> String {
  guard !localDependencies.isEmpty else {
    return """
    // This file is auto-generated by PackageGeneratorPlugin
    // No local dependencies to export
    """
  }
  
  let exports = localDependencies
    .sorted()
    .map { "@_exported import \($0)" }
    .joined(separator: "\n")
  
  return """
  // This file is auto-generated by PackageGeneratorPlugin
  // It exports all local dependencies for this package
  
  \(exports)
  """
}

/// Determine the path for an exported file
func exportedFilePath(
  packagePath: String,
  relativePath: FilePath?,
  isDryRun: Bool
) -> FilePath {
  let fileName = isDryRun ? "exported_generated.swift" : "exported.swift"
  let basePath = FilePath(packagePath)
  
  if let relative = relativePath {
    return basePath.appending(relative.rawValue).appending(fileName)
  } else {
    return basePath.appending(fileName)
  }
}

// MARK: - Complete Package.swift Generation

/// Generate the complete Package.swift file content
func generatePackageSwiftContent(
  header: String,
  packages: [Package],
  config: Configuration
) -> String {
  let packageCount = packages.count
  
  return """
  \(header)// MARK: - Generated \(packageCount) packages
  
  \(generateProductsCode(packages: packages, config: config))
  \(generateTargetsCode(packages: packages, config: config))
  """
}
