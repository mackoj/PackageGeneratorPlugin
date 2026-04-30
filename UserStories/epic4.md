# Epic 4: Package.swift Generation

**Description:** The actual writing of the `Package.swift` file, ensuring formatting, grouping, and injection of custom settings.

**User Story 4.1: Custom Target Parameters**
* **As a** developer,
* **I want** to inject custom Swift settings, resources, or exclusions into specific targets,
* **So that** I can support things like strict concurrency, specific asset folders, or macro plugins.
* **Acceptance Criteria:**
  * Reads `targetsParameters` from the config (e.g., `swiftSettings: [.enableUpcomingFeature(...)]`).
  * Injects these verbatim into the corresponding `.target` or `.testTarget` block.
  * Correctly formats the `exclude: [...]` arrays by merging them with any dynamically discovered exclusions.

**User Story 4.2: Pragma Mark Grouping**
* **As a** developer,
* **I want** my targets to be grouped by their parent directory using `// MARK: -` comments,
* **So that** the massive `Package.swift` file remains human-readable.
* **Acceptance Criteria:**
  * If `pragmaMark: true` is set, sort the targets by their parent directory name first, then by target type, then alphabetically.
  * Print `// MARK: - \n // MARK: GroupName` before a new group of targets begins.

**User Story 4.3: Header Injection & File Writing**
* **As a** developer,
* **I want** the generated file to include a standard header with the `Package` definition,
* **So that** the generated targets are appended to a valid SPM package structure.
* **Acceptance Criteria:**
  * Reads the file specified in `headerFileURL` (e.g., `PackageHeader.swift`).
  * Writes the header to the top of `Package.swift`.
  * Appends `.library()` products for all non-test targets.
  * Appends `.target()`, `.testTarget()`, or `.macro()` declarations.

