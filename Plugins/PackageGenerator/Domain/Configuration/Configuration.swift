import Foundation

// MARK: - Main Configuration

/// The complete configuration for the Package Generator plugin
struct Configuration: Codable, Equatable {
  let source: Source
  let output: Output
  let mapping: Mapping
  let exclusion: Exclusion
  let features: Features
  let verbose: Bool
  
  init(
    source: Source,
    output: Output = .init(),
    mapping: Mapping = .init(),
    exclusion: Exclusion = .init(),
    features: Features = .init(),
    verbose: Bool = false
  ) {
    self.source = source
    self.output = output
    self.mapping = mapping
    self.exclusion = exclusion
    self.features = features
    self.verbose = verbose
  }
}

// MARK: - Source Configuration

extension Configuration {
  /// Defines where to find source code and header files
  struct Source: Codable, Equatable {
    let packageDirectories: NonEmptyArray<PackageDirectory>
    let headerFile: FilePath
    
    init(packageDirectories: NonEmptyArray<PackageDirectory>, headerFile: FilePath) {
      self.packageDirectories = packageDirectories
      self.headerFile = headerFile
    }
  }
  
  /// Represents a package directory with optional test target
  struct PackageDirectory: Codable, Equatable, Hashable {
    let target: TargetInfo
    let test: TargetInfo?
    
    init(target: TargetInfo, test: TargetInfo? = nil) {
      self.target = target
      self.test = test
    }
    
    /// For simple string paths (backward compatibility)
    init(path: String) {
      self.target = TargetInfo(
        path: path,
        name: URL(fileURLWithPath: path).lastPathComponent
      )
      self.test = nil
    }
    
    struct TargetInfo: Codable, Equatable, Hashable {
      let path: String
      let name: String
    }
  }
}

// MARK: - Decodable Support for Legacy Format
extension Configuration.PackageDirectory {
  init(from decoder: Decoder) throws {
    // Try legacy string format first
    let stringContainer = try decoder.singleValueContainer()
    if let pathString = try? stringContainer.decode(String.self) {
      self.init(path: pathString)
      return
    }
    
    // Fall back to structured format
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.target = try container.decode(TargetInfo.self, forKey: .target)
    self.test = try container.decodeIfPresent(TargetInfo.self, forKey: .test)
  }
}

// MARK: - Output Configuration

extension Configuration {
  /// Defines how and where to write output
  struct Output: Codable, Equatable {
    let mode: Mode
    let formatting: Formatting
    
    init(
      mode: Mode = .dryRun(),
      formatting: Formatting = .init()
    ) {
      self.mode = mode
      self.formatting = formatting
    }
    
    enum Mode: Codable, Equatable {
      case dryRun(fileName: String = "Package_generated.swift")
      case live(fileName: String = "Package.swift")
      
      var isDryRun: Bool {
        if case .dryRun = self { return true }
        return false
      }
      
      var fileName: String {
        switch self {
        case .dryRun(let name): return name
        case .live(let name): return name
        }
      }
    }
    
    struct Formatting: Codable, Equatable {
      let indentation: Indentation
      let pragmaMarks: Bool
      
      init(
        indentation: Indentation = .spaces(2),
        pragmaMarks: Bool = false
      ) {
        self.indentation = indentation
        self.pragmaMarks = pragmaMarks
      }
      
      enum Indentation: Codable, Equatable {
        case spaces(Int)
        case tabs
        
        func string(count: Int = 1) -> String {
          switch self {
          case .spaces(let n):
            return String(repeating: " ", count: n * count)
          case .tabs:
            return String(repeating: "\t", count: count)
          }
        }
      }
    }
  }
}

// MARK: - Custom Codable for Mode
extension Configuration.Output.Mode {
  enum CodingKeys: String, CodingKey {
    case type
    case fileName
  }
  
