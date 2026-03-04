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
  var packageDirectories: [PackageInformation]
  var packageDirectoryTargets: [PackageDirectoryTargets]
  var targetsParameters: [String: [String]]?
  var spaces: Int
  var unusedThreshold: Int?
  var pragmaMark: Bool
  var generateExportedFiles: Bool
  var exportedFilesRelativePath: String?

  init(
    headerFileURL: String? = nil,
    packageDirectories: [PackageInformation] = [],
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
    }

    let path: String
    let targets: [Target]

    func targetPath(for target: Target) -> String {
      if let override = target.path, override.isEmpty == false {
        return override
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
}

let defaultUnusedThreshold = 1

extension PackageGeneratorConfiguration {
  var resolvedPackageDirectories: [PackageInformation] {
    var directories = packageDirectories
    directories.append(contentsOf: packageDirectoryTargets.flatMap { $0.packageInformations() })
    return directories
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
          name: regular.name
        )
        let testInfo = mappedTests[regular.name].map { test -> PackageInformation.PathInfo in
          PackageInformation.PathInfo(
            path: targetPath(for: test),
            name: test.name
          )
        }
        return PackageInformation(target: targetInfo, test: testInfo)
      }
  }
}
