# V2 Migration Guide

PackageGenerator V2 is a **complete rewrite** following a strict 7-Epic architecture from `UserStories/rewrite-epic.md`. This guide helps you understand what's new and how to migrate (if needed).

## Key Changes

### ✅ Backward Compatible
- **Old config format still works** — `targetsParameters` dict is automatically normalized to inline
- **No mandatory migration** — keep existing `packageGenerator.yaml/yml/json` as-is
- **Same output** — V2 generates identical `Package.swift` from same input

### 🆕 New Features (Optional)

| Feature | V1 | V2 | Notes |
|---------|----|----|-------|
| **Config Schema** | Legacy `targetParameters` dict | Inline `parameters` in targets | Both work, inline preferred |
| **Macro Targets** | ❌ | ✅ | Now supports `.macro()` targets |
| **Exported Files** | ✅ | ✅ Enhanced | Inline parameters support for better control |
| **Auto-Discovery** | ❌ | ✅ | Products auto-discovered from root Package.swift; `mappers.imports` rarely needed |
| **Dependency Weight** | ❌ | ✅ | `leafInfo: true` shows dep count + marks heaviest 🚛 |
| **Unused Detection** | ❌ | ✅ | `unusedThreshold` warns unused targets |
| **Verbose Scope** | Bool | String enum | `"none"` / `"plugin"` / `"cli"` / `"all"`; `true`/`false` still accepted |
| **MARK Grouping** | ✅ | ✅ Improved | Better path-based sorting |

## What's the Same

- **Configuration file location**: Still auto-finds `packageGenerator.yaml/yml/json`
- **Header file**: `headerFileURL` works identical
- **Exclusions**: `exclusions.apple/imports/targets` unchanged
- **Mappers**: `mappers.imports/targets` unchanged
- **CLI invocation**: `swift package plugin --allow-writing-to-package-directory package-generator`
- **Dry-run**: `dryRun: true` still generates `Package_generated.swift`

## What's Different

### 1. Internal Architecture (Invisible to Users)

V1: Single 800-line `PackageGenerator.swift` doing everything  
V2: Modular design across 5 files per epic:
- `TargetResolution.swift` — path discovery + test linking
- `ImportAnalysis.swift` — import filtering
- `CodeGeneration.swift` — Package.swift rendering
- `AdvancedFeatures.swift` — extras (exported files, unused detection)
- `PackageGeneratorV2.swift` — orchestrator

Users don't interact with this—V2 is just cleaner internally.

### 2. Configuration Schema (Optional Adoption)

**Old Format** (still 100% supported):
```yaml
packageDirectoryTargets:
  - path: Sources/Core
    targets:
      - name: Core
        type: regular

targetsParameters:
  Core:
    - 'resources: [.process("Assets")]'
    - 'exclude: ["__Snapshots__"]'
```

**New Format** (recommended, same output):
```yaml
packageDirectoryTargets:
  - path: Sources/Core
    targets:
      - name: Core
        type: regular
        parameters:
          - 'resources: [.process("Assets")]'
          - 'exclude: ["__Snapshots__"]'
```

**Why migrate?** Cleaner, no separate dict to maintain, easier to see target settings alongside target declaration.

**How to migrate?** Move `targetsParameters[targetName]` entries to `packageDirectoryTargets[].targets[name].parameters`. That's it.

### 3. New and Changed Settings

```yaml
# V2-only settings (old config works without these)
keepTempFiles: false        # Debug YAML→JSON conversion
leafInfo: false             # Add dependency weight comments
unusedThreshold: null       # Warn if target used ≤ this
libraryType: automatic      # "automatic" | "dynamic" | "static" product linkage

# verbose is now a string scope (bool still accepted for compatibility)
verbose: "none"             # "none" | "plugin" | "cli" | "all"
                            # true = "all", false = "none" (legacy)

# dryRun default changed from true → false
dryRun: false               # writes directly to Package.swift by default
```

**Removed settings** (silently ignored if present in old configs):
- `silenceUnresolvedImportWarnings` — no longer needed; all real unresolved imports emit a warning
- `exclusions.apple` — Apple SDKs are now always auto-excluded via built-in list

