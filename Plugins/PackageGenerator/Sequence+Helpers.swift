import Foundation

extension Sequence where Iterator.Element: Hashable {
  func unique() -> [Iterator.Element] {
    var seen: Set<Iterator.Element> = []
    return filter { seen.insert($0).inserted }
  }
}

extension Sequence {
  @inlinable func sorted(with: [Self.Element]) -> [Self.Element]
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

extension Sequence {
  func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>, order: @escaping (T, T) -> Bool) -> [Element] {
    return sorted { a, b in
      return order(a[keyPath: keyPath], b[keyPath: keyPath])
    }
  }
  
  func sorted<T: Comparable>(by keyPath: KeyPath<Element, T?>, order: @escaping (T?, T?) -> Bool) -> [Element] {
    return sorted { a, b in
      return order(a[keyPath: keyPath], b[keyPath: keyPath])
    }
  }
  func sorted<T: Comparable>(by comparators: (keyPath: KeyPath<Element, T>, order: (T, T) -> Bool)...) -> [Element] {
    return sorted { a, b in
      for comparator in comparators {
        if comparator.order(a[keyPath: comparator.keyPath], b[keyPath: comparator.keyPath]) {
          return true
        } else if comparator.order(b[keyPath: comparator.keyPath], a[keyPath: comparator.keyPath]) {
          return false
        }
      }
      return false
    }
  }
}
