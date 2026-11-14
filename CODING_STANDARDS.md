# Coding standards

Read during review. The mechanical part is enforced by the `Architecture/` package (see
[docs/architecture-rules.md](docs/architecture-rules.md)); the rest is judgement.

## Shape of the plugin

- **One pipeline, top-level phase functions.** `Plugin.swift` loads the config and calls
  `PackageGeneratorV2.generate`, which runs the phases in order: discovery (`TargetResolution.swift`), import
  filtering (`ImportAnalysis.swift`), rendering (`TargetRendering.swift`, `ProductGeneration.swift`, written by
  `CodeGeneration.swift`) and the optional extras (`AdvancedFeatures.swift`, `DependencyGraph.swift`). A phase is a free function at file scope, not a method on a new type.
- **Pure core, thin shell.** Code that turns a configuration and a list of `ParsedPackage` into text does not import
  `PackagePlugin`: it takes values and returns values, and reports warnings through a closure the caller passes. Only
  the shell (config loading, path discovery, running `package-generator-cli`, writing files, `Diagnostics`) touches
  `PackagePlugin`, the file system or a process.
- **The tests compile the real files.** A `.plugin` target cannot be imported, so `Tests/PackageGeneratorTests/Shared`
  holds symbolic links to the pure files in `Plugins/PackageGenerator`, never copies. A file that gains a
  `PackagePlugin` import can no longer be linked there.
- **Swift 6 language mode.** All code compiles under strict concurrency (`swiftLanguageModes: [.v6]`).

## Behaviour that users rely on

- **Output is deterministic.** The same config and imports give byte-for-byte the same `Package.swift`: products and
  targets are sorted, dependencies are sorted before `additionalDependencies` are appended.
- **Config strings are verbatim.** `parameters` and `additionalDependencies` are written into `Package.swift` as
  given, trimmed but never parsed or rewritten.
- **Apple SDK filtering happens at render time.** `filterImports` drops only self-imports and explicit exclusions.
  `renderSingleTarget` looks an import up in the external products first, then the local targets, and only then in
  `appleDefaultSDKs`, so a package product named like an SDK (`Charts`) is never dropped.
- **External products use the package identity.** `.product(name:package:)` takes `dependency.package.id`, the
  URL-derived identity SwiftPM resolves, never `displayName`.
- **URL-based PackagePlugin APIs.** `context.package.directoryURL`, `context.pluginWorkDirectoryURL`, `tool.url`;
  never the deprecated `Path` APIs.
- **Old configs keep working.** A new config key is optional with a default that reproduces today's output; legacy
  keys (`targetsParameters`, boolean `verbose`) are migrated in memory, never on disk. Document new keys in
  `README.md` and, when they replace an old one, in `MIGRATION.md`.

## Reporting

- **Diagnostics, not print.** The plugin reports through `Diagnostics.emit`; `print` output is lost in Xcode.
  Verbose-only messages check `config.verbosePlugin`.

## Tests

- **Swift Testing only.** `@Suite`, `@Test`, `#expect`, `#require`; no XCTest, no disabled tests.
- **Test the rendered text.** Assert on the generated `Package.swift` lines, which is what users see.
