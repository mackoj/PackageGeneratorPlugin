import Foundation

enum DiagnosticsSeverityProxy: String, Encodable {
  case error
  case warning
  case remark
}

#if canImport(PackagePlugin)
import PackagePlugin

func fatalErrorWithDiagnostics(_ description: String, file: StaticString = #file, line: UInt = #line) -> Never {
  Diagnostics.emit(.error, description)
  fatalError(file: file, line: line)
}

func printDiagnostics(_ severity: DiagnosticsSeverityProxy, _ description: String, file: String? = #file, line: Int? = #line) {
  Diagnostics.emit(severity.proxy, description)
}

extension DiagnosticsSeverityProxy {
  var proxy: PackagePlugin.Diagnostics.Severity {
    switch self {
    case .error: return .error
    case .warning: return .warning
    case .remark: return .remark
    }
  }
}

#else
func printDiagnostics(_ severity: DiagnosticsSeverityProxy, _ description: String, file: String? = #file, line: Int? = #line) {
  print(description)
}

func fatalErrorWithDiagnostics(_ description: String, file: StaticString = #file, line: UInt = #line) -> Never {
  fatalError(description, file: file, line: line)
}
#endif
