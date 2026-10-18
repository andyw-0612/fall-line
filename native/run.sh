#!/bin/zsh
set -euo pipefail
TASK_NATIVE_DIR=${0:A:h}
"$TASK_NATIVE_DIR/scripts/prepare-mediapipe.sh"
"$TASK_NATIVE_DIR/build-app.sh"
/usr/bin/open "$TASK_NATIVE_DIR/Build/Marking Menu.app"
