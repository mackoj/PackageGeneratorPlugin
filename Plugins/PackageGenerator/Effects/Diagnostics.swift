import Foundation
import PackagePlugin

// MARK: - Diagnostics Effect

/// Abstraction for emitting diagnostics
struct DiagnosticsEffect {
  var emit: (Severity, String) -> Void
  var warning: (String) -> Void
  var error: (String) -> Void
  var remark: (String) -> Void
  
  enum Severity {
    case warning
    case error
    case remark
  }
  
  init(
    emit: @escaping (Severity, String) -> Void
  ) {
    self.emit = emit
    self.warning = { emit(.warning, $0) }
    self.error = { emit(.error, $0) }
    self.remark = { emit(.remark, $0) }
  }
}

// MARK: - Live Implementation

extension DiagnosticsEffect {
  static let live = Self { severity, message in
    let pluginSeverity: PackagePlugin.Diagnostics.Severity
    switch severity {
    case .warning: pluginSeverity = .warning
    case .error: pluginSeverity = .error
    case .remark: pluginSeverity = .remark
    }
    Diagnostics.emit(pluginSeverity, message)
  }
}

// MARK: - Test/Mock Implementation

extension DiagnosticsEffect {
  static func mock(
    onEmit: @escaping (Severity, String) -> Void = { _, _ in }
  ) -> Self {
    Self(emit: onEmit)
  }
  
  static let silent = Self { _, _ in }
}

// MARK: - Convenience Functions

extension DiagnosticsEffect {
  /// Emit multiple messages at once
  func emitAll(_ severity: Severity, messages: [String]) {
    messages.forEach { emit(severity, $0) }
  }
  
  /// Emit a message with optional condition
  func emitIf(
    _ condition: Bool,
    _ severity: Severity,
    _ message: @autoclosure () -> String
  ) {
    if condition {
      emit(severity, message())
    }
  }
}
