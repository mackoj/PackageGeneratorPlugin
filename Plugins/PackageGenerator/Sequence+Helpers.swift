import Foundation

extension Sequence where Iterator.Element: Hashable {
  func unique() -> [Iterator.Element] {
    var seen: Set<Iterator.Element> = []
    return filter { seen.insert($0).inserted }
  }
}

extension Sequence {
  @inlinable public func sorted(with: [Self.Element]) -> [Self.Element]
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
  public func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>, order: @escaping (T, T) -> Bool) -> [Element] {
    return sorted { a, b in
      return order(a[keyPath: keyPath], b[keyPath: keyPath])
    }
  }
  
  public func sorted<T: Comparable>(by keyPath: KeyPath<Element, T?>, order: @escaping (T?, T?) -> Bool) -> [Element] {
    return sorted { a, b in
      return order(a[keyPath: keyPath], b[keyPath: keyPath])
    }
  }
}
