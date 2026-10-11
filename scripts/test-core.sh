#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Override SWIFT_BIN for a downloaded cloud toolchain; on Mac, use Xcode's Swift.
SWIFT_BIN="${SWIFT_BIN:-swift}"
cache="${LIFTLOG_CACHE:-$PWD/.build/portable-cache}"
mkdir -p "$cache/clang" "$cache/modules" "$cache/config" "$cache/security"
export CLANG_MODULE_CACHE_PATH="$cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$cache/modules"
"$SWIFT_BIN" test --cache-path "$cache" --config-path "$cache/config" --security-path "$cache/security" --jobs 4
