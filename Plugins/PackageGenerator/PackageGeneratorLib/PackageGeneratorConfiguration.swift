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
  var leafInfo: Bool?
  var exclusions: Exclusions
  var headerFileURL: String?
  var packageDirectories: [String]
  var targetsParameters: [String: [String]]?
  var spaces: Int
  var unusedThreshold: Int?
  var pragmaMark: Bool

  init(
    headerFileURL: String? = nil,
    packageDirectories: [String] = [],
    mappers: Mappers = Mappers(),
    exclusions: Exclusions = Exclusions(),
    verbose: Bool = false,
    dryRun: Bool = true,
    leafInfo: Bool? = nil,
    spaces: Int = 2,
    unusedThreshold: Int? = nil,
    pragmaMark: Bool = false,
    targetsParameters: [String: [String]]? = nil
  ) {
    self.mappers = mappers
    self.exclusions = exclusions
    self.headerFileURL = headerFileURL
    self.packageDirectories = packageDirectories
    self.verbose = verbose
    self.dryRun = dryRun
    self.leafInfo = leafInfo
    self.spaces = spaces
    self.unusedThreshold = unusedThreshold
    self.pragmaMark = pragmaMark
    self.targetsParameters = targetsParameters
  }
  
  // MARK: - Exclusions
  struct Exclusions: Codable {
    var imports: [String]
    var targets: [String]
    var apple: [String]
    
    
    init(apple: [String] = appleDefaultSDKs, imports: [String] = [], targets: [String] = []) {
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
}

let defaultUnusedThreshold = 1
