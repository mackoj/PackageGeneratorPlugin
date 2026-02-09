import Foundation

// MARK: - FileSystem Effect

/// Abstraction for file system operations
struct FileSystemEffect {
  var fileExists: (FilePath) -> Bool
  var readFile: (FilePath) throws -> Data
  var writeFile: (FilePath, Data) throws -> Void
  var removeFile: (FilePath) throws -> Void
  var createFile: (FilePath, Data?) throws -> Void
  var createDirectory: (FilePath) throws -> Void
  
  /// Read and decode JSON from a file
  func readJSON<T: Decodable>(_ type: T.Type, from path: FilePath) throws -> T {
    let data = try readFile(path)
    return try JSONDecoder().decode(T.self, from: data)
  }
  
  /// Encode and write JSON to a file
  func writeJSON<T: Encodable>(_ value: T, to path: FilePath) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(value)
    try writeFile(path, data)
  }
}

// MARK: - Live Implementation

extension FileSystemEffect {
  static let live = Self(
    fileExists: { path in
      FileManager.default.fileExists(atPath: path.rawValue)
    },
    readFile: { path in
      guard let data = try? Data(contentsOf: path.url) else {
        throw FileSystemError.readFailed(path)
      }
      return data
    },
    writeFile: { path, data in
      do {
        try data.write(to: path.url, options: .atomic)
      } catch {
        throw FileSystemError.writeFailed(path, error)
      }
    },
    removeFile: { path in
      do {
        try FileManager.default.removeItem(at: path.url)
      } catch {
        throw FileSystemError.deleteFailed(path, error)
      }
    },
    createFile: { path, data in
      let created = FileManager.default.createFile(
        atPath: path.rawValue,
        contents: data
      )
      if !created {
        throw FileSystemError.createFailed(path)
      }
    },
    createDirectory: { path in
      do {
        try FileManager.default.createDirectory(
          at: path.url,
          withIntermediateDirectories: true
        )
      } catch {
        throw FileSystemError.createDirectoryFailed(path, error)
      }
    }
  )
}

// MARK: - Test/Mock Implementation

extension FileSystemEffect {
  static func mock(
    files: [FilePath: Data] = [:]
  ) -> Self {
    var mockFiles = files
    
    return Self(
      fileExists: { path in
        mockFiles[path] != nil
      },
      readFile: { path in
        guard let data = mockFiles[path] else {
          throw FileSystemError.readFailed(path)
        }
        return data
      },
      writeFile: { path, data in
        mockFiles[path] = data
      },
      removeFile: { path in
        mockFiles[path] = nil
      },
      createFile: { path, data in
        mockFiles[path] = data ?? Data()
      },
      createDirectory: { _ in
        // No-op for mock
      }
    )
  }
}

// MARK: - Errors

enum FileSystemError: Error, CustomStringConvertible {
  case readFailed(FilePath)
  case writeFailed(FilePath, Error)
  case deleteFailed(FilePath, Error)
  case createFailed(FilePath)
  case createDirectoryFailed(FilePath, Error)
  
  var description: String {
    switch self {
    case .readFailed(let path):
      return "Failed to read file at \(path)"
    case .writeFailed(let path, let error):
      return "Failed to write file at \(path): \(error)"
    case .deleteFailed(let path, let error):
      return "Failed to delete file at \(path): \(error)"
    case .createFailed(let path):
      return "Failed to create file at \(path)"
    case .createDirectoryFailed(let path, let error):
      return "Failed to create directory at \(path): \(error)"
    }
  }
}
