import Foundation
import PackagePlugin

// MARK: - Process Effect

/// Abstraction for running external processes
struct ProcessEffect {
  var run: (FilePath, [String]) throws -> ProcessResult
  
  struct ProcessResult {
    let terminationStatus: Int32
    let terminationReason: Process.TerminationReason
    
    var succeeded: Bool {
      terminationReason == .exit && terminationStatus == 0
    }
  }
}

// MARK: - Live Implementation

extension ProcessEffect {
  static func live(context: PluginContext) -> Self {
    Self { executablePath, arguments in
      let process = Process()
      process.executableURL = executablePath.url
      process.arguments = arguments
      
      do {
        try process.run()
        process.waitUntilExit()
      } catch {
        throw ProcessError.executionFailed(executablePath, error)
      }
      
      return ProcessResult(
        terminationStatus: process.terminationStatus,
        terminationReason: process.terminationReason
      )
    }
  }
  
  /// Run a tool by name from the plugin context
  static func liveWithToolLookup(context: PluginContext) -> Self {
    Self { toolName, arguments in
      let tool: PluginContext.Tool
      do {
        tool = try context.tool(named: toolName.rawValue)
      } catch {
        throw ProcessError.toolNotFound(toolName)
      }
      
      let process = Process()
      process.executableURL = URL(fileURLWithPath: tool.path.string)
      process.arguments = arguments
      
      do {
        try process.run()
        process.waitUntilExit()
      } catch {
        throw ProcessError.executionFailed(toolName, error)
      }
      
      return ProcessResult(
        terminationStatus: process.terminationStatus,
        terminationReason: process.terminationReason
      )
    }
  }
}

// MARK: - Test/Mock Implementation

extension ProcessEffect {
  static func mock(
    result: ProcessResult = ProcessResult(
      terminationStatus: 0,
      terminationReason: .exit
    )
  ) -> Self {
    Self { _, _ in result }
  }
  
  static let alwaysSucceeds = mock()
  
  static let alwaysFails = mock(
    result: ProcessResult(
      terminationStatus: 1,
      terminationReason: .exit
    )
  )
}

// MARK: - Errors

enum ProcessError: Error, CustomStringConvertible {
  case toolNotFound(FilePath)
  case executionFailed(FilePath, Error)
  case nonZeroExit(FilePath, Int32)
  
  var description: String {
    switch self {
    case .toolNotFound(let tool):
      return "Tool not found: \(tool)"
    case .executionFailed(let tool, let error):
      return "Failed to execute \(tool): \(error)"
    case .nonZeroExit(let tool, let status):
      return "\(tool) exited with status \(status)"
    }
  }
}
