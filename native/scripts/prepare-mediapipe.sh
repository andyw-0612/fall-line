#!/bin/zsh
set -euo pipefail
TASK_NATIVE_DIR=${0:A:h:h}
TASK_MP_DIR="$TASK_NATIVE_DIR/Build/mediapipe"
[[ "$(uname -m)" == arm64 ]] || { print -u2 'This MediaPipe trial packages the macOS ARM64 runtime. Intel requires another runtime build.'; exit 1; }
mkdir -p "$TASK_MP_DIR"
TASK_MP_WHEEL="$TASK_MP_DIR/mediapipe-1.1.1-py3-none-macosx_11_0_arm64.whl"
if [[ ! -f "$TASK_MP_WHEEL" ]]; then
  curl --fail --location 'https://files.pythonhosted.org/packages/23/22/d113d29c97a4c9459ece90d9b70e81e790550f4ee7d0574042b0b9306ff9/mediapipe-1.1.1-py3-none-macosx_11_0_arm64.whl' -o "$TASK_MP_WHEEL"
fi
print "b22892847fbc6201959d20b2b9a1c9c34cda991e072f58ab0c38008dc789d4b1  $TASK_MP_WHEEL" | shasum -a 256 -c -
/usr/bin/unzip -p "$TASK_MP_WHEEL" mediapipe/tasks/c/libmediapipe.dylib > "$TASK_MP_DIR/libmediapipe.dylib"
if [[ ! -f "$TASK_MP_DIR/hand_landmarker.task" ]]; then
  curl --fail --location 'https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task' -o "$TASK_MP_DIR/hand_landmarker.task"
fi
print "fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1  $TASK_MP_DIR/hand_landmarker.task" | shasum -a 256 -c -
print 'MediaPipe macOS runtime and Hand Landmarker ready. No Python runtime is used by the app.'
