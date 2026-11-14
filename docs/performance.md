# Measuring and profiling

The benchmarks live in `Benchmarks/`, a separate package on [package-benchmark](https://github.com/ordo-one/package-benchmark),
so the plugin never depends on it. Run everything from the repository root. package-benchmark uses jemalloc to count
allocations (`brew install jemalloc`); set `BENCHMARK_DISABLE_JEMALLOC=true` to build without it.

## What is measured

A command plugin cannot be imported, so `Benchmarks/Benchmarks/GeneratorBenchmarks/Shared` links the plugin's
`PackagePlugin`-free files (the same ones the test target links; see `docs/architecture-rules.md`). The benchmarks run
them on a synthetic modular app of 1,000 targets: 25 folders of 20 library targets, each with a test target, and
about 15 imports per library mixing local targets, external products, Apple SDKs, an excluded import and an unknown
module.

| Benchmark | What it runs |
|---|---|
| Decode config, 1,000 targets | `JSONDecoder` on `ConfigurationV2`, with half the targets' parameters in the legacy `targetsParameters` |
| Filter imports, 1,000 targets | `filterImports` for every target |
| Dependency graph, 1,000 targets | `computeDependencyWeight` and `analyzeDependencyGraph` |
| Render products, 1,000 targets | `generateProductsSection` |
| Render Package.swift, 1,000 targets | `renderPackageContent` with `pragmaMark` and `leafInfo` on: the whole generated file |
| Render Package.swift, 1,000 targets, default settings | the same with the default configuration |

Not measured: finding target folders on disk, running `package-generator-cli` (which reads the sources and extracts
their imports, and is benchmarked in its own repository) and the YAML-to-JSON conversion in `yaml-converter`. Those
are process launches and file system work rather than code in this repository.

## Measure a change

Save `main`'s numbers before you change code, then compare the same harness after:

```sh
swift package --package-path Benchmarks benchmark --format markdown --no-progress > .build/before.md
# … change the code …
swift package --package-path Benchmarks benchmark --format markdown --no-progress > .build/after.md
swift run --package-path Benchmarks -c release p50 .build/before.md .build/after.md
```

`p50` prints a Markdown table of each benchmark's median wall clock and mallocs, before → after, ready for the pull
request. Malloc and retain counts are deterministic; wall clock moves by 10 to 20 % between runs on a busy machine, so
rerun a benchmark before trusting a small change.

- `--filter` takes one regular expression per flag and runs the benchmarks that match any of them: repeat the flag
  (`--filter 'Decode.*' --filter 'Render products.*'`) rather than writing `A|B`.
- `benchmark baseline update` / `baseline compare` are package-benchmark's own thresholds and stay available; `p50` is
  for reading the difference at a glance.
- The generated text must not change. `Tests/PackageGeneratorTests/TargetRenderingTests.swift` checks a whole file
  byte for byte; for a larger check, render the synthetic project before and after and `cmp` the two.

## Profile a benchmark

```sh
Benchmarks/scripts/profile.sh 'Render Package.swift, 1,000 targets' 25
```

It runs that one benchmark under Instruments' Time Profiler and prints:

- **Self**: the functions the samples were in. Standard library entries here say what kind of work dominates
  (`Hasher.combine` is hashing, `_stringCompareWithSmolCheck` string comparison, `_xzm_malloc` allocation).
- **Inclusive**: the generator's functions with the most samples under them, which says whose work it is.

The trace stays in `Benchmarks/.build/profiles/` to open in Instruments. package-benchmark's ARC and malloc counting
hooks run only while measuring, so the report leaves out samples inside them.

## What has paid off

Rendering a 1,000-target `Package.swift`, before → after (Apple silicon, release build, p50):

| Benchmark | Wall clock p50 (µs) | Mallocs p50 |
|---|---|---|
| Render Package.swift, 1,000 targets | 42,598 → 8,552 (0.20x) | 154,605 → 35,631 (0.23x) |
| Render Package.swift, 1,000 targets, default settings | 38,273 → 8,372 (0.22x) | 147,124 → 35,537 (0.24x) |
| Dependency graph, 1,000 targets | 1,213 → 834 (0.69x) | 5,003 → 29 (0.01x) |
| Decode config, Filter imports, Render products | unchanged (code untouched; ±15 % run-to-run noise) | unchanged |

Released in 1.0.6. The rendered text is byte for byte the same (checked with `cmp` on the 1.1 MB synthetic output, and
end to end by running the plugin on a sample package from `main` and from the change).

- **Compute a sort key once, not in the comparator.** `generateTargetsSection` sorted the targets by pragma-mark group
  and called `pragmaMarkGroupName` (a `split` and a `String` per path component) twice per comparison: half of all
  rendering time. The group is now computed once per target and reused for the `// MARK:` lines.
- **Build a constant set once.** `renderSingleTarget` built `Set(appleDefaultSDKs)`, about 270 strings hashed, for
  every target. `appleDefaultSDKSet` is a global built on first use.
- **Count instead of filtering into an array.** The dependency graph metrics built an array of local dependencies per
  target only to count it or check that it was empty; `count(where:)` and `contains(where:)` allocate nothing.

What is left in rendering is string building in `renderSingleTarget`, about 8 µs per target. A run of the plugin is
dominated by `package-generator-cli` reading sources, so further work here buys little.
