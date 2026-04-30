# V2 Architecture Overview for LLM
The `PackageGenerator` V2 is a Swift Package Manager (SPM) Command Plugin. Its goal is to fully automate the generation of a complex, multi-target `Package.swift` file. It delegates Swift file parsing to a companion executable (`package-generator-cli`) to extract `import` statements, then resolves those imports against the local project structure and SPM's graph of external dependencies. V2 embraces a "zero-exclusion" philosophy, relying on strict set intersections rather than hardcoded Apple SDK exclusion lists.

---

# Epic 1: Configuration Management (V2 Schema)
**Description:** The plugin relies on a streamlined configuration file (`packageGenerator.json` or `.yaml`). In V2, the schema is strictly defined without legacy arrays. It acts as the ultimate source of truth for structural rules and explicit overrides.

**User Story 1.1: Automatic Configuration Resolution & Parsing**
* **As a** developer,
* **I want** the plugin to automatically locate and parse my configuration file,
* **So that** I don't have to provide command-line arguments unless overriding the default.
* **Acceptance Criteria:**
  * Checks for `--confFile` in CLI arguments. If missing, looks for `packageGenerator.yaml`, `packageGenerator.yml`, or `packageGenerator.json` in the package root.
  * If no configuration file exists, the plugin generates a default `packageGenerator.json` and a default `PackageHeader.swift` file, prints a warning, and gracefully exits.
  * The configuration schema must securely parse top-level keys: `verbose`, `dryRun`, `pragmaMark`, `generateExportedFiles`, `headerFileURL`, `spaces`, `mappers`, and `packageDirectoryTargets`.

**User Story 1.2: Cross-Format Support (YAML & JSON)**
* **As a** developer,
* **I want** to write my configuration in YAML,
* **So that** it is easier to read, write, and maintain compared to strict JSON.
* **Acceptance Criteria:**
  * If a `.yaml` or `.yml` file is detected, the plugin invokes a `yaml-converter` CLI tool to temporarily convert it to a `.json` file in the plugin's work directory before decoding it into Swift structs.

# Epic 2: Target Discovery & Path Mapping
**Description:** The generator traverses the file system based purely on the `packageDirectoryTargets` array to map source directories to SPM targets, utilizing shortest-path logic to handle nested architectures.

**User Story 2.1: Explicit Target Declaration (The V2 Schema)**
* **As a** developer,
* **I want** to explicitly declare directories and their targets inside `packageDirectoryTargets`,
* **So that** the generator knows the exact layout of my `regular`, `test`, and `macro` targets.
* **Acceptance Criteria:**
  * The schema strictly expects an array of objects containing a base `path` and an array of `targets`.
  * Each target object defines a `name`, `type` (`regular`, `test`, `macro`), an optional `path` override, and an optional `parameters` array.
  * Automatically infers that `regular`/`macro` targets live in a `Sources/` subfolder, and `test` targets live in a `Tests/` subfolder unless a specific target `path` is overridden.

**User Story 2.2: Shortest-Path Target Resolution**
* **As a** developer,
* **I want** the plugin to safely resolve targets even if my folders don't perfectly match standard SPM conventions,
* **So that** identically named folders (e.g., `Sources/Search` vs `Sources/Search/Search`) do not overwrite each other.
* **Acceptance Criteria:**
  * The generator constructs the expected path for a target (e.g., `Sources/[Path]/Sources/[TargetName]`).
  * If the declared group `path` already terminates with the `TargetName`, it immediately accepts it as the root path (e.g., `Sources/OrderDetail` for target `OrderDetail`).
  * If the constructed path does not exist on disk, it falls back to a recursive search of `Sources/` and `Tests/`.
  * During recursive search, if multiple folders match the target name, **the shortest path (least depth) always wins**.

**User Story 2.3: Test Target Auto-Association**
* **As a** developer,
* **I want** my test targets to automatically pair with their corresponding regular targets,
* **So that** the generator can validate the project structure correctly.
* **Acceptance Criteria:**
  * The plugin automatically strips the "Tests" suffix from a test target to find its parent (e.g., `CatalogTests` pairs with `Catalog`).
  * If a test target is declared but no matching regular target exists, safely attach it to the first available regular target in that directory group.

# Epic 3: Inline Target Configuration
**Description:** Target-specific settings (Swift Settings, Resources, Exclusions) are defined directly inside the target object, ensuring high cohesion.

**User Story 3.1: Inline Parameters Processing**
* **As a** developer,
* **I want** to define custom SPM parameters directly inside the target's JSON definition,
* **So that** I don't have to maintain a separate global parameters dictionary.
* **Acceptance Criteria:**
  * The target schema accepts a `parameters: [String]` array.
  * *Example:* `"parameters": ["swiftSettings: [.enableUpcomingFeature(\"StrictConcurrency\")]", "resources: [.process(\"Files\")]"]`
  * These strings are passed down to the internal `ParsedPackage` representation without modification.

**User Story 3.2: Verbatim Parameter Injection**
* **As a** developer,
* **I want** the generator to inject my inline parameters exactly as written into the `Package.swift` file,
* **So that** SPM compiles the target exactly as intended.
* **Acceptance Criteria:**
  * When writing a `.target(...)` or `.testTarget(...)` block, the plugin iterates over the target's `parameters` array.
  * Each parameter string is appended as a comma-separated argument within the target's definition in the final `Package.swift` file.

# Epic 4: Automated External Dependency Resolution
**Description:** The plugin queries the SPM Plugin API to discover external packages and dynamically formats their products, eliminating manual alias dictionaries.

