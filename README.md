# Fall Line

Built for DubHacks 2026. For project description, see [DEVPOST](https://devpost.com/software/fall-line?ref_content=my-projects-tab&ref_feature=my_projects).

## Requirements

- macOS 14 or later
- Swift 6.1 or later (Xcode or Xcode Command Line Tools)
- Python 3

## Run

```sh
git clone https://github.com/andyw-0612/fall-line.git
cd fall-line
./native/run.sh
```

The build includes the 450-product shoe catalog. No extra Python packages are needed.

## Recommendations

Open **Settings** or **Taste & settings**:

- Choose **Local vectors + text** to run without an API key.
- For **Gemini AI**, enter your own Gemini API key and save it in Keychain.

## Controls

- **Input → Drawing input** selects Mouse or Trackpad.
- Mouse: click, hold, draw through the menu, then release.
- Trackpad: keep the pointer over the product, place two fingers, draw, then lift.
- Pause while drawing to reveal the menu.
- **Right/Left Arrow:** next/previous product.
- **Escape:** cancel. **Cmd-Z:** undo feedback.

## Camera and palm rest

These features are on the `experimental` branch:

```sh
git switch experimental
./native/run.sh
```

This branch requires Apple Silicon. Its first run downloads the Google MediaPipe runtime and model.
Open **Input → Palm Rest Settings** to choose and enable a camera. Tap the palm rest, then draw with your index finger.
Open **Input → Camera & Palm Rest Debug** (**Cmd-Shift-D**) for the live preview, skeleton and trails.
Palm-rest taps require a compatible MacBook accelerometer; Desk View requires supported camera hardware.
