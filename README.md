# oneko-swift — native macOS port of oneko

A native Swift/AppKit port of the classic [oneko](https://github.com/adryd325/oneko.js):
a little cat that chases your mouse cursor around the screen. No Electron, no
dependencies.

## Build & run

```sh
./build.sh
open build/Oneko.app
```

Requires Xcode command line tools. No other dependencies.

## Features

- Borderless, transparent, **click-through** overlay — the cat never intercepts
  clicks and renders above every app, including full-screen apps, on all Spaces.
- Faithful port of the original state machine: 8-directional running, alert,
  idle, random face-washing and wall-scratching (when idling near a screen
  edge), tired → sleeping after prolonged inactivity.
- **Horizontal-only mode**: the cat ignores the cursor's vertical position and
  stays pinned to a row along the top or bottom screen edge, following only the
  cursor's x. It follows the cursor's *screen* on multi-monitor setups (running
  to the new screen's edge row when the cursor changes displays) — same as in
  normal mode, where it simply chases the cursor across displays.
- **Sprite variants**: switch between the classic cat and the dog (like
  `oneko -dog` on X11) from the menu bar.
- Menu bar item (cat icon): Show/Hide Cat, Speed (Slow/Normal/Fast), Sprite
  (Cat/Dog), Horizontal-Only Mode + Dock to Top/Bottom, Launch at Login, Quit.
- Lightweight: one 100 ms timer polling `NSEvent.mouseLocation` (no
  accessibility permission needed), ~0.1% CPU.

## Layout

- `Sources/CatController.swift` — timer + state machine (port of oneko.js logic,
  adapted to AppKit's y-up coordinates)
- `Sources/TargetStrategy.swift` — the single swappable target-position piece:
  `FullChaseStrategy` (classic 2D) vs `HorizontalPinnedStrategy` (pinned row)
- `Sources/CatWindow.swift` — transparent click-through overlay window
- `Sources/SpriteSheet.swift` — slices the 256×128 sheets into frames; sprite
  variants (cat/dog) live here
- `Sources/AppDelegate.swift` — menu bar UI, settings (UserDefaults),
  launch-at-login via `SMAppService`
- `Resources/oneko.png`, `Resources/dog.png` — sprite sheets

Settings persist in `defaults` domain `com.michael.oneko`.

## Credits

The cat sprite sheet (`Resources/oneko.png`) is the classic oneko sprite set,
taken from [adryd325/oneko.js](https://github.com/adryd325/oneko.js), which in
turn traces back to the original X11
[oneko](https://en.wikipedia.org/wiki/Neko_(software)) by Masayuki Koba. The
dog sheet (`Resources/dog.png`) is generated directly from the original
oneko 1.2 XBM bitmaps and transparency masks (the `oneko -dog` variant) with
`tools/makesheet.swift`, which can build a sheet for any animal in the oneko
sources.
