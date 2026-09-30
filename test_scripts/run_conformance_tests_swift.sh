#!/bin/bash
# Conformance-test runner for a Swift Package Manager build folder — activate-only variant.
# Attaches to the working folder populated by prepare_environment_swift.sh, drops the
# conformance test folder's Swift files into Tests/ConformanceTests, and runs that target.
# Usage: run_conformance_tests_swift.sh <build_folder> <conformance_tests_folder>
# Exit codes: 69 unrecoverable (usage, toolchain, prepared environment missing),
#             1 no tests discovered, otherwise the exit code of `swift test`.

UNRECOVERABLE_ERROR_EXIT_CODE=69

echo "===== [1/8] Toolchain check (activate-only variant) ====="
if ! command -v swift >/dev/null 2>&1; then
  echo "Error: 'swift' not found on PATH. Install Xcode or the Swift toolchain."
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
echo "swift resolved from: $(command -v swift)"
swift --version 2>&1

echo "===== [2/8] Argument validation ====="
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Error: expected <build_folder> <conformance_tests_folder>."
  echo "Usage: $0 <build_folder> <conformance_tests_folder>"
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
SOURCE_FOLDER="$1"
echo "Invocation directory: $(pwd)"
echo "Build folder (read-only): $SOURCE_FOLDER"

echo "===== [3/8] Resolve conformance tests folder ====="
case "$2" in
  /*) CONFORMANCE_TESTS_FOLDER="$2" ;;
  *)  CONFORMANCE_TESTS_FOLDER="$(pwd)/$2" ;;
esac
echo "Conformance tests folder (read-only): $CONFORMANCE_TESTS_FOLDER"
if [ ! -d "$CONFORMANCE_TESTS_FOLDER" ]; then
  echo "Error: conformance tests folder '$CONFORMANCE_TESTS_FOLDER' does not exist."
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi

echo "===== [4/8] Verify prepared environment ====="
WORKING_FOLDER="/tmp/swift_$(basename "$SOURCE_FOLDER")"
SCRATCH_PATH="$WORKING_FOLDER/.build"
CACHE_PATH="$WORKING_FOLDER/.swiftpm-cache"
CONFIG_PATH="$WORKING_FOLDER/.swiftpm-config"
echo "Working folder: $WORKING_FOLDER"
if [ ! -d "$WORKING_FOLDER" ] || [ ! -f "$WORKING_FOLDER/Package.swift" ] || [ ! -d "$SCRATCH_PATH" ]; then
  echo "Error: prepared environment missing at $WORKING_FOLDER (expected Package.swift and .build/)."
  echo "Did you run prepare_environment_swift.sh \"$SOURCE_FOLDER\" first?"
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
echo "Found prepared environment: $SCRATCH_PATH"

echo "===== [5/8] Enter working directory ====="
cd "$WORKING_FOLDER" 2>/dev/null
if [ $? -ne 0 ]; then
  echo "Error: cannot enter working folder '$WORKING_FOLDER'."
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
echo "Now in: $(pwd)"

echo "===== [6/8] Activate prepared environment: stage conformance tests into Tests/ConformanceTests ====="
TARGET_DIR="$WORKING_FOLDER/Tests/ConformanceTests"
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: $TARGET_DIR missing. The package must declare a ConformanceTests test target."
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
echo "+ rm -f \"$TARGET_DIR\"/*.swift"
rm -f "$TARGET_DIR"/*.swift
count=0
for f in "$CONFORMANCE_TESTS_FOLDER"/*.swift; do
  [ -e "$f" ] || continue
  echo "+ cp \"$f\" \"$TARGET_DIR/\""
  cp "$f" "$TARGET_DIR/"
  count=$((count + 1))
done
echo "Staged $count Swift test file(s) from $CONFORMANCE_TESTS_FOLDER"
if [ $count -eq 0 ]; then
  echo "Error: no *.swift files found in $CONFORMANCE_TESTS_FOLDER."
  exit 1
fi

echo "===== [7/8] (no install step in activate-only variant) ====="

echo "===== [8/8] Run conformance tests ====="
TEST_CMD="swift test --filter ConformanceTests --scratch-path $SCRATCH_PATH --cache-path $CACHE_PATH --config-path $CONFIG_PATH --skip-update"
echo "+ $TEST_CMD"
output=$(swift test --filter ConformanceTests --scratch-path "$SCRATCH_PATH" --cache-path "$CACHE_PATH" --config-path "$CONFIG_PATH" --skip-update 2>&1)
exit_code=$?
echo "$output"
if echo "$output" | grep -q "Executed 0 tests"; then
  echo ""
  echo "Error: no conformance tests were discovered in target ConformanceTests."
  echo "----- summary -----"
  echo "Variant: activate-only | Exit code: 1 | Tests: $CONFORMANCE_TESTS_FOLDER | Working folder: $WORKING_FOLDER"
  exit 1
fi
echo "----- summary -----"
echo "Variant: activate-only"
echo "Test command: $TEST_CMD"
echo "Conformance tests folder: $CONFORMANCE_TESTS_FOLDER"
echo "Working folder: $WORKING_FOLDER"
echo "Exit code: $exit_code"
exit $exit_code
