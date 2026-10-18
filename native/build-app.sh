#!/bin/zsh
set -euo pipefail
TASK_NATIVE_DIR=${0:A:h}
TASK_BUILD_MODE=${1:-release}
if [[ "$TASK_BUILD_MODE" != release && "$TASK_BUILD_MODE" != debug ]]; then
  print -u2 'Usage: ./native/build-app.sh [release|debug]'
  exit 1
fi
swift build --package-path "$TASK_NATIVE_DIR" --configuration "$TASK_BUILD_MODE" --product MarkingMenu
TASK_BIN_DIR=$(swift build --package-path "$TASK_NATIVE_DIR" --configuration "$TASK_BUILD_MODE" --show-bin-path)
TASK_APP_PATH="$TASK_NATIVE_DIR/Build/Marking Menu.app"
mkdir -p "$TASK_APP_PATH/Contents/MacOS" "$TASK_APP_PATH/Contents/Resources"
TASK_CATALOGUE_ROOT="${FALL_LINE_CATALOGUE_ROOT:-$TASK_NATIVE_DIR/../catalogue-data}"
python3 "$TASK_NATIVE_DIR/scripts/package-catalogue.py" "$TASK_CATALOGUE_ROOT" "$TASK_APP_PATH/Contents/Resources/Catalogue"
cp "$TASK_NATIVE_DIR/Resources/Outfit.ttf" "$TASK_NATIVE_DIR/ThirdParty/Outfit-OFL.txt" "$TASK_APP_PATH/Contents/Resources/"
cp "$TASK_NATIVE_DIR/ThirdParty/QuentinRoy-Marking-Menu-LICENSE.txt" "$TASK_APP_PATH/Contents/Resources/"
cp "$TASK_BIN_DIR/MarkingMenu" "$TASK_APP_PATH/Contents/MacOS/MarkingMenu"
cp "$TASK_NATIVE_DIR/Info.plist" "$TASK_APP_PATH/Contents/Info.plist"
/usr/bin/codesign --force --sign - --identifier com.moritzvt.markingmenu "$TASK_APP_PATH"
/usr/bin/plutil -lint "$TASK_APP_PATH/Contents/Info.plist"
print "$TASK_APP_PATH"
