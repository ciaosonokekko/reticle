<div align="center">

<img src="assets/icon.png" alt="Reticle" width="160" />

# Reticle

**Pixel-perfect alignment guides for the macOS “Arrange Displays” panel.**

[![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift)](https://swift.org)
[![AppKit](https://img.shields.io/badge/AppKit-pure-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)](#-license)

</div>

---

Got multiple monitors and want them **pixel-perfect aligned** in the *Arrange Displays* sheet? macOS gives you zero visual feedback. **Reticle** does.

A lightweight, click-through overlay living in your menu bar, activating **only** when you open the *Arrange Displays* sheet. Every monitor gets a faint crosshair at its center; the moment two centers line up, the guide **snaps to full opacity** and stretches across the canvas — exactly like Photoshop or Figma smart guides.

## ✨ Features

- 🎯 **Faint center crosshairs** drawn inside each display (alpha 0.5).
- ⚡ **Visual snap**: full-opacity, thicker line across the canvas the instant centers align.
- 🎨 **System accent color**: lines and icon follow the user's *Settings → Appearance* accent and update live.
- 🖱️ **Click-through overlay**: never steals focus, never eats mouse events.
- 🧭 **Auto-trigger**: appears only when the *Arrange Displays* sheet is open, disappears when you close it.
- 🥷 **Menu bar app** (`LSUIElement`): no Dock icon, no main window.
- 🪶 **Zero dependencies**: pure AppKit + Accessibility API. No SwiftUI, no pods, no SPM.

## 🚀 Quick start

```bash
git clone git@github.com:ciaosonokekko/reticle.git
cd reticle/DisplayAlignGuide
open DisplayAlignGuide.xcodeproj
```

Hit **⌘R** in Xcode. On first launch macOS adds the app to the *Accessibility* list (disabled): just **flip the toggle** in *Settings → Privacy & Security → Accessibility*. You don't need to drag or browse for the binary — it's already there.

Then, from the menu bar (`display.2` symbol):

| Menu item | What it does |
|---|---|
| **Open Arrange Displays** | Opens Displays settings and auto-presses the *Arrange…* button via Accessibility |
| **Accessibility status** | System prompt + on-screen instructions; menu title reflects current state |
| **About Reticle** | Standard About panel with the app icon |
| **Quit** | Terminates the app (including from background) |

## 🧠 How it works

1. `ForegroundWindowWatcher` polls the **Accessibility API** every 150 ms and looks for the *Arrange Displays* sheet inside `com.apple.systempreferences`'s windows.
2. Inside the sheet, the individual monitors are exposed as `AXImage` elements. Their `kAXPositionAttribute` / `kAXSizeAttribute` give the exact on-screen rectangles.
3. `GuideOverlayController` parks a `.nonactivatingPanel` `NSPanel` — borderless, transparent, click-through, top level — over the sheet, **converting AX coordinates (top-left origin) to Cocoa coordinates (bottom-left origin)** against the primary screen.
4. `GuideOverlayView` groups display centers by tolerance: group of 1 → crosshair clipped to the monitor (alpha 0.5); group of ≥ 2 → solid line spanning the full canvas (alpha 1.0, double thickness).

## 📁 Project layout

```
DisplayAlignGuide/
└── DisplayAlignGuide/
    ├── main.swift                    explicit NSApplication bootstrap
    ├── AppDelegate.swift             lifecycle + wiring
    ├── ForegroundWindowWatcher.swift AX polling, locates the Arrange sheet
    ├── GuideOverlayController.swift  NSPanel overlay + AX→Cocoa coord conversion
    ├── GuideOverlayView.swift        guide / alignment line drawing
    ├── MenuBarController.swift       NSStatusItem, menu, AppIcon, AX press
    ├── Logger.swift                  diagnostic log at /tmp/Reticle.log
    └── Info.plist                    LSUIElement = true
```

## 🛠 Requirements

- macOS **13.0+** (tested on Sonoma and Sequoia)
- Xcode **15+**
- **Accessibility** permission (to read window geometry via `AXUIElement`)

## 🔒 Privacy

No network, no telemetry, no data collection. The app is not sandboxed: it uses the Accessibility API read-only to fetch window positions and sizes for System Settings, and nothing else. Local diagnostic logs live at `/tmp/Reticle.log` and contain only window/display geometry.

## 🗺️ Roadmap

- [ ] `.icns` bundle icon for Finder
- [ ] Apple Development signing so Accessibility grants survive across releases
- [ ] Edge guides (in addition to centers), Figma-style
- [ ] "Offset readout" mode showing how many real pixels you're off-axis

## 📝 License

[MIT](LICENSE) — use it, fork it, enjoy.

---

<div align="center">

Built with 💻 and a handful of `kAX*` constants.

</div>
