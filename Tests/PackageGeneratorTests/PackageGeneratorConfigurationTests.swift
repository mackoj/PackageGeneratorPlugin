import XCTest
import Foundation
@testable import PackageGeneratorLib

@available(macOS 13.0, *)
@MainActor
class PackageGeneratorConfigurationTests: XCTestCase {
    
  // loading
  /*
   - dryRun: Failed to decode(String)
   - dryRun: not set == false
   - pragmaMark: Failed to decode(String)
   - pragmaMark: not set == false
   - targetsParameters: Failed to decode(String)
   - targetsParameters: not set == empty
   - targetsParameters: Non existing target
   - exclusions.imports: Failed to decode(String)
   - exclusions.imports: not set == empty
   - exclusions.imports: Non existing Import
   - exclusions.targets: Failed to decode(String)
   - exclusions.targets: not set == empty
   - exclusions.targets: Non existing Target
   - exclusions.apple: Failed to decode(String)
   - exclusions.apple: not set == default list
   - exclusions.apple: Non existing Import
   - verbose: Failed to decode(String)
   - verbose:  not set == false
   - mappers.imports: Failed to decode(String)
   - mappers.imports: not set == empty
   - mappers.imports: Non existing Import
   - mappers.targets: Failed to decode(String)
   - mappers.targets: not set == empty
   - mappers.targets: Non existing Target
   - packageDirectories: Failed to decode(String)
   - packageDirectories: This should not be empty
   - packageDirectories: Failed to find Package
   - packageDirectories: Failed to read Package
   - version: Failed to decode(String)
   - version: This should not be empty
   - version: This should be == 1

   //    { error in
   //      XCTAssertEqual(
   //        """
   //        Impossible d’ouvrir le fichier « \(headerFileURL.lastPathComponent) » car il n’existe pas.
   //        """,
   //        "\(error.localizedDescription)")
   //    }

   */
  
  
  func testBadLoadingHeader() async throws {
    let confFileURL = try badConfigurationFileBuilder { $0["headerFileURL"] = 1 }
    XCTAssertThrowsError(try PackageGenerator.loadConfiguration(confFileURL), "Failed to decode(Int)")

    let headerFileURL = FileManager.default.temporaryDirectory.appendingPathExtension(UUID().uuidString)
    try Data().write(to: headerFileURL)
    XCTAssertThrowsError(try PackageGenerator.loadConfiguration(headerFileURL), "headerFileURL: is empty")
    try FileManager.default.removeItem(at: headerFileURL)
  }

  func testBadHeaderContent() async throws {
    let headerFileURL = FileManager.default.temporaryDirectory.appendingPathExtension(UUID().uuidString)
    let confFileURL = FileManager.default.temporaryDirectory.appendingPathExtension(UUID().uuidString)
    var conf = PackageGeneratorConfiguration()
    conf.headerFileURL = headerFileURL.path
    XCTAssertThrowsError(try PackageGenerator.validateConfiguration(conf, confFileURL), "headerFileURL: File not found")
    //    XCTAssertThrowsError(try PackageGenerator.validateConfiguration(conf, confFileURL), "headerFileURL: File not readable")
  }

  func testHeaderHappyPath() async throws {
    var (conf, confFileURL) = correctConf()
    let headerFileURL = FileManager.default.temporaryDirectory.appendingPathExtension(UUID().uuidString)
    conf.headerFileURL = headerFileURL.path
    XCTAssertNoThrow(try PackageGenerator.validateConfiguration(conf, confFileURL), "headerFileURL: ok")
  }
  
  func testBadLoadingSpaces() async throws {
    let confFileURL = try badConfigurationFileBuilder { $0["spaces"] = "tartempion" }
    XCTAssertThrowsError(try PackageGenerator.loadConfiguration(confFileURL), "spaces: Failed to decode(String)")
  }
  
  func testBadSpacesContent() async throws {
    var (conf, confFileURL) = correctConf()
    conf.spaces = -1
    XCTAssertThrowsError(try PackageGenerator.validateConfiguration(conf, confFileURL), "spaces: <0")
    conf.spaces = 9
    XCTAssertThrowsError(try PackageGenerator.validateConfiguration(conf, confFileURL), "spaces: >8")
  }
  
  func testSpacesHappyPath() async throws {
    var (conf, confFileURL) = correctConf()
    XCTAssertEqual(2, conf.spaces, "spaces: default == 2")
    conf.spaces = 0
    XCTAssertNoThrow(try PackageGenerator.validateConfiguration(conf, confFileURL), "spaces: ok")
    conf.spaces = 8
    XCTAssertNoThrow(try PackageGenerator.validateConfiguration(conf, confFileURL), "spaces: ok")
  }

}
