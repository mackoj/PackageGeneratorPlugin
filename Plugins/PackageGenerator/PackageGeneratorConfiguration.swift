import Foundation

public struct PackageGeneratorConfiguration: Codable {
  public var mappers: Mappers
  public var verbose: Bool
  public var dryRun: Bool
  public var leafInfo: Bool
  public var exclusions: Exclusions
  public var headerFileURL: FileURL?
  public var packageDirectories: [FileURL]
  public var checkIfThereIsCommitToDo: Bool
  
  public init(
    headerFileURL: FileURL? = nil,
    packageDirectories: [FileURL] = [],
    checkIfThereIsCommitToDo: Bool = true,
    mappers: Mappers = Mappers(),
    exclusions: Exclusions = Exclusions(),
    verbose: Bool = false,
    dryRun: Bool = true,
    leafInfo: Bool = false
  ) {
    self.mappers = mappers
    self.exclusions = exclusions
    self.headerFileURL = headerFileURL
    self.packageDirectories = packageDirectories
    self.checkIfThereIsCommitToDo = checkIfThereIsCommitToDo
    self.verbose = verbose
    self.dryRun = dryRun
    self.leafInfo = leafInfo
  }
  
  // MARK: - Exclusions
  public struct Exclusions: Codable {
    public var imports: [String]
    public var targets: [String]
    public var apple: [String]
    
    
    public init(apple: [String] = [], imports: [String] = [], targets: [String] = []) {
      self.imports = imports
      self.targets = targets
      self.apple = apple
    }
  }
  
  // MARK: - Mappers
  public struct Mappers: Codable {
    public var imports: [String: String]
    public var targets: [String: String]
    
    public init(imports: [String: String] = [:], targets: [String: String] = [:]) {
      self.imports = imports
      self.targets = targets
    }
  }
}
