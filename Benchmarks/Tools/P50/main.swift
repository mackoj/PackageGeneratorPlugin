import Foundation

// Usage: swift run --package-path Benchmarks p50 before.md after.md
// Each file is the output of `swift package --package-path Benchmarks benchmark --format markdown --no-progress`.

/// A benchmark's p50 wall clock in microseconds and p50 malloc count.
struct Medians {
    var wallClock: Double?
    var mallocs: Double?
}

func medians(inFile path: String) throws -> [(name: String, medians: Medians)] {
    let text = try String(contentsOfFile: path, encoding: .utf8)
    // A row: | Time (wall clock) (μs) * | p0 | p25 | p50 | …  The unit is absent for plain counts.
    let row =
        /^\|\s*(Malloc \(total\)|Time \(wall clock\))\s*(?:\(([^)]*)\))?\s*\*?\s*\|\s*[\d,]+\s*\|\s*[\d,]+\s*\|\s*([\d,]+)/
    let scale: [String: Double] = ["ns": 1e-3, "μs": 1, "us": 1, "ms": 1e3, "s": 1e6, "K": 1e3, "M": 1e6]
    var result: [(name: String, medians: Medians)] = []
    for line in text.split(separator: "\n") {
        if line.hasPrefix("### ") {
            let name = line.dropFirst(4).replacingOccurrences(of: " metrics", with: "")
            result.append((name, Medians()))
        } else if let match = line.firstMatch(of: row), !result.isEmpty {
            let value =
                Double(match.3.replacingOccurrences(of: ",", with: ""))! * (match.2.map { scale[String($0)] ?? 1 } ?? 1)
            if match.1 == "Malloc (total)" {
                result[result.count - 1].medians.mallocs = result[result.count - 1].medians.mallocs ?? value
            } else {
                result[result.count - 1].medians.wallClock = result[result.count - 1].medians.wallClock ?? value
            }
        }
    }
    return result
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("usage: p50 <before.md> <after.md>")
    exit(2)
}
let before = Dictionary(
    try medians(inFile: arguments[1]).map { ($0.name, $0.medians) }, uniquingKeysWith: { a, _ in a })
func cell(_ old: Double?, _ new: Double?, _ format: String) -> String {
    guard let new else { return "" }
    guard let old else { return String(format: format, new) }
    return String(format: "\(format) → \(format) (%.2fx)", old, new, new / old)
}
print("| Benchmark | Wall clock p50 (µs) | Mallocs p50 |")
print("|---|---|---|")
for (name, after) in try medians(inFile: arguments[2]) {
    let old = before[name]
    print(
        "| \(name) | \(cell(old?.wallClock, after.wallClock, "%.1f")) | \(cell(old?.mallocs, after.mallocs, "%.0f")) |")
}
