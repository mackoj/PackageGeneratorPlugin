import Foundation

public typealias FileURL = URL

extension KeyedDecodingContainer {
  public func decode(_ type: FileURL.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> FileURL {
    let decodedValue = try self.decode(String.self, forKey: key)
    return FileURL(fileURLWithPath: decodedValue)
  }
  
  public func decodeIfPresent(_ type: FileURL.Type, forKey key: KeyedDecodingContainer<K>.Key) throws -> FileURL? {
    if let decodedValue = try self.decodeIfPresent(String.self, forKey: key)  {
      return FileURL(fileURLWithPath: decodedValue)
    }
    return nil
  }
}

extension KeyedEncodingContainer {
  public mutating func encode(_ value: FileURL, forKey key: KeyedEncodingContainer<K>.Key) throws {
    try self.encode(value.path, forKey: key)
  }
  
  public mutating func encodeIfPresent(_ value: FileURL?, forKey key: KeyedEncodingContainer<K>.Key) throws {
    try self.encodeIfPresent(value?.path, forKey: key)
  }
}
