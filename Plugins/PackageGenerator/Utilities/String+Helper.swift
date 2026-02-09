import Foundation

// MARK: - String Extensions

extension String {
  /// Count occurrences of a character in a string (point-free style)
  func count(of needle: Character) -> Int {
    reduce(0) { $1 == needle ? $0 + 1 : $0 }
  }
}
