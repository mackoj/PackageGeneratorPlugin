import Foundation

// Usage: swift run --package-path Benchmarks hotspots profile.xml [count]
// profile.xml is `xcrun xctrace export --xpath '…/table[@schema="time-profile"]'` (scripts/profile.sh writes it).
// Prints the functions with the most samples of their own (self) and the generator functions with the most samples
// under them (inclusive). package-benchmark's ARC counting hooks are left out: they exist only while measuring.

/// Reads the rows of an exported time-profile table. Frames and backtraces are written once and then referenced
/// by id, so both are remembered.
final class ProfileReader: NSObject, XMLParserDelegate {
    var frameNames: [String: String] = [:]
    var backtraces: [String: [String]] = [:]
    var samples: [[String]] = []
    private var current: [String]?
    private var currentID: String?

    func parser(
        _ parser: XMLParser, didStartElement element: String, namespaceURI: String?, qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        switch element {
        case "tagged-backtrace", "backtrace":
            if let ref = attributes["ref"] {
                samples.append(backtraces[ref] ?? [])
            } else {
                current = []
                currentID = attributes["id"]
            }
        case "frame" where current != nil:
            if let ref = attributes["ref"] {
                current?.append(frameNames[ref] ?? "?")
            } else {
                let name = attributes["name"] ?? "?"
                if let id = attributes["id"] { frameNames[id] = name }
                current?.append(name)
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
        guard element == "tagged-backtrace" || element == "backtrace", let frames = current else { return }
        if let currentID { backtraces[currentID] = frames }
        samples.append(frames)
        current = nil
        currentID = nil
    }
}

let arguments = CommandLine.arguments
guard arguments.count >= 2, let parser = XMLParser(contentsOf: URL(fileURLWithPath: arguments[1])) else {
    print("usage: hotspots <profile.xml> [count]")
    exit(2)
}
let count = arguments.count > 2 ? Int(arguments[2]) ?? 20 : 20
let reader = ProfileReader()
parser.delegate = reader
guard parser.parse() else {
    print("could not read \(arguments[1]): \(parser.parserError.map { "\($0)" } ?? "unknown error")")
    exit(1)
}

/// The generator's own functions and types: the plugin files the benchmarks compile.
let generator =
    /GeneratorBenchmarks|ConfigurationV2|ParsedPackage|render[A-Z]|generate[A-Z]|filterImports|pragmaMarkGroupName|computeDependencyWeight|analyzeDependencyGraph|typeOrder/
let measuring = /ARCStatsProducer|_swift_(retain|release)_(adapter|hook)|MallocInterposer/
func short(_ name: String) -> String { String(name.prefix { $0 != "(" }.suffix(110)) }

var selfSamples: [String: Int] = [:]
var inclusiveSamples: [String: Int] = [:]
var total = 0
for frames in reader.samples where !frames.isEmpty {
    guard !frames.contains(where: { $0.contains(measuring) }) else { continue }
    total += 1
    selfSamples[short(frames[0]), default: 0] += 1
    for name in Set(frames.map(short)) where name.contains(generator) {
        inclusiveSamples[name, default: 0] += 1
    }
}
func report(_ title: String, _ counts: [String: Int], of total: Int) {
    print(title)
    for (name, samples) in counts.sorted(by: { $0.value > $1.value }).prefix(count) {
        print(String(format: "%5.1f%%  ", 100 * Double(samples) / Double(max(total, 1))) + name)
    }
}
print("\(total) samples")
report("Self", selfSamples, of: total)
report("Inclusive (generator functions)", inclusiveSamples, of: total)
