# Epic 3: Dependency Resolution & Filtering

**Description:** The plugin must figure out what each target depends on by analyzing Swift files, while filtering out noise like Apple SDKs or excluded imports.

**User Story 3.1: Import Extraction via CLI**
* **As a** developer,
* **I want** the plugin to delegate the heavy lifting of reading `.swift` files and parsing `import` statements to a dedicated CLI tool (`package-generator-cli`),
* **So that** the main plugin remains fast and doesn't load thousands of files into memory at once.
* **Acceptance Criteria:**
  * Serializes the discovered targets to a temporary JSON file.
  * Invokes `package-generator-cli` with the input JSON and an output path.
  * Reads the output JSON back into `ParsedPackage` structs containing a unique list of dependencies for each target.

**User Story 3.2: Dependency Exclusions**
* **As a** developer,
* **I want** to exclude specific imports globally,
* **So that** internal Apple frameworks (e.g., `Foundation`, `UIKit`) or specific ignored libraries aren't added to my `Package.swift` as dependencies.
* **Acceptance Criteria:**
  * Reads `exclusions.apple` and `exclusions.imports` from the config.
  * Removes these values from every target's dependency array.
  * Prevents "self-imports" (a target accidentally depending on itself).

**User Story 3.3: Dependency Mapping / Aliasing**
* **As a** developer,
* **I want** to map specific `import` statements to custom SPM product declarations,
* **So that** third-party dependencies (like Firebase or Lottie) are correctly formatted as `.product(name: "...", package: "...")`.
* **Acceptance Criteria:**
  * Reads `mappers.imports` from the config.
  * Replaces raw import strings with the mapped string in the final `Package.swift` output.