  init(from decoder: Decoder) throws {
    // Try simple string format
    let stringContainer = try decoder.singleValueContainer()
    if let string = try? stringContainer.decode(String.self) {
      switch string.lowercased() {
      case "dryrun", "dry-run", "dry_run":
        self = .dryRun()
      case "live":
        self = .live()
      default:
        throw DecodingError.dataCorruptedError(
          in: stringContainer,
          debugDescription: "Invalid mode: \(string)"
        )
      }
      return
    }
    
    // Try structured format
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    let fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
    
    switch type.lowercased() {
    case "dryrun", "dry-run", "dry_run":
      self = .dryRun(fileName: fileName ?? "Package_generated.swift")
    case "live":
      self = .live(fileName: fileName ?? "Package.swift")
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type,
        in: container,
        debugDescription: "Invalid mode type: \(type)"
      )
    }
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .dryRun(let fileName):
      try container.encode("dryRun", forKey: .type)
      try container.encode(fileName, forKey: .fileName)
    case .live(let fileName):
      try container.encode("live", forKey: .type)
      try container.encode(fileName, forKey: .fileName)
    }
  }
}

// MARK: - Custom Codable for Indentation
extension Configuration.Output.Formatting.Indentation {
  enum CodingKeys: String, CodingKey {
    case type
    case count
  }
  
  init(from decoder: Decoder) throws {
    // Try simple integer (assume spaces)
    let intContainer = try decoder.singleValueContainer()
    if let count = try? intContainer.decode(Int.self) {
      self = .spaces(count)
      return
    }
    
    // Try structured format
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    
    switch type.lowercased() {
    case "spaces":
      let count = try container.decode(Int.self, forKey: .count)
      self = .spaces(count)
    case "tabs":
      self = .tabs
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type,
        in: container,
        debugDescription: "Invalid indentation type: \(type)"
      )
    }
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .spaces(let count):
      try container.encode("spaces", forKey: .type)
      try container.encode(count, forKey: .count)
    case .tabs:
      try container.encode("tabs", forKey: .type)
    }
  }
}

// MARK: - Mapping Configuration

extension Configuration {
  /// Defines how to map target names and import statements
  struct Mapping: Codable, Equatable {
    let targets: [String: String]
    let imports: [String: ImportMapping]
    
    init(
      targets: [String: String] = [:],
      imports: [String: ImportMapping] = [:]
    ) {
      self.targets = targets
      self.imports = imports
    }
    
    enum ImportMapping: Codable, Equatable {
      case simple(String)
      case product(name: String, package: String)
      
      var swiftCode: String {
        switch self {
        case .simple(let name):
          return "\"\(name)\""
        case .product(let name, let package):
          return ".product(name: \"\(name)\", package: \"\(package)\")"
        }
      }
    }
  }
}

// MARK: - Custom Codable for ImportMapping
extension Configuration.Mapping.ImportMapping {
  init(from decoder: Decoder) throws {
    // Try simple string
    let stringContainer = try decoder.singleValueContainer()
    if let string = try? stringContainer.decode(String.self) {
      // Check if it's already a .product() format
      if string.hasPrefix(".product(") {
        self = .simple(string)
      } else {
        self = .simple("\"\(string)\"")
      }
      return
    }
    
    // Try structured format
    enum CodingKeys: String, CodingKey {
      case product, package
    }
    
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let product = try container.decode(String.self, forKey: .product)
    let package = try container.decode(String.self, forKey: .package)
    self = .product(name: product, package: package)
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(swiftCode)
  }
}

// MARK: - Exclusion Configuration

extension Configuration {
  /// Defines what to exclude from generation
  struct Exclusion: Codable, Equatable {
    let apple: AppleSDKs
    let imports: Set<String>
    let targets: Set<String>
    
    init(
      apple: AppleSDKs = .default,
      imports: Set<String> = [],
      targets: Set<String> = []
    ) {
      self.apple = apple
      self.imports = imports
      self.targets = targets
    }
    
    enum AppleSDKs: Codable, Equatable {
      case `default`
      case custom(Set<String>)
      
      var sdks: Set<String> {
        switch self {
        case .default:
          return Set(appleDefaultSDKs)
        case .custom(let sdks):
          return sdks
        }
      }
    }
  }
}

// MARK: - Custom Codable for AppleSDKs
extension Configuration.Exclusion.AppleSDKs {
  init(from decoder: Decoder) throws {
    let stringContainer = try decoder.singleValueContainer()
    
    // Try string "default"
    if let string = try? stringContainer.decode(String.self), string == "default" {
      self = .default
      return
    }
    
    // Try array of strings
    if let sdks = try? stringContainer.decode([String].self) {
      self = .custom(Set(sdks))
      return
    }
    
    throw DecodingError.dataCorruptedError(
      in: stringContainer,
      debugDescription: "Expected 'default' or array of SDK names"
    )
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .default:
      try container.encode("default")
    case .custom(let sdks):
      try container.encode(Array(sdks))
    }
  }
}

