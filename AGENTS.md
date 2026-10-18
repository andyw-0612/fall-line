# Development

Read README.md first. The completed app is native SwiftUI/AppKit in native/;
catalogue-data/ contains the bundled public dataset and recommendation source.

main contains mouse/trackpad input only, with no camera permission or CV runtime.
experimental adds Google MediaPipe camera tracking, palm-rest taps and debug UI.
Keep these branch boundaries. Preserve gesture semantics and the bounded product
transition sequence. Do not replace the finished app with an older demo/export.

Never commit credentials, local session state, model runtimes or build outputs.
API credentials belong in the user's Keychain. Keep third-party notices.
Build: ./native/build-app.sh. Tests: ./native/test.sh and
python3 native/catalogue/test_bridge.py (after building).