## Migration Strategies

### Strategy A: Do Nothing (Fastest)
✅ Keep current config  
✅ V2 auto-migrates `targetsParameters` → inline internally  
✅ Output identical to V1  
✅ No action needed

### Strategy B: Gradual (Recommended)
1. Keep config as-is (works with V2)
2. Over time, move targets to inline `parameters` one at a time
3. Delete `targetsParameters` once all targets migrated
4. No risk since both formats work during migration

### Strategy C: Bulk Migration (Fast)
Write a small script to convert YAML:
```python
# Pseudo-code
for target_name, params in config['targetsParameters'].items():
    # Find matching target in packageDirectoryTargets
    for group in config['packageDirectoryTargets']:
        for target in group['targets']:
            if target['name'] == target_name:
                target['parameters'] = params
# Delete targetsParameters key
del config['targetsParameters']
```

Then remove `targetsParameters` section from YAML.

## Testing Your Migration

1. **Keep dry-run enabled first**:
   ```yaml
   dryRun: true
   ```

2. **Run plugin**:
   ```bash
   swift package plugin --allow-writing-to-package-directory package-generator
   ```

3. **Review** `Package_generated.swift` and compare to old output

4. **Diff check**:
   ```bash
   diff Package.swift Package_generated.swift
   ```

5. **If identical**, enable writing:
   ```yaml
   dryRun: false
   ```

## Breaking Changes

❌ **None.** V2 is fully backward compatible with V1 configs. Old settings may emit deprecation warnings (for future cleanup), but remain functional.

## Troubleshooting

**Q: My config file is not found**  
A: V2 searches in order: `--confFile arg` → `packageGenerator.yaml` → `packageGenerator.yml` → `packageGenerator.json`. Ensure one exists at package root.

**Q: Unresolved import warnings appeared**  
A: V2 auto-discovers products from all direct dependencies in your root `Package.swift` using the URL-derived package identity. If an import is still unresolved, the product name differs from the import name — add a `mappers.imports` entry for it.

**Q: New `leafInfo` feature adds weird comments**  
A: `leafInfo: false` (default). To disable, ensure it's set in config.

**Q: Still using old format—do I need to change?**  
A: No. V2 supports both old `targetsParameters` and new inline `parameters`. No deadline to migrate.

## FAQ

**Q: What if I have both old `targetsParameters` AND new inline `parameters`?**  
A: Both merge. Inline `parameters` are applied first, then legacy `targetsParameters` merged in. If conflict (duplicate param strings), inline wins.

**Q: Will V2 modify my config file?**  
A: No. V2 reads your config and normalizes internally. Config file on disk never changes. You decide when to manually update it.

**Q: Can I use JSON config with V2?**  
A: Yes. V2 auto-detects `.json`, `.yaml`, `.yml` extensions. JSON schema identical to YAML.

**Q: Is there a V1 ↔ V2 compatibility window?**  
A: Yes, indefinite. Both formats supported forever in V2. Migrate when ready, no pressure.

## Summary

| Aspect | V1 | V2 | Action |
|--------|----|----|--------|
| **Old configs** | ✅ Works | ✅ Works | None needed |
| **New inline format** | ❌ N/A | ✅ Works | Optional: migrate gradually |
| **Macro targets** | ❌ | ✅ | Use if needed |
| **Auto-discovery** | ❌ | ✅ | Most `mappers.imports` entries can be removed |
| **verbose scope** | `Bool` | `String` | `true`/`false` still works; use `"cli"`/`"plugin"`/`"all"` for precision |
| **dryRun default** | `true` | `false` | Add `dryRun: true` if you relied on the old default |
| **New features** | N/A | `leafInfo`, `unusedThreshold` | Optional: enable in config |
| **Migration cost** | N/A | ~5 min per 10 targets | Can be done gradually or all-at-once |

## Next Steps

1. **Test V2** with current config → should produce identical Package.swift
2. **Optionally migrate** to new inline format at your pace
3. **Read** full README.md for all feature docs
4. **Check** UserStories/rewrite-epic.md for V2 architecture details
