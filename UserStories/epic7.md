# Epic 7: Automatic Unresolved Dependency Filtering (Zero-Exclusion Configuration)

**Description:** The plugin should automatically filter out system frameworks (Apple SDKs) and untracked imports by strictly validating discovered `import` statements against the known graph of local targets and external packages. This eliminates the need for developers to manually maintain an `exclusions` block in the configuration file.

**User Story 7.1: Strict Dependency Validation**
* **As a** developer,
* **I want** the plugin to only add dependencies to my `Package.swift` if they are explicitly recognized as local targets or linked external packages,
* **So that** Apple SDKs (like `SwiftUI`, `Combine`, `Foundation`) are naturally filtered out without needing a hardcoded exclusion list.
* **Acceptance Criteria:**
  * The plugin maintains a `Set<String>` of all valid local target names discovered in the project.
  * The plugin maintains a `Set<String>` of all valid external product names (resolved dynamically via Epic 6).
  * When processing the raw imports for a target, the plugin performs an intersection. Any import that is *not* in the local targets set and *not* in the external products set is automatically dropped from the final `dependencies: []` array.

**User Story 7.2: Smart Console Diagnostics for Dropped Imports**
* **As a** developer,
* **I want** the plugin to log a warning when it drops an unrecognized import,
* **So that** I know if I accidentally forgot to link a third-party dependency in my root `Package.swift`, while easily ignoring the warnings for standard Apple frameworks.
* **Acceptance Criteria:**
  * When an import is filtered out (because it is neither a local target nor an external product), the plugin outputs a diagnostic message.
  * *Example Output:* `ℹ️ Dropped unresolved import 'MLCompute' in target 'Search'. (If this is a system framework, ignore this message. Otherwise, ensure it is added to the root Package.swift).`
  * Add a configuration flag (e.g., `silenceUnresolvedImportWarnings: true`) to allow teams to hide these logs once their package is stable.

**User Story 7.3: Deprecation of the `exclusions` Configuration Block**
* **As a** developer,
* **I want** the legacy `exclusions` (apple, imports, targets) arrays removed from the configuration model,
* **So that** the `packageGenerator.json` file is significantly smaller, simpler, and less prone to human error.
* **Acceptance Criteria:**
  * Remove the `Exclusions` struct from `PackageGeneratorConfiguration.swift`.
  * Delete the `AppleSDKs.swift` file from the plugin's source code entirely, as maintaining a hardcoded list of Apple frameworks is no longer necessary.
  * If the parser detects an `exclusions` block in an older `packageGenerator.json` file, it safely ignores it and prints a warning that this block is deprecated and can be safely deleted.