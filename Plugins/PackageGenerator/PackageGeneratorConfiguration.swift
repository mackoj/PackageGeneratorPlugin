import Foundation

extension String {
  var fileURL: FileURL {
    URL(fileURLWithPath: self)
  }
}

struct PackageGeneratorConfiguration: Codable {
  var mappers: Mappers
  var verbose: Bool
  var dryRun: Bool
  var keepTempFiles: Bool?
  var leafInfo: Bool?
  var exclusions: Exclusions
  var headerFileURL: String?
  var packageDirectories: [PackageDirectoryEntry]
  var packageDirectoryTargets: [PackageDirectoryTargets]
  var targetsParameters: [String: [String]]?
  var spaces: Int
  var unusedThreshold: Int?
  var pragmaMark: Bool
  var generateExportedFiles: Bool
  var exportedFilesRelativePath: String?

  init(
    headerFileURL: String? = nil,
    packageDirectories: [PackageDirectoryEntry] = [],
    packageDirectoryTargets: [PackageDirectoryTargets] = [],
    mappers: Mappers = Mappers(),
    exclusions: Exclusions = Exclusions(),
    verbose: Bool = false,
    dryRun: Bool = true,
    keepTempFiles: Bool = false,
    leafInfo: Bool? = nil,
    spaces: Int = 2,
    unusedThreshold: Int? = nil,
    pragmaMark: Bool = false,
    targetsParameters: [String: [String]]? = nil,
    generateExportedFiles: Bool = false,
    exportedFilesRelativePath: String? = nil
  ) {
    self.mappers = mappers
    self.exclusions = exclusions
    self.headerFileURL = headerFileURL
    self.packageDirectories = packageDirectories
    self.packageDirectoryTargets = packageDirectoryTargets
    self.verbose = verbose
    self.dryRun = dryRun
    self.keepTempFiles = keepTempFiles
    self.leafInfo = leafInfo
    self.spaces = spaces
    self.unusedThreshold = unusedThreshold
    self.pragmaMark = pragmaMark
    self.targetsParameters = targetsParameters
    self.generateExportedFiles = generateExportedFiles
    self.exportedFilesRelativePath = exportedFilesRelativePath
  }

  enum CodingKeys: String, CodingKey {
    case mappers
    case verbose
    case dryRun
    case keepTempFiles
    case leafInfo
    case exclusions
    case headerFileURL
    case packageDirectories
    case packageDirectoryTargets
    case targetsParameters
    case spaces
    case unusedThreshold
    case pragmaMark
    case generateExportedFiles
    case exportedFilesRelativePath
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.mappers = try container.decodeIfPresent(Mappers.self, forKey: .mappers) ?? Mappers()
    self.verbose = try container.decodeIfPresent(Bool.self, forKey: .verbose) ?? false
    self.dryRun = try container.decodeIfPresent(Bool.self, forKey: .dryRun) ?? true
    self.keepTempFiles = try container.decodeIfPresent(Bool.self, forKey: .keepTempFiles)
    self.leafInfo = try container.decodeIfPresent(Bool.self, forKey: .leafInfo)
    self.exclusions = try container.decodeIfPresent(Exclusions.self, forKey: .exclusions) ?? Exclusions()
    self.headerFileURL = try container.decodeIfPresent(String.self, forKey: .headerFileURL)
    self.packageDirectories = try container.decodeIfPresent([PackageDirectoryEntry].self, forKey: .packageDirectories) ?? []
    self.packageDirectoryTargets = try container.decodeIfPresent([PackageDirectoryTargets].self, forKey: .packageDirectoryTargets) ?? []
    self.targetsParameters = try container.decodeIfPresent([String: [String]].self, forKey: .targetsParameters)
    self.spaces = try container.decodeIfPresent(Int.self, forKey: .spaces) ?? 2
    self.unusedThreshold = try container.decodeIfPresent(Int.self, forKey: .unusedThreshold)
    self.pragmaMark = try container.decodeIfPresent(Bool.self, forKey: .pragmaMark) ?? false
    self.generateExportedFiles = try container.decodeIfPresent(Bool.self, forKey: .generateExportedFiles) ?? false
    self.exportedFilesRelativePath = try container.decodeIfPresent(String.self, forKey: .exportedFilesRelativePath)
  }

  // MARK: - Exclusions
  struct Exclusions: Codable {
    var imports: [String]
    var targets: [String]
    var apple: [String]

    var resolvedAppleExclusions: Set<String> {
      Set(appleDefaultSDKs + apple)
    }

    init(apple: [String] = [], imports: [String] = [], targets: [String] = []) {
      self.imports = imports
      self.targets = targets
      self.apple = apple
    }
  }
  
  // MARK: - Mappers
  struct Mappers: Codable {
    var imports: [String: String]
    var targets: [String: String]
    
