import Benchmark
import Foundation

// The plugin's PackagePlugin-free files are compiled into this target through the links in `Shared/`. What they
// measure is the part of a run the plugin does itself; scanning sources for imports is package-generator-cli's work.

/// A synthetic modular app: `groups` folders of `perGroup` library targets, each with a test target, so
/// `2 × groups × perGroup` targets. Imports mix local targets, external products, Apple SDKs and an unknown module,
/// like a real heavily modularized app.
struct SyntheticProject {
    let config: ConfigurationV2
    /// The configuration as the plugin reads it from disk, with some parameters in the legacy `targetsParameters`.
    let configJSON: Data
    /// What package-generator-cli reports for each target: unsorted, with self-imports and an excluded import.
    let rawImports: [(name: String, isTest: Bool, imports: [String])]
    /// `ParsedPackage`s after `filterImports`, as `PackageGeneratorV2` builds them.
    let packages: [ParsedPackage]
    let externalDeps: [String: String]

    init(groups: Int = 25, perGroup: Int = 20) {
        var random = SplitMix64(seed: 42)
        let externalProducts = (0..<40).map { "Vendor\($0)" }
        externalDeps = Dictionary(
            uniqueKeysWithValues: externalProducts.enumerated().map { index, product in
                (product, ".product(name: \"\(product)\", package: \"vendor-package-\(index % 12)\")")
            })
        let sdks = ["Foundation", "SwiftUI", "UIKit", "Combine", "CoreData", "MapKit", "Charts", "OSLog", "os"]
        let exclusions = ConfigurationV2.Exclusions(imports: ["LegacyAnalytics"], targets: [])

        var directoryGroups: [ConfigurationV2.DirectoryGroup] = []
        var rawImports: [(name: String, isTest: Bool, imports: [String])] = []
        var legacyParameters: [String: [String]] = [:]
        var localNames: [String] = []

        for group in 0..<groups {
            var specs: [ConfigurationV2.TargetSpec] = []
            for index in 0..<perGroup {
                let name = "Feature\(group)Module\(index)"
                let testName = name + "Tests"

                var imports = [name, "LegacyAnalytics", "Module\(group)Unknown"]
                imports += (0..<min(8, localNames.count)).map { _ in localNames[random.next(below: localNames.count)] }
                imports += (0..<3).map { _ in externalProducts[random.next(below: externalProducts.count)] }
                imports += (0..<3).map { _ in sdks[random.next(below: sdks.count)] }
                imports.shuffle(using: &random)
                var seen = Set<String>()
                rawImports.append((name, false, imports.filter { seen.insert($0).inserted }))
                rawImports.append((testName, true, [name, "XCTest", "Foundation", externalProducts[index % 40]]))

                specs.append(
                    .init(
                        name: name,
                        path: "Sources/Feature\(group)/\(name)",
                        exclude: index % 4 == 0 ? ["README.md", "__Snapshots__"] : nil,
                        parameters: index % 3 == 0 ? ["resources: [.process(\"Resources\")]"] : nil,
                        additionalDependencies: index % 5 == 0
                            ? [".product(name: \"Dependencies\", package: \"swift-dependencies\")"] : nil))
                specs.append(.init(name: testName, type: .test, path: "Tests/Feature\(group)/\(testName)"))
                if index % 2 == 0 {
                    legacyParameters[name] = ["swiftSettings: [.enableUpcomingFeature(\"ExistentialAny\")]"]
                }
                localNames.append(name)
            }
            directoryGroups.append(.init(path: "Sources/Feature\(group)", targets: specs))
        }

        config = ConfigurationV2(
            pragmaMark: true, spaces: 2, leafInfo: true, unusedThreshold: 0,
            packageDirectoryTargets: directoryGroups,
            mappers: .init(imports: ["Vendor0": ".product(name: \"Vendor0\", package: \"vendor-zero\")"]),
            exclusions: exclusions)

        var object = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as! [String: Any]
        object["targetsParameters"] = legacyParameters
        configJSON = try! JSONSerialization.data(withJSONObject: object)

        self.rawImports = rawImports
        let specs = Dictionary(
            uniqueKeysWithValues: directoryGroups.flatMap(\.targets).map { ($0.name, $0) })
        packages = rawImports.map { entry in
            let spec = specs[entry.name]!
            return ParsedPackage(
                name: entry.name,
                isTest: entry.isTest,
                dependencies: filterImports(rawImports: entry.imports, targetName: entry.name, exclusions: exclusions),
                path: spec.path!,
                fullPath: "/project/" + spec.path!,
                exclude: spec.exclude ?? [],
                parameters: spec.parameters,
                additionalDependencies: spec.additionalDependencies)
        }
    }
}

/// A seeded generator, so every run measures the same project.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func next(below upperBound: Int) -> Int { Int(next() % UInt64(upperBound)) }
}

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(
        metrics: [.wallClock, .cpuTotal, .mallocCountTotal, .peakMemoryResident, .retainCount],
        // Exact counts and microseconds, so a change of a few percent shows up in a comparison.
        timeUnits: .microseconds,
        units: [.mallocCountTotal: .count, .retainCount: .count],
        maxDuration: .seconds(2),
        maxIterations: 1_000
    )

    let project = SyntheticProject()
    let plain = ConfigurationV2(packageDirectoryTargets: project.config.packageDirectoryTargets)

    Benchmark("Decode config, 1,000 targets") { _ in
        blackHole(try JSONDecoder().decode(ConfigurationV2.self, from: project.configJSON))
    }

    Benchmark("Filter imports, 1,000 targets") { _ in
        for entry in project.rawImports {
            blackHole(
                filterImports(
                    rawImports: entry.imports, targetName: entry.name, exclusions: project.config.exclusions))
        }
    }

    Benchmark("Dependency graph, 1,000 targets") { _ in
        blackHole(computeDependencyWeight(project.packages))
        blackHole(analyzeDependencyGraph(project.packages))
    }

    Benchmark("Render products, 1,000 targets") { _ in
        blackHole(generateProductsSection(parsedPackages: project.packages, config: project.config))
    }

    Benchmark("Render Package.swift, 1,000 targets") { _ in
        let weights = computeDependencyWeight(project.packages)
        var warnings = 0
        blackHole(
            renderPackageContent(
                project.packages, config: project.config, externalDeps: project.externalDeps, leafWeights: weights,
                warn: { _ in warnings += 1 }))
        blackHole(warnings)
    }

    Benchmark("Render Package.swift, 1,000 targets, default settings") { _ in
        var warnings = 0
        blackHole(
            renderPackageContent(
                project.packages, config: plain, externalDeps: project.externalDeps, leafWeights: [:],
                warn: { _ in warnings += 1 }))
        blackHole(warnings)
    }
}
