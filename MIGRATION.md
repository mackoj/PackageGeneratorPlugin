# Migration Guide: Legacy → Point-Free Edition

This guide helps you migrate from the legacy PackageGenerator to the new Point-Free edition.

## Overview of Changes

### ✅ What's Better

- **Type-safe configuration** with proper nesting and validation
- **JSON Schema support** for IDE autocomplete
- **Better error messages** with specific validation errors
- **Testable architecture** with isolated effects
- **Cleaner codebase** following functional programming principles
- **Same features** - everything from the legacy version is preserved

### ⚠️ Breaking Changes

1. **Configuration format** has changed (nested structure)
2. **Some property names** have been renamed for clarity
3. **Configuration validation** is stricter (catches errors earlier)

## Step-by-Step Migration

### Step 1: Backup Your Current Config

```bash
cp packageGenerator.json packageGenerator.json.backup
```

### Step 2: Update Configuration Structure

#### Before (Legacy Format)

```json
{
  "packageDirectories": [
    "Sources/App/Feature1",
    "Sources/App/Feature2"
  ],
  "headerFileURL": "header.swift",
  "spaces": 2,
  "verbose": false,
  "pragmaMark": false,
  "dryRun": true,
  "generateExportedFiles": true,
  "exportedFilesRelativePath": "Generated",
  "mappers": {
    "targets": {
      "Sources/App/Helpers/Foundation/": "FoundationHelpers"
    },
    "imports": {
      "ComposableArchitecture": ".product(name: \"ComposableArchitecture\", package: \"swift-composable-architecture\")"
    }
  },
  "exclusions": {
    "apple": ["ARKit", "AVFoundation"],
    "imports": ["PurchasesCoreSwift"],
    "targets": ["ParserCLI"]
  },
  "targetsParameters": {
    "MyTarget": ["exclude: [\"__Snapshots__\"]"]
  },
  "keepTempFiles": false,
  "leafInfo": false,
  "unusedThreshold": null
}
```

#### After (Point-Free Format)

```json
{
  "$schema": "./packageGenerator.schema.json",
  "source": {
    "packageDirectories": [
      "Sources/App/Feature1",
      "Sources/App/Feature2"
    ],
    "headerFile": "header.swift"
  },
  "output": {
    "mode": "dryRun",
    "formatting": {
      "indentation": 2,
      "pragmaMarks": false
    }
  },
  "mapping": {
    "targets": {
      "Sources/App/Helpers/Foundation/": "FoundationHelpers"
    },
    "imports": {
      "ComposableArchitecture": {
        "product": "ComposableArchitecture",
        "package": "swift-composable-architecture"
      }
    }
  },
  "exclusion": {
    "apple": ["ARKit", "AVFoundation"],
    "imports": ["PurchasesCoreSwift"],
    "targets": ["ParserCLI"]
  },
  "features": {
    "exportedFiles": {
      "relativePath": "Generated"
    },
    "leafInfo": false,
    "unusedThreshold": null,
    "keepTempFiles": false,
    "targetParameters": {
      "MyTarget": ["exclude: [\"__Snapshots__\"]"]
    }
  },
  "verbose": false
}
```

### Step 3: Property Mapping Reference

| Legacy Property | New Location | Notes |
|----------------|--------------|-------|
| `packageDirectories` | `source.packageDirectories` | Same format |
| `headerFileURL` | `source.headerFile` | Renamed |
| `spaces` | `output.formatting.indentation` | Can be int or object |
| `pragmaMark` | `output.formatting.pragmaMarks` | Renamed |
| `dryRun` | `output.mode` | Now enum: `"dryRun"` or `"live"` |
| `mappers` | `mapping` | Renamed |
| `mappers.imports.*` | `mapping.imports.*` | Format changed (see below) |
| `exclusions` | `exclusion` | Renamed (singular) |
| `generateExportedFiles` | `features.exportedFiles` | Now object or null |
| `exportedFilesRelativePath` | `features.exportedFiles.relativePath` | Nested |
| `targetsParameters` | `features.targetParameters` | Renamed |
| `keepTempFiles` | `features.keepTempFiles` | Moved |
| `leafInfo` | `features.leafInfo` | Moved |
| `unusedThreshold` | `features.unusedThreshold` | Moved |
| `verbose` | `verbose` | Same location |

### Step 4: Import Mapping Changes

#### Legacy Format

```json
"mappers": {
  "imports": {
    "ComposableArchitecture": ".product(name: \"ComposableArchitecture\", package: \"swift-composable-architecture\")"
  }
}
```

#### New Format (Structured)

```json
"mapping": {
  "imports": {
    "ComposableArchitecture": {
      "product": "ComposableArchitecture",
      "package": "swift-composable-architecture"
    }
  }
}
```

#### New Format (Still Works - String)

```json
"mapping": {
  "imports": {
    "ComposableArchitecture": ".product(name: \"ComposableArchitecture\", package: \"swift-composable-architecture\")"
  }
}
```

