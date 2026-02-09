import Foundation

// MARK: - Function Composition

/// Forward composition operator: combines two functions left-to-right
/// Example: (f >>> g)(x) == g(f(x))
infix operator >>>: CompositionPrecedence
precedencegroup CompositionPrecedence {
  associativity: left
  higherThan: MultiplicationPrecedence
}

func >>> <A, B, C>(
  _ f: @escaping (A) -> B,
  _ g: @escaping (B) -> C
) -> (A) -> C {
  { g(f($0)) }
}

/// Backward composition operator: combines two functions right-to-left
/// Example: (f <<< g)(x) == f(g(x))
infix operator <<<: CompositionPrecedence

func <<< <A, B, C>(
  _ f: @escaping (B) -> C,
  _ g: @escaping (A) -> B
) -> (A) -> C {
  { f(g($0)) }
}

// MARK: - Pipe Operator

/// Pipe operator: applies a value to a function
/// Example: x |> f == f(x)
infix operator |>: ForwardApplication
precedencegroup ForwardApplication {
  associativity: left
  higherThan: AssignmentPrecedence
}

func |> <A, B>(_ a: A, _ f: (A) -> B) -> B {
  f(a)
}

func |> <A, B>(_ a: A, _ f: (A) throws -> B) rethrows -> B {
  try f(a)
}

// MARK: - Common Combinators

/// Identity function: returns its input unchanged
func identity<A>(_ a: A) -> A {
  a
}

/// Constant function: returns a function that always returns the same value
func constant<A, B>(_ b: B) -> (A) -> B {
  { _ in b }
}

/// Flip: reverses the order of a function's arguments
func flip<A, B, C>(_ f: @escaping (A) -> (B) -> C) -> (B) -> (A) -> C {
  { b in { a in f(a)(b) } }
}

/// Flip for two-argument functions
func flip<A, B, C>(_ f: @escaping (A, B) -> C) -> (B, A) -> C {
  { b, a in f(a, b) }
}

// MARK: - Predicate Combinators

/// Negates a predicate
func not<A>(_ p: @escaping (A) -> Bool) -> (A) -> Bool {
  { !p($0) }
}

/// Combines predicates with AND
func and<A>(_ p1: @escaping (A) -> Bool, _ p2: @escaping (A) -> Bool) -> (A) -> Bool {
  { p1($0) && p2($0) }
}

/// Combines predicates with OR
func or<A>(_ p1: @escaping (A) -> Bool, _ p2: @escaping (A) -> Bool) -> (A) -> Bool {
  { p1($0) || p2($0) }
}

// MARK: - Function Application

/// Apply a function to a value (for lifting)
func apply<A, B>(_ f: @escaping (A) -> B) -> (A) -> B {
  f
}

/// Curry a two-argument function
func curry<A, B, C>(_ f: @escaping (A, B) -> C) -> (A) -> (B) -> C {
  { a in { b in f(a, b) } }
}

/// Uncurry a curried function
func uncurry<A, B, C>(_ f: @escaping (A) -> (B) -> C) -> (A, B) -> C {
  { a, b in f(a)(b) }
}

// MARK: - Collection Functions

/// Map function (point-free style)
func map<A, B>(_ transform: @escaping (A) -> B) -> ([A]) -> [B] {
  { $0.map(transform) }
}

/// Filter function (point-free style)
func filter<A>(_ predicate: @escaping (A) -> Bool) -> ([A]) -> [A] {
  { $0.filter(predicate) }
}

/// CompactMap function (point-free style)
func compactMap<A, B>(_ transform: @escaping (A) -> B?) -> ([A]) -> [B] {
  { $0.compactMap(transform) }
}

/// FlatMap function (point-free style)
func flatMap<A, B>(_ transform: @escaping (A) -> [B]) -> ([A]) -> [B] {
  { $0.flatMap(transform) }
}

/// Reduce function (point-free style)
func reduce<A, B>(_ initial: B, _ combine: @escaping (B, A) -> B) -> ([A]) -> B {
  { $0.reduce(initial, combine) }
}

/// Sort function (point-free style)
func sort<A>(by areInIncreasingOrder: @escaping (A, A) -> Bool) -> ([A]) -> [A] {
  { $0.sorted(by: areInIncreasingOrder) }
}

