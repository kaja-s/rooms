#!/bin/bash
# Unit-test runner for a Swift Package Manager build folder.
# Usage: run_unittests_swift.sh <build_folder>
# Exit codes: 1 bad usage, 2 cannot enter working folder, 69 toolchain missing,
#             otherwise the exit code of `swift test`.

echo "===== [1/7] Toolchain check ====="
if ! command -v swift >/dev/null 2>&1; then
  echo "Error: 'swift' not found on PATH. Install Xcode or the Swift toolchain (macOS: xcode-select --install or Xcode.app)."
  exit 69
fi
echo "swift resolved from: $(command -v swift)"
swift --version 2>&1

echo "===== [2/7] Argument validation ====="
if [ -z "$1" ]; then
  echo "Error: No build folder provided."
  echo "Usage: $0 <build_folder>"
  exit 1
fi
SOURCE_FOLDER="$1"
echo "Invocation directory: $(pwd)"
echo "Source build folder (read-only): $SOURCE_FOLDER"
if [ ! -d "$SOURCE_FOLDER" ]; then
  echo "Error: build folder '$SOURCE_FOLDER' does not exist."
  exit 1
fi

echo "===== [3/7] Working directory setup ====="
WORKING_FOLDER="/tmp/swift_$(basename "$SOURCE_FOLDER")"
echo "Working folder: $WORKING_FOLDER"
trap 'echo "Cleaning up working folder $WORKING_FOLDER"; rm -rf "$WORKING_FOLDER"' EXIT
rm -rf "$WORKING_FOLDER"
mkdir -p "$WORKING_FOLDER"

echo "===== [4/7] Copy build into working folder ====="
echo "+ cp -R \"$SOURCE_FOLDER\"/. \"$WORKING_FOLDER\"/"
cp -R "$SOURCE_FOLDER"/. "$WORKING_FOLDER"/
# Never reuse a build cache copied from the source folder.
rm -rf "$WORKING_FOLDER/.build"

echo "===== [5/7] Enter working directory ====="
cd "$WORKING_FOLDER" 2>/dev/null
if [ $? -ne 0 ]; then
  echo "Error: cannot enter working folder '$WORKING_FOLDER'."
  exit 2
fi
echo "Now in: $(pwd)"
if [ ! -f "Package.swift" ]; then
  echo "Error: Package.swift not found in $(pwd). The build folder must be a Swift package."
  exit 1
fi

echo "===== [6/7] Resolve dependencies into isolated caches ====="
SCRATCH_PATH="$WORKING_FOLDER/.build"
CACHE_PATH="$WORKING_FOLDER/.swiftpm-cache"
CONFIG_PATH="$WORKING_FOLDER/.swiftpm-config"
mkdir -p "$CACHE_PATH" "$CONFIG_PATH"
echo "Scratch path: $SCRATCH_PATH"
echo "Cache path:   $CACHE_PATH"
start_time=$(date +%s)
echo "+ swift package --scratch-path \"$SCRATCH_PATH\" --cache-path \"$CACHE_PATH\" --config-path \"$CONFIG_PATH\" resolve"
swift package --scratch-path "$SCRATCH_PATH" --cache-path "$CACHE_PATH" --config-path "$CONFIG_PATH" resolve
resolve_code=$?
if [ $resolve_code -ne 0 ]; then
  echo "Error: dependency resolution failed with exit code $resolve_code (cwd $(pwd))."
  exit $resolve_code
fi
end_time=$(date +%s)
echo "Dependency resolution completed in $((end_time - start_time)) seconds"

echo "===== [7/7] Run unit tests ====="
TEST_CMD="swift test --scratch-path $SCRATCH_PATH --cache-path $CACHE_PATH --config-path $CONFIG_PATH --skip-update"
echo "+ $TEST_CMD"
swift test --scratch-path "$SCRATCH_PATH" --cache-path "$CACHE_PATH" --config-path "$CONFIG_PATH" --skip-update 2>&1
exit_code=$?
echo "----- summary -----"
echo "Test command: $TEST_CMD"
echo "Working folder: $WORKING_FOLDER"
echo "Exit code: $exit_code"
exit $exit_code
