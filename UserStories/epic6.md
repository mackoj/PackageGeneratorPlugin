# Epic 6: Automated External Dependency Resolution

**Description:** The plugin should automatically identify external dependencies and their vended products using the SwiftPM Plugin API, eliminating the need for developers to manually maintain the `mappers.imports` configuration block.

**User Story 1: Dynamic Discovery of External Products**
* **As a** developer,
* **I want** the plugin to automatically scan the root `Package.swift`'s external dependencies during execution,
* **So that** it can deduce the correct `.product(name: "...", package: "...")` syntax for any external `import` statements found in my Swift files.
* **Acceptance Criteria:**
  * The plugin iterates through `context.package.dependencies`.
  * For every external package, it iterates through `dependency.package.products`.
  * It dynamically builds an in-memory dictionary of `[String: String]` where the key is the `product.name` and the value is the formatted `.product(name: "...", package: "...")` string.
  * *Technical Note:* Use `dependency.package.displayName` (or the equivalent package identity string in the Plugin API) for the `package:` parameter.

**User Story 2: Automatic Mapping Injection**
* **As a** developer,
* **I want** the dynamically discovered external products to be automatically injected into the generator's dependency resolution logic,
* **So that** I don't have to define them in `packageGenerator.json`.
* **Acceptance Criteria:**
  * When generating the `dependencies: []` array for a target, the plugin checks the in-memory dictionary of discovered external products whenever it encounters an `import` that isn't a local module.
  * If `import Lottie` is found in a file, and `Lottie` exists in the dynamically generated dictionary, the plugin correctly writes `.product(name: "Lottie", package: "lottie-spm")`.

**User Story 3: Manual Mapping Override (Fallback/Conflict Resolution)**
* **As a** developer,
* **I want** any manual entries left in my `packageGenerator.json`'s `mappers.imports` block to take precedence over the automatically deduced mappings,
* **So that** I can manually resolve naming collisions (e.g., two external packages vending a product with the same name) or create custom aliases.
* **Acceptance Criteria:**
  * The plugin merges the manual `mappers.imports` dictionary with the automatically generated dictionary.
  * If a key exists in both dictionaries, the value from the manual `packageGenerator.json` configuration wins.