**User Story 4.1: Dynamic Discovery via SPM Plugin API**
* **As a** developer,
* **I want** the plugin to automatically scan my root `Package.swift`'s dependencies,
* **So that** I don't have to manually write `.product(name: "...", package: "...")` aliases for external libraries.
* **Acceptance Criteria:**
  * The plugin reads `context.package.dependencies` from the SPM Plugin API.
  * It iterates through `dependency.package.products` to build an in-memory dictionary mapping product names to formatted SPM product strings.
  * Uses `dependency.package.displayName` (or equivalent identity) for the `package:` argument.

**User Story 4.2: Manual Mapping Override**
* **As a** developer,
* **I want** to provide explicit mapping overrides via `mappers.imports` in my configuration file,
* **So that** I can manually resolve naming collisions between two external packages, or rename internal module imports.
* **Acceptance Criteria:**
  * The plugin merges the manual `mappers.imports` object with the automatically discovered external products.
  * Explicit keys in the configuration file always overwrite automatically discovered keys.

# Epic 5: Zero-Exclusion Dependency Filtering
**Description:** The plugin drops unknown dependencies strictly based on mathematical set intersections, rendering legacy "Apple SDK" hardcoded exclusion lists obsolete.

**User Story 5.1: Strict Import Intersection**
* **As a** developer,
* **I want** the plugin to only link recognized local targets and recognized external products,
* **So that** Apple system frameworks (like `Foundation`, `UIKit`) are automatically ignored without me having to maintain a list of them.
* **Acceptance Criteria:**
  * The plugin collects all raw `import` statements found in a target's `.swift` files using the `package-generator-cli`.
  * The plugin creates a combined `Set<String>` of all valid local targets AND all valid external products (from Epic 4).
  * The final dependency list for a target is strictly the intersection of its raw imports and the combined valid Set.
  * "Self-imports" (a target importing its own name) are automatically filtered out.

**User Story 5.2: Unresolved Import Diagnostics**
* **As a** developer,
* **I want** the plugin to log a warning when it drops an unrecognized import,
* **So that** I can catch third-party libraries that I forgot to add to my root `Package.swift`.
* **Acceptance Criteria:**
  * When an import is filtered out, the plugin prints a diagnostic warning: `ℹ️ Dropped unresolved import '[Name]'. If this is a system framework, ignore this. Otherwise, ensure it is linked in the root Package.swift.`
  * A boolean config flag `silenceUnresolvedImportWarnings` can optionally suppress these logs.

# Epic 6: Package.swift Code Generation
**Description:** The final phase where the plugin constructs the actual `Package.swift` file according to formatting rules and structural grouping.

**User Story 6.1: Header Injection**
* **As a** developer,
* **I want** the plugin to prepend a template file to the generated output,
* **So that** the base `Package(name: "...", platforms: [...])` structure is preserved.
* **Acceptance Criteria:**
  * Reads the contents of the file specified in `headerFileURL` (e.g., `PackageHeader.swift`).
  * Writes this directly to the top of `Package_generated.swift` (dry run) or `Package.swift`.

**User Story 6.2: Pragma Mark Grouping**
* **As a** developer,
* **I want** targets to be grouped by their parent directory using `// MARK: -` comments,
* **So that** the massive `Package.swift` file remains easily navigable.
* **Acceptance Criteria:**
  * If `pragmaMark: true`, sort all targets by their parent group name (derived from their path), then by target type (regular, then tests), then alphabetically.
  * Output `// MARK: - \n // MARK: [GroupName]` before beginning a new group of targets.

**User Story 6.3: SPM Formatting & Output**
* **As a** developer,
* **I want** the generated targets to be properly indented and formatted,
* **So that** the file adheres to standard Swift formatting guidelines.
* **Acceptance Criteria:**
  * Generates an array of `.library(name: "...", targets: ["..."])` for all non-test targets under `package.products.append(...)`.
  * Generates the `.target()`, `.testTarget()`, and `.macro()` blocks under `package.targets.append(...)`.
  * Uses the `spaces` configuration value to control indentation levels consistently.

# Epic 7: Advanced Architecture Utilities
**Description:** Supplementary tooling executed during generation to assist with large-scale project health and modularity.

**User Story 7.1: Exported Files Generation**
* **As a** developer,
* **I want** the plugin to generate `exported.swift` files for my modules,
* **So that** downstream targets automatically inherit dependencies without explicitly importing them.
* **Acceptance Criteria:**
  * If `generateExportedFiles: true`, create a file in each non-test target's directory.
  * The file contains `@_exported import [DependencyName]` for every valid dependency linked to that target.
  * Respects `exportedFilesRelativePath` if the file should be placed in a specific subfolder (e.g., `Generated/`).

**User Story 7.2: Unused Target Detection**
* **As a** developer,
* **I want** to be warned if a local target is never imported by any other target,
* **So that** I can identify and delete dead code or orphaned modules.
* **Acceptance Criteria:**
  * If `unusedThreshold` is defined (e.g., `0`), the plugin analyzes the dependency graph of all local targets.
  * Emits a console warning for any local target whose usage count is less than or equal to the threshold: `📦 [TargetName] is used [Count] times`.

**User Story 7.3: Leaf Node / Dependency Weight Calculation**
* **As a** developer,
* **I want** to see how many dependencies a target relies on directly in the `Package.swift` file,
* **So that** I can easily spot bloated modules.
* **Acceptance Criteria:**
  * If `leafInfo: true`, the plugin calculates the total number of dependencies for each target.
  * Injects a comment next to the target declaration: `// [TotalDependencies|LocalDependencies]`.
  * Appends a truck emoji `🚛` to the comment of the target that has the highest number of local dependencies.