// MARK: - Features Configuration

extension Configuration {
  /// Optional features that can be enabled
  struct Features: Codable, Equatable {
    let exportedFiles: ExportedFiles?
    let leafInfo: Bool
    let unusedThreshold: Int?
    let keepTempFiles: Bool
    let targetParameters: [String: [String]]
    
    init(
      exportedFiles: ExportedFiles? = nil,
      leafInfo: Bool = false,
      unusedThreshold: Int? = nil,
      keepTempFiles: Bool = false,
      targetParameters: [String: [String]] = [:]
    ) {
      self.exportedFiles = exportedFiles
      self.leafInfo = leafInfo
      self.unusedThreshold = unusedThreshold
      self.keepTempFiles = keepTempFiles
      self.targetParameters = targetParameters
    }
    
    struct ExportedFiles: Codable, Equatable {
      let relativePath: FilePath?
      
      init(relativePath: FilePath? = nil) {
        self.relativePath = relativePath
      }
    }
  }
}

// MARK: - Default Apple SDKs (from AppleSDKs.swift)
let appleDefaultSDKs = [
  "ARKit", "AVFoundation", "AVKit", "Accelerate", "Accounts",
  "AdSupport", "AddressBook", "AddressBookUI", "AppKit",
  "AppSupport", "AppleBasebandManager", "ArtworkCache",
  "AssetsLibrary", "AudioToolbox", "AudioUnit",
  "AuthenticationServices", "BluetoothManager", "BusinessChat",
  "CFNetwork", "Calculate", "Calendar", "CallKit", "Camera",
  "CarPlay", "Celestial", "Charts", "ClassKit", "CloudKit",
  "Combine", "Compression", "Contacts", "ContactsUI", "CoreAudio",
  "CoreAudioKit", "CoreBluetooth", "CoreData", "CoreFoundation",
  "CoreGraphics", "CoreImage", "CoreLocation", "CoreMIDI",
  "CoreML", "CoreMedia", "CoreMotion", "CoreNFC", "CoreServices",
  "CoreSpotlight", "CoreSurface", "CoreTelephony", "CoreText",
  "CoreVideo", "CryptoKit", "DeviceCheck", "DeviceLink",
  "EventKit", "EventKitUI", "ExternalAccessory", "FileProvider",
  "FileProviderUI", "Foundation", "FoundationNetworking", "GLKit",
  "GMM", "GSS", "GameController", "GameKit", "GameplayKit",
  "GraphicsServices", "HealthKit", "HealthKitUI", "HomeKit", "IAP",
  "IOKit", "IOMobileFramebuffer", "IOSurface", "ITSync",
  "IdentityLookup", "IdentityLookupUI", "ImageIO", "Intents",
  "IntentsUI", "JavaScriptCore", "LayerKit", "LocalAuthentication",
  "MBX2D", "MBXConnect", "MapKit", "MeCCA", "MediaAccessibility",
  "MediaPlayer", "MediaToolbox", "Message", "MessageUI", "Messages",
  "Metal", "MetalKit", "MetalPerformanceShaders", "MobileBluetooth",
  "MobileCoreServices", "MobileMusicPlayer", "ModelIO",
  "MoviePlayerUI", "MultipeerConnectivity", "MultitouchSupport",
  "MusicLibrary", "NaturalLanguage", "Network", "NetworkExtension",
  "NewsstandKit", "NotificationCenter", "OfficeImport", "OpenAL",
  "OpenGLES", "PDFKit", "PassKit", "PhotoLibrary", "Photos",
  "PhotosUI", "Preferences", "PushKit", "QuartzCore", "QuickLook",
  "ReplayKit", "SafariServices", "SceneKit", "Security", "Social",
  "Speech", "SpriteKit", "StoreKit", "SwiftUI", "System",
  "SystemConfiguration", "TelephonyUI", "Twitter", "UIKit", "URLify",
  "UserNotifications", "UserNotificationsUI", "VideoSubscriberAccount",
  "VideoToolbox", "Vision", "VisualVoicemail", "WatchConnectivity",
  "WatchKit", "WebCore", "WebKit", "iAD", "iTunesStore"
]
