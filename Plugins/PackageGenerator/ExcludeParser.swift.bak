import Foundation

func parseExcludeValues(from parameter: String) -> [String]? {
  guard let start = parameter.firstIndex(of: "["),
        let end = parameter.lastIndex(of: "]"),
        start < end else {
    return nil
  }

  let substring = parameter[start...end]
  guard let data = substring.data(using: .utf8) else {
    return nil
  }

  do {
    return try JSONDecoder().decode([String].self, from: data)
  } catch {
    return nil
  }
}
