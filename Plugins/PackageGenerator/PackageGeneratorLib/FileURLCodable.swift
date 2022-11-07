import Foundation

typealias FileURL = URL

extension KeyedDecodingContainer {
  func decode(_ type: FileURL.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> FileURL {
    let decodedValue = try self.decode(String.self, forKey: key)
    return FileURL(fileURLWithPath: decodedValue)
  }
  
  func decodeIfPresent(_ type: FileURL.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> FileURL? {
    if let decodedValue = try self.decodeIfPresent(String.self, forKey: key)  {
      return FileURL(fileURLWithPath: decodedValue)
    }
    return nil
  }
}

extension KeyedEncodingContainer {
  mutating func encode(_ value: FileURL, forKey key: KeyedEncodingContainer<K>.Key) throws {
    try self.encode(value.path, forKey: key)
  }
  
  mutating func encodeIfPresent(_ value: FileURL?, forKey key: KeyedEncodingContainer<K>.Key) throws {
    try self.encodeIfPresent(value?.path, forKey: key)
  }
}
