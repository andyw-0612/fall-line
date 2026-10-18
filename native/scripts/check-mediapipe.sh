#!/bin/zsh
set -euo pipefail
TASK_NATIVE_DIR=${0:A:h:h}
TASK_MP_DIR="$TASK_NATIVE_DIR/Build/mediapipe"
clang++ -std=c++17 -I "$TASK_NATIVE_DIR/Sources/CMediaPipe/include" -I "$TASK_NATIVE_DIR/Sources/CMediaPipe/vendor" -c "$TASK_NATIVE_DIR/Sources/CMediaPipe/MediaPipeBridge.cpp" -o "$TASK_MP_DIR/bridge.o"
TASK_BIN_DIR=$(swift build --package-path "$TASK_NATIVE_DIR" --configuration release --show-bin-path)
swiftc -O -I "$TASK_NATIVE_DIR/Sources/CMediaPipe/include" -Xcc -fmodule-map-file="$TASK_BIN_DIR/CMediaPipe.build/module.modulemap" "$TASK_NATIVE_DIR/scripts/check-mediapipe.swift" "$TASK_NATIVE_DIR/Sources/MarkingMenu/MediaPipeHandEngine.swift" "$TASK_MP_DIR/bridge.o" -lc++ -o "$TASK_MP_DIR/check-mediapipe"
"$TASK_MP_DIR/check-mediapipe" "$TASK_MP_DIR/libmediapipe.dylib" "$TASK_MP_DIR/hand_landmarker.task" "$@"
