# Epic 2: Target Discovery & Path Mapping

**Description:** The plugin must accurately traverse the file system to map source directories to SPM targets, respecting nested architectures and custom overrides.

**User Story 2.1: Explicit Target Declaration**
* **As a** developer,
* **I want** to explicitly declare directories and the targets they contain in the configuration (`packageDirectoryTargets`),
* **So that** the generator knows exactly which folders correspond to regular targets, test targets, or macro targets.
* **Acceptance Criteria:**
  * Supports `regular`, `test`, and `macro` target types.
  * Automatically infers that regular/macro targets live in `Sources/` and test targets live in `Tests/`.
  * Allows a `path` override for specific targets if they don't follow the standard `Sources/TargetName` convention.

**User Story 2.2: Shortest-Path Fallback Discovery (The Bug Fix)**
* **As a** developer,
* **I want** the plugin to safely resolve target paths when standard conventions aren't strictly followed,
* **So that** nested folders with the same name as root modules don't accidentally hijack the root module's configuration.
* **Acceptance Criteria:**
  * If a target's explicit path is declared, verify it exists.
  * If it doesn't exist, scan the `Sources` and `Tests` directories recursively.
  * If multiple directories share the exact same name (e.g., `Sources/Search/Search` and `Sources/Search`), the plugin **must always prefer the shortest path** (least depth).

**User Story 2.3: Test Target Association**
* **As a** developer,
* **I want** test targets to automatically pair with their corresponding regular targets,
* **So that** the generator understands their relationship.
* **Acceptance Criteria:**
  * Automatically strips the "Tests" suffix from a test target name to find its parent (e.g., `CatalogTests` pairs with `Catalog`).
  * If an explicit `regularTargetName` is provided in the configuration, use that instead.
  * If a test target is declared but no matching regular target exists, safely attach it to the first available regular target in that directory group.