Both formats are supported for backward compatibility!

### Step 5: Exported Files Changes

#### Legacy Format

```json
"generateExportedFiles": true,
"exportedFilesRelativePath": "Generated"
```

#### New Format (Enabled)

```json
"features": {
  "exportedFiles": {
    "relativePath": "Generated"
  }
}
```

#### New Format (Disabled)

```json
"features": {
  "exportedFiles": null
}
```

### Step 6: Output Mode Changes

#### Legacy Format

```json
"dryRun": true
```

#### New Format

```json
"output": {
  "mode": "dryRun"  // or "live"
}
```

#### New Format (Custom Filename)

```json
"output": {
  "mode": {
    "type": "dryRun",
    "fileName": "Package_custom.swift"
  }
}
```

### Step 7: Apple SDK Exclusions

#### Legacy Format

```json
"exclusions": {
  "apple": ["ARKit", "AVFoundation", ...]
}
```

#### New Format (Custom List)

```json
"exclusion": {
  "apple": ["ARKit", "AVFoundation", ...]
}
```

#### New Format (Use Defaults)

```json
"exclusion": {
  "apple": "default"  // Uses built-in list
}
```

## Automated Migration Script

Create a file `migrate-config.js`:

```javascript
const fs = require('fs');

const legacy = JSON.parse(fs.readFileSync('packageGenerator.json', 'utf8'));

const migrated = {
  "$schema": "./packageGenerator.schema.json",
  source: {
    packageDirectories: legacy.packageDirectories,
    headerFile: legacy.headerFileURL || "header.swift"
  },
  output: {
    mode: legacy.dryRun ? "dryRun" : "live",
    formatting: {
      indentation: legacy.spaces || 2,
      pragmaMarks: legacy.pragmaMark || false
    }
  },
  mapping: {
    targets: legacy.mappers?.targets || {},
    imports: Object.fromEntries(
      Object.entries(legacy.mappers?.imports || {}).map(([k, v]) => {
        if (v.startsWith('.product(')) {
          // Keep string format for backward compatibility
          return [k, v];
        }
        return [k, v];
      })
    )
  },
  exclusion: {
    apple: legacy.exclusions?.apple || "default",
    imports: legacy.exclusions?.imports || [],
    targets: legacy.exclusions?.targets || []
  },
  features: {
    exportedFiles: legacy.generateExportedFiles ? {
      relativePath: legacy.exportedFilesRelativePath || null
    } : null,
    leafInfo: legacy.leafInfo || false,
    unusedThreshold: legacy.unusedThreshold || null,
    keepTempFiles: legacy.keepTempFiles || false,
    targetParameters: legacy.targetsParameters || {}
  },
  verbose: legacy.verbose || false
};

fs.writeFileSync(
  'packageGenerator.new.json',
  JSON.stringify(migrated, null, 2)
);

console.log('✅ Migrated config written to packageGenerator.new.json');
console.log('📝 Review the file, then: mv packageGenerator.new.json packageGenerator.json');
```

Run it:

```bash
node migrate-config.js
```

## Validation

After migration, validate your configuration:

1. **Check schema**: If using VS Code, open your JSON file and verify no squiggly lines appear
2. **Test dry run**: Run the plugin in dry-run mode and check the output
3. **Compare**: Compare `Package_generated.swift` with your current `Package.swift`

```bash
swift package plugin package-generator
diff Package.swift Package_generated.swift
```

## Common Migration Issues

### Issue: "Invalid configuration" error

**Cause**: Missing required fields or invalid structure

**Solution**: Ensure `source.packageDirectories` and `source.headerFile` are present

### Issue: Import mappings not working

**Cause**: Format changed from string to object

**Solution**: Both formats work! Keep your existing string format or migrate to structured format

### Issue: Exported files not generating

**Cause**: Changed from boolean to object

**Solution**: Change `"generateExportedFiles": true` to:

```json
"features": {
  "exportedFiles": {}
}
```

### Issue: "Header file not found"

**Cause**: `headerFileURL` was renamed to `headerFile`

**Solution**: Update the key name in `source.headerFile`

## Rollback Instructions

If you need to rollback:

```bash
# Restore backup
cp packageGenerator.json.backup packageGenerator.json

# Revert to legacy version
# In Package.swift:
.package(url: "https://github.com/mackoj/PackageGeneratorPlugin.git", exact: "0.5.2")
```

## Support

If you encounter issues during migration:

1. Check this guide thoroughly
2. Review the [example configuration](./packageGenerator.example.json)
3. Enable verbose mode: `"verbose": true`
4. Open an issue on GitHub with your configuration

## Next Steps

After successful migration:

1. ✅ Test the plugin in dry-run mode
2. ✅ Review the generated output
3. ✅ Switch to live mode: `"mode": "live"`
4. ✅ Consider using new features like JSON Schema autocomplete
5. ✅ Explore point-free architecture benefits

Happy migrating! 🚀
