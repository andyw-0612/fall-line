#!/bin/zsh
set -euo pipefail
TASK_NATIVE_DIR=${0:A:h}
TASK_DEVELOPER_DIR=$(/usr/bin/xcode-select -p)
TASK_TEST_FLAGS=()
# The standalone Command Line Tools ship Swift Testing outside SwiftPM's
# default framework search paths. Full Xcode installations need no workaround.
TASK_TEST_FRAMEWORKS="$TASK_DEVELOPER_DIR/Library/Developer/Frameworks"
if [[ -d "$TASK_TEST_FRAMEWORKS/Testing.framework" ]]; then
  TASK_TEST_FLAGS=(-Xswiftc -F -Xswiftc "$TASK_TEST_FRAMEWORKS" -Xlinker -F -Xlinker "$TASK_TEST_FRAMEWORKS" -Xlinker -rpath -Xlinker "$TASK_TEST_FRAMEWORKS" -Xlinker -rpath -Xlinker "$TASK_DEVELOPER_DIR/Library/Developer/usr/lib")
fi
swift test --package-path "$TASK_NATIVE_DIR" --disable-xctest "${TASK_TEST_FLAGS[@]}"
