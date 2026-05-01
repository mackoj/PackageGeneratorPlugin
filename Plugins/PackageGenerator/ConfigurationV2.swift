import Foundation

/// V2 Configuration Schema - fully normalized internal representation.
/// Supports both old (targetsParameters dict) and new (inline parameters) formats.
struct ConfigurationV2: Codable {
  // Settings
  let verbose: Bool
  let dryRun: Bool
  let pragmaMark: Bool
  let generateExportedFiles: Bool
  let exportedFilesRelativePath: String?
  let headerFileURL: String?
  let spaces: Int
  let keepTempFiles: Bool
  let leafInfo: Bool
  let unusedThreshold: Int?
  let silenceUnresolvedImportWarnings: Bool
  
  // Directories and targets
  let packageDirectoryTargets: [DirectoryGroup]
  
  // Mappers for renaming
  let mappers: Mappers
  
  // Exclusions
  let exclusions: Exclusions
  
  // MARK: - Nested Types
  
  struct DirectoryGroup: Codable {
    let path: String
    let targets: [TargetSpec]
  }
  
  struct TargetSpec: Codable {
    let name: String
    let type: TargetType
    let path: String?
    let exclude: [String]?
    let parameters: [String]?
    let regularTargetName: String?
    
    enum TargetType: String, Codable {
      case regular
      case test
      case macro
      
      var defaultFolder: String {
        switch self {
        case .regular, .macro: return "Sources"
        case .test: return "Tests"
        }
      }
    }
  }
  
  struct Mappers: Codable {
    let imports: [String: String]
    let targets: [String: String]
    
    init(imports: [String: String] = [:], targets: [String: String] = [:]) {
      self.imports = imports
      self.targets = targets
    }
  }
  
  struct Exclusions: Codable {
    let apple: [String]
    let imports: [String]
    let targets: [String]
    
    var resolvedAppleExclusions: Set<String> {
      Set(appleDefaultSDKs + apple)
    }
    
    init(apple: [String] = [], imports: [String] = [], targets: [String] = []) {
      self.apple = apple
      self.imports = imports
      self.targets = targets
    }
  }
  
  // MARK: - Initialization
  
  init(
    verbose: Bool = false,
    dryRun: Bool = true,
    pragmaMark: Bool = false,
    generateExportedFiles: Bool = false,
    exportedFilesRelativePath: String? = nil,
    headerFileURL: String? = nil,
    spaces: Int = 2,
    keepTempFiles: Bool = false,
    leafInfo: Bool = false,
    unusedThreshold: Int? = nil,
    silenceUnresolvedImportWarnings: Bool = false,
    packageDirectoryTargets: [DirectoryGroup] = [],
    mappers: Mappers = Mappers(),
    exclusions: Exclusions = Exclusions()
  ) {
    self.verbose = verbose
    self.dryRun = dryRun
    self.pragmaMark = pragmaMark
    self.generateExportedFiles = generateExportedFiles
    self.exportedFilesRelativePath = exportedFilesRelativePath
    self.headerFileURL = headerFileURL
    self.spaces = spaces
    self.keepTempFiles = keepTempFiles
    self.leafInfo = leafInfo
    self.unusedThreshold = unusedThreshold
    self.silenceUnresolvedImportWarnings = silenceUnresolvedImportWarnings
    self.packageDirectoryTargets = packageDirectoryTargets
    self.mappers = mappers
    self.exclusions = exclusions
  }
  
  // MARK: - Codable (supports both old & new formats)
  
  enum CodingKeys: String, CodingKey {
    case verbose
    case dryRun
    case pragmaMark
    case generateExportedFiles
    case exportedFilesRelativePath
    case headerFileURL
    case spaces
    case keepTempFiles
    case leafInfo
    case unusedThreshold
    case silenceUnresolvedImportWarnings
    case packageDirectoryTargets
    case mappers
    case exclusions
    case targetsParameters // Legacy: migrated in-memory
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.verbose = try container.decodeIfPresent(Bool.self, forKey: .verbose) ?? false
    self.dryRun = try container.decodeIfPresent(Bool.self, forKey: .dryRun) ?? true
    self.pragmaMark = try container.decodeIfPresent(Bool.self, forKey: .pragmaMark) ?? false
    self.generateExportedFiles = try container.decodeIfPresent(Bool.self, forKey: .generateExportedFiles) ?? false
    self.exportedFilesRelativePath = try container.decodeIfPresent(String.self, forKey: .exportedFilesRelativePath)
    self.headerFileURL = try container.decodeIfPresent(String.self, forKey: .headerFileURL)
    self.spaces = try container.decodeIfPresent(Int.self, forKey: .spaces) ?? 2
    self.keepTempFiles = try container.decodeIfPresent(Bool.self, forKey: .keepTempFiles) ?? false
    self.leafInfo = try container.decodeIfPresent(Bool.self, forKey: .leafInfo) ?? false
    self.unusedThreshold = try container.decodeIfPresent(Int.self, forKey: .unusedThreshold)
    self.silenceUnresolvedImportWarnings = try container.decodeIfPresent(Bool.self, forKey: .silenceUnresolvedImportWarnings) ?? false
    self.mappers = try container.decodeIfPresent(Mappers.self, forKey: .mappers) ?? Mappers()
    self.exclusions = try container.decodeIfPresent(Exclusions.self, forKey: .exclusions) ?? Exclusions()
    
    // Decode directory targets, applying legacy targetsParameters if present
    var groups = try container.decodeIfPresent([DirectoryGroup].self, forKey: .packageDirectoryTargets) ?? []
    let legacyParams = try container.decodeIfPresent([String: [String]].self, forKey: .targetsParameters)
    
    if let legacy = legacyParams {
      // Merge legacy targetsParameters into inline parameters
      groups = groups.map { group in
        let updatedTargets = group.targets.map { target -> TargetSpec in
          if let legacyParamsForTarget = legacy[target.name] {
            let merged = ((target.parameters ?? []) + legacyParamsForTarget)
            return TargetSpec(
              name: target.name,
              type: target.type,
              path: target.path,
              exclude: target.exclude,
              parameters: merged.isEmpty ? nil : merged,
              regularTargetName: target.regularTargetName
            )
          }
          return target
        }
        return DirectoryGroup(path: group.path, targets: updatedTargets)
      }
    }
    
    self.packageDirectoryTargets = groups
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(verbose, forKey: .verbose)
    try container.encode(dryRun, forKey: .dryRun)
    try container.encode(pragmaMark, forKey: .pragmaMark)
    try container.encode(generateExportedFiles, forKey: .generateExportedFiles)
    try container.encodeIfPresent(exportedFilesRelativePath, forKey: .exportedFilesRelativePath)
    try container.encodeIfPresent(headerFileURL, forKey: .headerFileURL)
    try container.encode(spaces, forKey: .spaces)
    try container.encode(keepTempFiles, forKey: .keepTempFiles)
    try container.encode(leafInfo, forKey: .leafInfo)
    try container.encodeIfPresent(unusedThreshold, forKey: .unusedThreshold)
    try container.encode(silenceUnresolvedImportWarnings, forKey: .silenceUnresolvedImportWarnings)
    try container.encode(packageDirectoryTargets, forKey: .packageDirectoryTargets)
    try container.encode(mappers, forKey: .mappers)
    try container.encode(exclusions, forKey: .exclusions)
  }
}