    init(imports: [String: String] = [:], targets: [String: String] = [:]) {
      self.imports = imports
      self.targets = targets
    }
  }

  struct PackageDirectoryTargets: Codable {
    struct Target: Codable {
      enum TargetType: String, Codable {
        case regular
        case test
        
        var defaultFolder: String {
          switch self {
          case .regular:
            return "Sources"
          case .test:
            return "Tests"
          }
        }
      }

      let name: String
      let type: TargetType
      let path: String?
      let regularTargetName: String?
      let exclude: [String]?
    }

    let path: String
    let targets: [Target]

    func targetPath(for target: Target) -> String {
      if let override = target.path, override.isEmpty == false {
        if override.hasPrefix("/") {
          return override
        }
        return (path as NSString).appendingPathComponent(override)
      }

      let folder = target.type.defaultFolder
      let base = (path as NSString).appendingPathComponent(folder)
      return (base as NSString).appendingPathComponent(target.name)
    }

    func regularTargetName(for testTarget: Target) -> String? {
      guard testTarget.type == .test else { return nil }
      if let explicit = testTarget.regularTargetName, explicit.isEmpty == false {
        return explicit
      }
      let suffix = "Tests"
      guard testTarget.name.hasSuffix(suffix) else { return nil }
      return String(testTarget.name.dropLast(suffix.count))
    }
  }

  enum PackageDirectoryEntry: Codable {
    case legacy(PackageInformation)
    case directoryTargets(PackageDirectoryTargets)

    var packageInformations: [PackageInformation] {
      switch self {
      case .legacy(let info):
        return [info]
      case .directoryTargets(let targets):
        return targets.packageInformations()
      }
    }

    init(from decoder: Decoder) throws {
      if let targets = try? PackageDirectoryTargets(from: decoder) {
        self = .directoryTargets(targets)
        return
      }
      let info = try PackageInformation(from: decoder)
      self = .legacy(info)
    }

    func encode(to encoder: Encoder) throws {
      switch self {
      case .legacy(let info):
        try info.encode(to: encoder)
      case .directoryTargets(let targets):
        try targets.encode(to: encoder)
      }
    }
  }
}

let defaultUnusedThreshold = 1

extension PackageGeneratorConfiguration {
  var resolvedPackageDirectories: [PackageInformation] {
    var directories = packageDirectories.flatMap { $0.packageInformations }
    directories.append(contentsOf: packageDirectoryTargets.flatMap { $0.packageInformations() })
    return directories.map { $0.withResolvedExcludes(using: self) }
  }

  fileprivate func pathInfoWithResolvedExcludes(for info: PackageInformation.PathInfo) -> PackageInformation.PathInfo {
    let combined = combinedExcludes(for: info)
    return PackageInformation.PathInfo(path: info.path, name: info.name, exclude: combined)
  }

  private func combinedExcludes(for info: PackageInformation.PathInfo) -> [String]? {
    var excludes = Set(info.exclude ?? [])
    if let parameterExcludes = excludeValues(from: targetsParameters?[info.name]) {
      excludes.formUnion(parameterExcludes)
    }
    return excludes.isEmpty ? nil : excludes.sorted()
  }

  private func excludeValues(from parameters: [String]?) -> [String]? {
    guard let parameters else { return nil }
    var result: [String] = []
    for parameter in parameters {
      let trimmed = parameter.trimmingCharacters(in: .whitespacesAndNewlines)
      guard trimmed.hasPrefix("exclude"), let parsed = parseExcludeValues(from: trimmed) else { continue }
      result.append(contentsOf: parsed)
    }
    return result.isEmpty ? nil : result
  }
}

extension PackageGeneratorConfiguration.PackageDirectoryTargets {
  func packageInformations() -> [PackageInformation] {
    var mappedTests: [String: Target] = [:]
    for target in targets where target.type == .test {
      if let regularName = regularTargetName(for: target) {
        mappedTests[regularName] = target
      }
    }

    return targets
      .filter { $0.type == .regular }
      .map { regular -> PackageInformation in
        let targetInfo = PackageInformation.PathInfo(
          path: targetPath(for: regular),
          name: regular.name,
          exclude: regular.exclude
        )
        let testInfo = mappedTests[regular.name].map { test -> PackageInformation.PathInfo in
          PackageInformation.PathInfo(
            path: targetPath(for: test),
            name: test.name,
            exclude: test.exclude
          )
        }
        return PackageInformation(target: targetInfo, test: testInfo)
      }
  }
}

private extension PackageInformation {
  func withResolvedExcludes(using configuration: PackageGeneratorConfiguration) -> PackageInformation {
    let targetInfo = configuration.pathInfoWithResolvedExcludes(for: target)
    let testInfo = test.map { configuration.pathInfoWithResolvedExcludes(for: $0) }
    return PackageInformation(target: targetInfo, test: testInfo)
  }
}
