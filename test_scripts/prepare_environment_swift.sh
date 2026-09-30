#!/bin/bash
# Prepare-environment script for a Swift Package Manager build folder.
# Stages the build into /tmp/swift_<basename> and pre-builds the package and
# its tests once, so run_conformance_tests_swift.sh can attach to it repeatedly.
# Usage: prepare_environment_swift.sh <build_folder>
# Exit codes: 0 success, 69 any failure. The working folder is left in place on purpose.

UNRECOVERABLE_ERROR_EXIT_CODE=69

echo "===== [1/6] Toolchain check ====="
if ! command -v swift >/dev/null 2>&1; then
  echo "Error: 'swift' not found on PATH. Install Xcode or the Swift toolchain."
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
echo "swift resolved from: $(command -v swift)"
swift --version 2>&1

echo "===== [2/6] Argument validation ====="
if [ -z "$1" ]; then
  echo "Error: No build folder provided."
  echo "Usage: $0 <build_folder>"
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
SOURCE_FOLDER="$1"
echo "Invocation directory: $(pwd)"
echo "Source build folder (read-only): $SOURCE_FOLDER"
if [ ! -d "$SOURCE_FOLDER" ]; then
  echo "Error: build folder '$SOURCE_FOLDER' does not exist."
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi

echo "===== [3/6] Working directory setup ====="
WORKING_FOLDER="/tmp/swift_$(basename "$SOURCE_FOLDER")"
echo "Working folder: $WORKING_FOLDER (left populated on exit; no cleanup trap)"
rm -rf "$WORKING_FOLDER"
mkdir -p "$WORKING_FOLDER"

echo "===== [4/6] Copy build into working folder ====="
echo "+ cp -R \"$SOURCE_FOLDER\"/. \"$WORKING_FOLDER\"/"
cp -R "$SOURCE_FOLDER"/. "$WORKING_FOLDER"/
rm -rf "$WORKING_FOLDER/.build"

echo "===== [5/6] Enter working directory ====="
cd "$WORKING_FOLDER" 2>/dev/null
if [ $? -ne 0 ]; then
  echo "Error: cannot enter working folder '$WORKING_FOLDER'."
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
echo "Now in: $(pwd)"
if [ ! -f "Package.swift" ]; then
  echo "Error: Package.swift not found in $(pwd). The build folder must be a Swift package."
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
if [ ! -d "Tests/ConformanceTests" ]; then
  echo "Error: Tests/ConformanceTests not found. The package must declare a ConformanceTests test target."
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi

echo "===== [6/6] Resolve dependencies and pre-build package with tests ====="
SCRATCH_PATH="$WORKING_FOLDER/.build"
CACHE_PATH="$WORKING_FOLDER/.swiftpm-cache"
CONFIG_PATH="$WORKING_FOLDER/.swiftpm-config"
mkdir -p "$CACHE_PATH" "$CONFIG_PATH"
echo "Scratch path: $SCRATCH_PATH"
echo "Cache path:   $CACHE_PATH"
start_time=$(date +%s)
echo "+ swift package --scratch-path \"$SCRATCH_PATH\" --cache-path \"$CACHE_PATH\" --config-path \"$CONFIG_PATH\" resolve"
if ! swift package --scratch-path "$SCRATCH_PATH" --cache-path "$CACHE_PATH" --config-path "$CONFIG_PATH" resolve; then
  echo "Error: dependency resolution failed (cwd $(pwd))."
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
echo "+ swift build --build-tests --scratch-path \"$SCRATCH_PATH\" --cache-path \"$CACHE_PATH\" --config-path \"$CONFIG_PATH\" --skip-update"
if ! swift build --build-tests --scratch-path "$SCRATCH_PATH" --cache-path "$CACHE_PATH" --config-path "$CONFIG_PATH" --skip-update; then
  echo "Error: pre-build failed (cwd $(pwd))."
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
end_time=$(date +%s)
echo "----- summary -----"
echo "Language: swift"
echo "Working folder: $WORKING_FOLDER"
echo "Isolation root: $SCRATCH_PATH (+ $CACHE_PATH)"
echo "Prepared in $((end_time - start_time)) seconds, exit code 0"
exit 0
