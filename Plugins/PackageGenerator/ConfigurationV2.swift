import Foundation

// MARK: - VerboseMode

/// Controls which components emit verbose diagnostic output.
/// YAML accepts a string ("none" | "plugin" | "cli" | "all") or a legacy bool (true = "all", false = "none").
enum VerboseMode: Equatable {
  case none
  case plugin
  case cli
  case all
}

extension VerboseMode: Codable {
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let string = try? container.decode(String.self) {
      switch string {
      case "plugin": self = .plugin
      case "cli":    self = .cli
      case "all":    self = .all
      default:       self = .none
      }
    } else if let bool = try? container.decode(Bool.self) {
      self = bool ? .all : .none
    } else {
      self = .none
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .none:   try container.encode("none")
    case .plugin: try container.encode("plugin")
    case .cli:    try container.encode("cli")
    case .all:    try container.encode("all")
    }
  }
}

/// V2 Configuration Schema - fully normalized internal representation.
/// Supports both old (targetsParameters dict) and new (inline parameters) formats.
struct ConfigurationV2: Codable {
  // Settings
  let verbose: VerboseMode
  let dryRun: Bool
  let pragmaMark: Bool
  let generateExportedFiles: Bool
  let exportedFilesRelativePath: String?
  let headerFileURL: String?
  let spaces: Int
  let keepTempFiles: Bool
  let leafInfo: Bool
  let unusedThreshold: Int?
  // Directories and targets
  let packageDirectoryTargets: [DirectoryGroup]
  
  // Mappers for renaming
  let mappers: Mappers
  
  // Exclusions
  let exclusions: Exclusions

  // MARK: - Computed Verbose Helpers

  /// `true` when plugin-side diagnostics should be verbose (mode is `.plugin` or `.all`).
  var verbosePlugin: Bool { verbose == .plugin || verbose == .all }

  /// `true` when the CLI subprocess should run in verbose mode (mode is `.cli` or `.all`).
  var verboseCLI: Bool { verbose == .cli || verbose == .all }

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

    init(name: String, type: TargetType = .regular, path: String? = nil, exclude: [String]? = nil, parameters: [String]? = nil, regularTargetName: String? = nil) {
      self.name = name
      self.type = type
      self.path = path
      self.exclude = exclude
      self.parameters = parameters
      self.regularTargetName = regularTargetName
    }

    init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      name = try c.decode(String.self, forKey: .name)
      type = try c.decodeIfPresent(TargetType.self, forKey: .type) ?? .regular
      path = try c.decodeIfPresent(String.self, forKey: .path)
      exclude = try c.decodeIfPresent([String].self, forKey: .exclude)
      parameters = try c.decodeIfPresent([String].self, forKey: .parameters)
      regularTargetName = try c.decodeIfPresent(String.self, forKey: .regularTargetName)
    }
  }
  
  struct Mappers: Codable {
    let imports: [String: String]
    let targets: [String: String]
    
    private enum CodingKeys: String, CodingKey { case imports, targets }
    
    init(imports: [String: String] = [:], targets: [String: String] = [:]) {
      self.imports = imports
      self.targets = targets
    }
    
    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      imports = try container.decodeIfPresent([String: String].self, forKey: .imports) ?? [:]
      targets = try container.decodeIfPresent([String: String].self, forKey: .targets) ?? [:]
    }
  }
  
  struct Exclusions: Codable {
    let imports: [String]
    let targets: [String]
    
    private enum CodingKeys: String, CodingKey { case imports, targets }
    
    init(imports: [String] = [], targets: [String] = []) {
      self.imports = imports
      self.targets = targets
    }
    
    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      imports = try container.decodeIfPresent([String].self, forKey: .imports) ?? []
      targets = try container.decodeIfPresent([String].self, forKey: .targets) ?? []
    }
  }
  
  // MARK: - Initialization
  
  init(
    verbose: VerboseMode = .none,
    dryRun: Bool = false,
    pragmaMark: Bool = false,
    generateExportedFiles: Bool = false,
    exportedFilesRelativePath: String? = nil,
    headerFileURL: String? = nil,
    spaces: Int = 2,
    keepTempFiles: Bool = false,
    leafInfo: Bool = false,
    unusedThreshold: Int? = nil,
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
    case packageDirectoryTargets
    case mappers
    case exclusions
    case targetsParameters // Legacy: migrated in-memory
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.verbose = try container.decodeIfPresent(VerboseMode.self, forKey: .verbose) ?? .none
    self.dryRun = try container.decodeIfPresent(Bool.self, forKey: .dryRun) ?? false
    self.pragmaMark = try container.decodeIfPresent(Bool.self, forKey: .pragmaMark) ?? false
    self.generateExportedFiles = try container.decodeIfPresent(Bool.self, forKey: .generateExportedFiles) ?? false
    self.exportedFilesRelativePath = try container.decodeIfPresent(String.self, forKey: .exportedFilesRelativePath)
    self.headerFileURL = try container.decodeIfPresent(String.self, forKey: .headerFileURL)
    self.spaces = try container.decodeIfPresent(Int.self, forKey: .spaces) ?? 2
    self.keepTempFiles = try container.decodeIfPresent(Bool.self, forKey: .keepTempFiles) ?? false
    self.leafInfo = try container.decodeIfPresent(Bool.self, forKey: .leafInfo) ?? false
    self.unusedThreshold = try container.decodeIfPresent(Int.self, forKey: .unusedThreshold)
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
    try container.encode(packageDirectoryTargets, forKey: .packageDirectoryTargets)
    try container.encode(mappers, forKey: .mappers)
    try container.encode(exclusions, forKey: .exclusions)
  }
}
