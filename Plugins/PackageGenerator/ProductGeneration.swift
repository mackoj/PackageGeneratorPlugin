import Foundation

// MARK: - Product rendering
//
// Kept free of `PackagePlugin` so the test target can compile this file directly.

/// Generates the products `package.products.append(contentsOf: [...])` section.
/// Includes all non-test, non-macro targets sorted alphabetically.
func generateProductsSection(
  parsedPackages: [ParsedPackage],
  config: ConfigurationV2
) -> String {
  let s1 = String(repeating: " ", count: config.spaces)

  let libs = parsedPackages
    .filter { !$0.isTest && !$0.isMacro }
    .sorted { $0.name < $1.name }

  var lines: [String] = []
  for lib in libs {
    // The product may be named differently from the target it wraps; `targets:` must
    // always reference the real target name.
    let productName = lib.productName ?? config.mappers.targets[lib.path, default: lib.name]
    let type = (lib.libraryType ?? config.libraryType).productArgument.map { "\($0), " } ?? ""
    lines.append("\(s1).library(name: \"\(productName)\", \(type)targets: [\"\(lib.name)\"])")
  }

  if lines.isEmpty {
    return "// MARK: - Targets\npackage.products.append(contentsOf: [\n])\n"
  }

  let body = lines.dropLast().map { $0 + "," }.joined(separator: "\n")
    + "\n" + lines.last!
  return "// MARK: - Targets\npackage.products.append(contentsOf: [\n\(body)\n])\n\n"
}
