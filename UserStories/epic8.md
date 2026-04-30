# Epic 8: Inline Target Parameters (Deprecation of Global `targetsParameters`)

**Description:** To improve the readability and maintainability of the `packageGenerator.json` file, target-specific settings (such as `resources`, `swiftSettings`, `plugins`, etc.) should be defined directly inside the target's object within the `packageDirectoryTargets` array. This eliminates the disconnected global `targetsParameters` dictionary and ensures all configuration for a specific target lives in exactly one place.

**User Story 8.1: Encapsulate Parameters in the Target Schema**
* **As a** developer,
* **I want** to define custom settings (like `swiftSettings` or `resources`) directly inside my target objects in `packageDirectoryTargets`,
* **So that** I don't have to jump back and forth between two different parts of the JSON file to understand how a single target is configured.
* **Acceptance Criteria:**
  * [cite_start]Update the `PackageDirectoryTargets.Target` struct in `PackageGeneratorConfiguration.swift` to include a new optional property: `let parameters: [String]?`[cite: 7].
  * [cite_start]Update the `PackageInformation.PathInfo` struct to also carry this `parameters: [String]?` array alongside the existing `exclude` array[cite: 9].
  * *Example JSON structure:*
    ```json
    {
      "name": "AddCoupon",
      "type": "regular",
      "parameters": [
        "swiftSettings: [.enableUpcomingFeature(\"StrictConcurrency=minimal\")]"
      ]
    }
    ```

**User Story 8.2: Propagate Inline Parameters to the Code Generator**
* **As a** developer,
* **I want** the generator to read these inline parameters and inject them into the final `Package.swift` file,
* **So that** the generated targets retain all their required Swift settings and resources.
* **Acceptance Criteria:**
  * [cite_start]Update the `ParsedPackage` struct to include a `parameters: [String]` array[cite: 3].
  * [cite_start]During the mapping phase in `PackageGenerator.swift`, pass the `parameters` from the resolved `PackageInformation` down into the `ParsedPackage` objects[cite: 5].
  * [cite_start]Update the `fakeTargetToSwiftCode` function to read from `parsedPackage.parameters` instead of doing a dictionary lookup (`configuration.targetsParameters?[name]`)[cite: 5].
  * [cite_start]Ensure the parameters are injected verbatim into the generated Swift code, just as they were previously[cite: 5].