/// Sort by key path (point-free style)
func sortBy<A, B: Comparable>(_ keyPath: KeyPath<A, B>) -> ([A]) -> [A] {
  { $0.sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] } }
}

// MARK: - Optional Lifting

/// Lift a function into the Optional context
func optionally<A, B>(_ f: @escaping (A) -> B) -> (A?) -> B? {
  { $0.map(f) }
}

/// FlatMap for Optional (point-free)
func optionally<A, B>(_ f: @escaping (A) -> B?) -> (A?) -> B? {
  { $0.flatMap(f) }
}

// MARK: - String Operations

/// Join an array of strings with a separator
func joined(separator: String) -> ([String]) -> String {
  { $0.joined(separator: separator) }
}

/// Surround strings with prefix and suffix
func surroundWith(prefix: String = "", suffix: String = "") -> ([String]) -> String {
  { [prefix] + $0 + [suffix] }
    >>> joined(separator: "\n")
}

/// Add separator between elements
func joinWithCommas(_ strings: [String]) -> String {
  strings.joined(separator: ",\n")
}

// MARK: - Side Effect Management

/// Tap: perform a side effect and return the original value
func tap<A>(_ sideEffect: @escaping (A) -> Void) -> (A) -> A {
  { a in
    sideEffect(a)
    return a
  }
}

/// Perform an effect and ignore the result
func ignoring<A, B>(_ f: @escaping (A) -> B) -> (A) -> Void {
  { _ = f($0) }
}

// MARK: - Conditional Application

/// Apply a function conditionally
func when<A>(_ condition: Bool, apply f: @escaping (A) -> A) -> (A) -> A {
  condition ? f : identity
}

/// Apply a function conditionally based on predicate
func when<A>(_ predicate: @escaping (A) -> Bool, apply f: @escaping (A) -> A) -> (A) -> A {
  { a in predicate(a) ? f(a) : a }
}

/// Apply one of two functions based on a condition
func ifElse<A, B>(
  _ condition: @escaping (A) -> Bool,
  then: @escaping (A) -> B,
  else: @escaping (A) -> B
) -> (A) -> B {
  { a in condition(a) ? then(a) : `else`(a) }
}

// MARK: - Tuple Helpers

/// First component of a tuple
func first<A, B>(_ tuple: (A, B)) -> A {
  tuple.0
}

/// Second component of a tuple
func second<A, B>(_ tuple: (A, B)) -> B {
  tuple.1
}

/// Zip two arrays
func zip<A, B>(_ as: [A]) -> ([B]) -> [(A, B)] {
  { bs in Swift.zip(as, bs).map { $0 } }
}

// MARK: - NonEmpty Array

/// A non-empty array type that enforces at least one element
struct NonEmptyArray<Element> {
  let head: Element
  let tail: [Element]
  
  init(_ head: Element, _ tail: Element...) {
    self.head = head
    self.tail = tail
  }
  
  init?(_ array: [Element]) {
    guard let head = array.first else { return nil }
    self.head = head
    self.tail = Array(array.dropFirst())
  }
  
  var all: [Element] {
    [head] + tail
  }
  
  var count: Int {
    1 + tail.count
  }
}

extension NonEmptyArray: Codable where Element: Codable {
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let array = try container.decode([Element].self)
    guard let nonEmpty = NonEmptyArray(array) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Expected non-empty array"
      )
    }
    self = nonEmpty
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(all)
  }
}

extension NonEmptyArray: Equatable where Element: Equatable {}
extension NonEmptyArray: Hashable where Element: Hashable {}

// MARK: - FilePath Type

/// Type-safe file path wrapper
struct FilePath: Hashable {
  let rawValue: String
  
  init(_ path: String) {
    self.rawValue = path
  }
  
  var url: URL {
    URL(fileURLWithPath: rawValue)
  }
  
  func appending(_ component: String) -> FilePath {
    FilePath(url.appendingPathComponent(component).path)
  }
  
  var lastComponent: String {
    url.lastPathComponent
  }
  
  var deletingLastComponent: FilePath {
    FilePath(url.deletingLastPathComponent().path)
  }
}

extension FilePath: Codable {
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self.init(try container.decode(String.self))
  }
  
  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension FilePath: ExpressibleByStringLiteral {
  init(stringLiteral value: String) {
    self.init(value)
  }
}

extension FilePath: CustomStringConvertible {
  var description: String { rawValue }
}
