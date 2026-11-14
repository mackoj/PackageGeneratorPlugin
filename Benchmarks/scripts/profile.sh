#!/bin/sh
# Profiles one benchmark with Instruments' Time Profiler and prints its hottest functions.
# Usage, from the repository root: Benchmarks/scripts/profile.sh 'Render Package.swift, 1,000 targets' [count]
# The name is the benchmark's, matched exactly. The trace is kept in Benchmarks/.build/profiles to open in Instruments.
set -eu

name=$1
count=${2:-20}
package=$(cd "$(dirname "$0")/.." && pwd)
swift build --package-path "$package" -c release --product GeneratorBenchmarks
swift build --package-path "$package" -c release --product hotspots
bin=$(swift build --package-path "$package" -c release --show-bin-path)

out="$package/.build/profiles"
mkdir -p "$out"
trace="$out/$(echo "$name" | tr -c 'A-Za-z0-9' '-').trace"
rm -rf "$trace"
# Instruments symbolicates only a binary launched by its absolute path.
xcrun xctrace record --quiet --template 'Time Profiler' --output "$trace" --launch -- \
    "$bin/GeneratorBenchmarks" --filter "^$name\$"
xcrun xctrace export --input "$trace" \
    --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' > "$trace.xml"
"$bin/hotspots" "$trace.xml" "$count"
