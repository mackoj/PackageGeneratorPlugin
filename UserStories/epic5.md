# Epic 5: Advanced Analytics & Utilities

**Description:** Optional tools that run during generation to help maintain the health and architecture of the codebase.

**User Story 5.1: Exported Files Generation**
* **As a** developer,
* **I want** the option to automatically generate `exported.swift` files for my modules,
* **So that** modules can easily re-export their underlying dependencies using `@_exported import`.
* **Acceptance Criteria:**
  * If `generateExportedFiles: true`, loops through all non-test targets.
  * Creates a file named `exported.swift` (or `exported_generated.swift` in dry-run) in the target's directory.
  * Populates the file with `@_exported import [DependencyName]` for every discovered dependency.

**User Story 5.2: Unused Target Detection**
* **As a** developer,
* **I want** to know if a target is rarely or never imported by other modules,
* **So that** I can clean up dead code.
* **Acceptance Criteria:**
  * Analyzes the dependency graph.
  * If a target is imported fewer times than the `unusedThreshold`, prints a warning to the console: `📦 [Target] is used X times`.

**User Story 5.3: Leaf Node Calculation**
* **As a** developer,
* **I want** to visualize how heavy my targets are in the dependency graph,
* **So that** I can refactor bottleneck modules.
* **Acceptance Criteria:**
  * If `leafInfo: true`, calculates the number of local dependencies.
  * Appends a comment directly to the target declaration in `Package.swift`: `// [TotalDependencies|LocalDependencies]`.
  * Flags the target with the absolute highest number of local dependencies with a truck emoji `🚛`.