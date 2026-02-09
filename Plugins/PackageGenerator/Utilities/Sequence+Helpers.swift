import Foundation

// MARK: - Sequence Extensions

extension Sequence where Iterator.Element: Hashable {
  /// Returns an array with duplicate elements removed, preserving order
  func unique() -> [Iterator.Element] {
    var seen: Set<Iterator.Element> = []
    return filter { seen.insert($0).inserted }
  }
}

extension Sequence {
  /// Sort a sequence according to the order defined by another sequence
  @inlinable
  func sorted(with: [Self.Element]) -> [Self.Element]
  where Self.Element: Equatable {
    var res: [Self.Element?] = Array(repeating: nil, count: with.count)
    for (index, element) in with.enumerated() {
      if self.contains(element) {
        res[index] = element
      }
    }
    return res.compactMap { $0 }
  }
}

// Note: Point-free versions of sorting are in Functional.swift
// These are kept for backward compatibility with existing code
