# CaptainUtils

A native Apple Silicon window manager for macOS. Drop-in replacement for [SizeUp](https://www.irradiatedsoftware.com/sizeup/), which is x86-only and will stop working when Apple removes Rosetta 2 in macOS 28.

CaptainUtils replicates SizeUp's exact keyboard shortcuts, runs natively on arm64, has no dependencies, and lives in the menu bar.

## Why

SizeUp was last updated in 2021 and is Intel-only. Rosetta 2 is being phased out starting after macOS 27 (announced at WWDC25). CaptainUtils was built as a native, minimal, free replacement that preserves SizeUp's keyboard shortcuts so muscle memory carries over.

## Features

- All 13 SizeUp window-positioning shortcuts (halves, quarters, fullscreen, center, snapback, multi-monitor)
- Native arm64 binary, no Rosetta needed
- Menu bar app with no Dock icon
- Optional Start at Login (via SMAppService)
- Restore previous window position with SnapBack

## Keyboard Shortcuts

### Halves
| Shortcut | Action |
|----------|--------|
| ⌃⌥⌘← | Left half |
| ⌃⌥⌘→ | Right half |
| ⌃⌥⌘↑ | Top half |
| ⌃⌥⌘↓ | Bottom half |

### Quarters
| Shortcut | Action |
|----------|--------|
| ⌃⌥⇧← | Upper-left |
| ⌃⌥⇧↑ | Upper-right |
| ⌃⌥⇧↓ | Lower-left |
| ⌃⌥⇧→ | Lower-right |

### Multi-Monitor
| Shortcut | Action |
|----------|--------|
| ⌃⌥← | Previous monitor |
| ⌃⌥→ | Next monitor |

### Other
| Shortcut | Action |
|----------|--------|
| ⌃⌥⌘M | Fullscreen (maximize, not native macOS fullscreen) |
| ⌃⌥⌘C | Center window |
| ⌃⌥⌘/ | SnapBack (restore previous window position) |

> Note: Spaces shortcuts (⌃⌘+arrows) from SizeUp are not implemented. Modern macOS has no public API to move windows between Spaces or switch Spaces programmatically. Those key combos remain free for you to bind elsewhere.

## How It Works

- **Global hotkeys** are registered via Carbon's `RegisterEventHotKey` (HIToolbox). This is the same API used by Rectangle, Amethyst, and every major macOS window manager. Reliable across macOS versions, including Tahoe.
- **Window manipulation** uses the Accessibility API (`AXUIElement`). The app gets the system-wide focused application, then its focused window, and sets `kAXPositionAttribute` and `kAXSizeAttribute`.
- **Multi-monitor** uses `NSScreen.screens`, sorted by `frame.origin.x` for consistent left-to-right ordering.
- **SnapBack** saves the previous window frame in memory keyed by `(pid, window title)` before every move/resize. The snapback hotkey restores it.
- **Coordinate handling**: Accessibility uses top-left origin in primary-screen coordinates. `NSScreen` uses bottom-left. The app converts between them.

## Architecture

Six Swift files, ~300 lines total.

| File | Responsibility |
|------|----------------|
| `main.swift` | NSApplication entry point |
| `AppDelegate.swift` | Menu bar UI, accessibility check, Start at Login |
| `HotkeyManager.swift` | Carbon hotkey registration and dispatch |
| `WindowManager.swift` | Accessibility API window move/resize |
| `ScreenManager.swift` | Multi-monitor geometry, target frame calculations |
| `SnapBackStore.swift` | Previous window frame storage |

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon Mac (arm64)
- Accessibility permission (required for window manipulation)

## Build

No Xcode required, only Command Line Tools.

```bash
cd CaptainUtils
make build
```

This produces `CaptainUtils.app` in the project directory. To install to `/Applications`:

```bash
make install
```

To launch:

```bash
make run
```

Or just `open CaptainUtils.app`.

## First-Run Setup

1. Launch `CaptainUtils.app`. A menu bar icon appears (rectangle/grid symbol).
2. Click the menu bar icon and choose **Open Accessibility Settings…**
3. In System Settings, toggle CaptainUtils ON under Privacy & Security → Accessibility.
4. The app detects the grant automatically (no relaunch needed). The menu item updates to **Accessibility: Granted ✓**.
5. Optionally enable **Start at Login** from the menu.

## Menu

| Item | What it does |
|------|--------------|
| About CaptainUtils | Version info |
| Shortcuts | Show all keyboard shortcuts in a dialog |
| Open Accessibility Settings… | Opens the Accessibility settings pane. Becomes "Granted ✓" once permission is given. |
| Start at Login | Toggle launching CaptainUtils automatically on macOS login |
| Quit | Quit the app |

## Code Signing

The Makefile produces an unsigned binary. macOS requires that the binary be signed (even ad-hoc) for Accessibility permission to persist across launches. After building:

```bash
codesign --force --sign - /Applications/CaptainUtils.app
```

Each rebuild changes the binary hash, which invalidates the existing Accessibility grant. You'll need to remove and re-add the app in Privacy & Security → Accessibility after each rebuild.

## Known Limitations

- **No Spaces shortcuts.** macOS has no public API for moving windows between Spaces or switching Spaces. Skipped intentionally.
- **No App Store distribution.** The Accessibility API requires non-sandboxed apps, which the App Store rejects.
- **Some Electron and Java apps** have quirky Accessibility implementations and may partially resist window resizing.

## License

MIT
