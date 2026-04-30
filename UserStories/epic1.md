# Epic 1: Configuration Management

**Description:** The plugin relies on a centralized configuration file to dictate how the `Package.swift` file should be generated, including exclusions, custom mappings, and structural rules.

**User Story 1.1: Automatic Configuration Resolution**
* **As a** developer,
* **I want** the plugin to automatically find my configuration file (checking `.json`, `.yml`, or `.yaml` formats) or accept a custom path via CLI arguments,
* **So that** I don't have to hardcode the configuration file name in my build scripts.
* **Acceptance Criteria:**
  * Checks for `--confFile` in CLI arguments first.
  * Falls back to checking for `packageGenerator.yaml`, `packageGenerator.yml`, and `packageGenerator.json` in the root directory.
  * If no file exists, generates a default `packageGenerator.json` and a default `header.swift` file, then gracefully exits with a warning.

**User Story 1.2: Cross-Format Support (YAML & JSON)**
* **As a** developer,
* **I want** to be able to write my configuration in YAML,
* **So that** it is easier to read and maintain than strict JSON.
* **Acceptance Criteria:**
  * If a `.yaml` or `.yml` file is detected, the plugin invokes a `yaml-converter` CLI tool to temporarily convert it to JSON before decoding the configuration into Swift structs.
