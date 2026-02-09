import Foundation
import PackagePlugin

// MARK: - Lightweight Dependency Injection for Plugins

/// Simple dependency container for effects
struct Dependencies {
  var fileSystem: FileSystemEffect
  var diagnostics: DiagnosticsEffect
  var process: ProcessEffect
  
  /// The current global dependencies
  private static var _current: Dependencies?
  
  /// Access the current dependencies
  static var current: Dependencies {
    get { _current ?? .test }
    set { _current = newValue }
  }
  
  /// Live implementation (production)
  static func live(context: PluginContext) -> Self {
    Self(
      fileSystem: .live,
      diagnostics: .live,
      process: .liveWithToolLookup(context: context)
    )
  }
  
  /// Test implementation (mocking)
  static var test: Self {
    Self(
      fileSystem: .mock(),
      diagnostics: .silent,
      process: .alwaysSucceeds
    )
  }
}

/// Execute code with specific dependencies
func withDependencies<R>(
  _ update: (inout Dependencies) -> Void,
  operation: () throws -> R
) rethrows -> R {
  var modified = Dependencies.current
  update(&modified)
  let original = Dependencies.current
  Dependencies.current = modified
  defer { Dependencies.current = original }
  return try operation()
}

/// Property wrapper for accessing dependencies
@propertyWrapper
struct Dependency<Value> {
  private let keyPath: KeyPath<Dependencies, Value>
  
  init(_ keyPath: KeyPath<Dependencies, Value>) {
    self.keyPath = keyPath
  }
  
  var wrappedValue: Value {
    Dependencies.current[keyPath: keyPath]
  }
}
