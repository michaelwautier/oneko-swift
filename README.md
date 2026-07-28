# oneko-swift — native macOS port of oneko

A native Swift/AppKit port of the classic [oneko](https://github.com/adryd325/oneko.js):
a little cat that chases your mouse cursor around the screen. No Electron, no
dependencies, no network access, no permission prompts — a ~320 KB app that
does one thing well.

[![Latest release](https://img.shields.io/github/v/release/oneko-swift/oneko-swift)](https://github.com/oneko-swift/oneko-swift/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platform: macOS 13+](https://img.shields.io/badge/platform-macOS%2013%2B-black)

Requires macOS 13 (Ventura) or later. Universal binary — Apple Silicon and
Intel.

![oneko chasing the cursor](docs/previews/oneko-live-preview.gif)

## Install

### Via Homebrew

```sh
brew install --cask oneko-swift/tap/oneko
```

Homebrew 6+ asks you to trust third-party taps first: `brew trust oneko-swift/tap`.

### Manually

1. Download `Oneko-<version>.zip` from the
   [latest release](https://github.com/oneko-swift/oneko-swift/releases/latest).
2. Unzip it and drag `Oneko.app` into `/Applications`.
3. Authorize the app on first launch (below).

### First launch (both methods)

The app is not notarized (that requires a paid Apple Developer account; this
is a free open-source project), so Gatekeeper blocks the first launch. The
entire source is in this repo and `./build.sh` produces the same app in
seconds if you'd rather not trust a downloaded binary. To authorize it:

1. Open `Oneko.app` once — macOS shows a warning and refuses to run it.
2. Go to System Settings → Privacy & Security, scroll down to the notice
   about Oneko and click **Open Anyway** (on macOS 14 and older you can
   instead right-click `Oneko.app` → Open).
3. Launch it again and confirm. The cat appears; this is only needed once.

Terminal alternative to step 2, same effect:

```sh
xattr -dr com.apple.quarantine /Applications/Oneko.app
```

Building from source (below) avoids the Gatekeeper step entirely.

## Raycast extension

[`raycast/`](raycast/) holds a Raycast extension with four commands: Toggle
Cat, Change Skin (a grid with sprite previews), Set Speed, and Quit Oneko.
It is a remote control, not a replacement — it drives the installed app
through the URL scheme below, so install Oneko first (see above). Until the
extension reaches the Raycast Store, import it locally:

```sh
cd raycast && npm install && npx ray develop
```

## Scripting (oneko:// URL scheme)

Anything that can open a URL can control Oneko — Raycast Quicklinks, Apple
Shortcuts, or `open` in a script. Opening any `oneko://` URL launches the
app if it isn't running.

| URL | Effect |
| --- | --- |
| `oneko://show`, `oneko://hide`, `oneko://toggle` | Show or hide the cat |
| `oneko://skin/<id>` | Switch sprite, e.g. `oneko://skin/sakura` |
| `oneko://speed/<slow\|normal\|fast>` | Set the chase speed |
| `oneko://quit` | Quit the app |

Skin ids are the sheet file names in [`Resources/`](Resources/) (the classic
cat is `cat`).

## Build & run

```sh
./build.sh
open build/Oneko.app
```

Requires Xcode command line tools. No other dependencies.

## Features

Everything lives in the menu bar item (cat icon) — there is no settings
window, no onboarding, no Dock icon. Just the cat.

- **Click-through overlay** — borderless and transparent; the cat never
  intercepts a click and renders above every app, including full-screen apps,
  on all Spaces.
- **Faithful port** of the original state machine: 8-directional running,
  alert, idle, random face-washing and wall-scratching (when idling near a
  screen edge), tired → sleeping after prolonged inactivity.
- **27 sprite variants**, grouped as Classic (cat, dog), X11 Originals (tora,
  sakura, tomoyo, the BSD daemon) and Community (21 sheets of community pixel
  art) — each menu entry shows the sprite's idle frame as its icon. See the
  [gallery](#sprite-gallery) below.
- **Speed** — Slow, Normal (the classic 10 px per 100 ms tick) or Fast.
- **Choose a display**: by default the cat chases the cursor across every
  monitor; lock it to one and it waits at that screen's edge while the cursor
  is elsewhere. The lock is remembered by the monitor's hardware identity, so
  it survives unplugging, docking and reboots — even when macOS reshuffles
  display IDs.
- **Horizontal-only mode**: the cat ignores the cursor's vertical position and
  stays pinned to a row along the top or bottom screen edge (your pick),
  following only the cursor's x — like the original strip-of-desk cat. It
  still follows the cursor across monitors, running to the new screen's edge
  row.
- **Multi-monitor done right**: works with mixed Retina/non-Retina setups and
  non-rectangular arrangements — the cat is confined to real screens, never
  parked in the dead space between them.
- **Launch at Login** (via the system `SMAppService` — shows up in System
  Settings → Login Items like a good citizen), and **Show/Hide** that reduces
  the app to literally zero CPU.
- **Private by construction**: the app never opens a network connection — no
  updater, no telemetry, no downloads (updates come through Homebrew or
  GitHub Releases). It needs no permissions either: no Accessibility, no
  Input Monitoring, no Screen Recording. There is nothing to grant and
  nothing to trust beyond the ~320 KB binary itself.
- **Lightweight**: ~0.1% CPU idle, ~1.5% mid-chase, ~12 MB, exactly zero when
  hidden — see [Performance](#performance).

## Performance

A pixel cat that animates 10 times a second doesn't need a game engine. There
is no GPU render loop here, no display link, no full-screen transparent layer
redrawn every vsync — the app is a single 32×32 window that moves, driven by
one timer on the main run loop. That design keeps it invisible in Activity
Monitor and off your battery report.

Measured with `top` on an Apple Silicon Mac:

| State                         | CPU   | Memory | Power score |
| ----------------------------- | ----- | ------ | ----------- |
| Cat visible, idle or sleeping | ~0.1% | ~12 MB | ~0.4        |
| Cat chasing a moving cursor   | ~1.5% | ~12 MB | ~1.5        |
| Cat hidden                    | 0.0%  | ~12 MB | 0.0         |

Why it stays that cheap:

- **One timer, nothing else.** A single 100 ms `Timer` (20 ms tolerance, so
  wakeups coalesce with other system activity) drives the mouse poll, the state
  machine and the sprite swap. No display link, no event tap, no accessibility
  API — `NSEvent.mouseLocation` is a cheap read that needs no permissions.
- **No drawing code runs per frame.** The cat is one 32×32 `CALayer`; a frame
  change is a layer-contents swap to an already-decoded `CGImage`, and movement
  is a window-origin change. Scaling (nearest-neighbor, for crisp pixels) is
  done by the compositor.
- **Identical frames are never recommitted.** An idle or sleeping cat sends
  zero updates to WindowServer, even though the timer still polls the mouse
  10× per second.
- **Only the sprite sheet in use is resident** (~130 KB decoded). The 27 menu
  icons are standalone 32×32 copies, not crops retaining their full sheets.
- **Hide Cat means zero.** Hiding stops the timer, orders the window out and
  ends the app's activity assertion, so macOS puts the process in App Nap. No
  sleep assertions are ever held (`pmset -g assertions` stays clean).
- **320 KB universal binary, 768 KB bundle**, no frameworks beyond AppKit.

Check it yourself while the app runs:

```sh
top -l 3 -pid $(pgrep -x Oneko) -stats cpu,power,mem
```

## Layout

- `Sources/CatController.swift` — timer + state machine (port of oneko.js logic,
  adapted to AppKit's y-up coordinates)
- `Sources/TargetStrategy.swift` — the single swappable target-position piece:
  `FullChaseStrategy` (classic 2D) vs `HorizontalPinnedStrategy` (pinned row)
- `Sources/CatWindow.swift` — transparent click-through overlay window
- `Sources/SpriteSheet.swift` — slices the 256×128 sheets into frames; the
  sprite variant catalog (with menu grouping) lives here
- `Sources/AppDelegate.swift` — menu bar UI, settings (UserDefaults),
  launch-at-login via `SMAppService`
- `Resources/*.png` — the 27 sprite sheets, all in the oneko.js 256×128 layout
- `tools/makesheet.swift` — builds a sheet from the original X11 oneko XBM
  bitmaps + transparency masks, for any animal in the oneko sources
- `tools/makepreviews.swift` — regenerates the animated README previews in
  `docs/previews/` from `Resources/`

Settings persist in `defaults` domain `app.oneko.Oneko`.

## Sprite gallery

### Classic

| ![cat](docs/previews/oneko.png) | ![dog](docs/previews/dog.png) |
| :-----------------------------: | :---------------------------: |
|               Cat               |              Dog              |

### X11 Originals

| ![tora](docs/previews/tora-x11.png) | ![sakura](docs/previews/sakura.png) | ![tomoyo](docs/previews/tomoyo.png) | ![bsd](docs/previews/bsd.png) |
| :---------------------------------: | :---------------------------------: | :---------------------------------: | :---------------------------: |
|                Tora                 |               Sakura                |               Tomoyo                |          BSD Daemon           |

### Community

| ![ace](docs/previews/ace.png) | ![black](docs/previews/black.png) | ![bunny](docs/previews/bunny.png) | ![calico](docs/previews/calico.png) | ![catppuccin](docs/previews/catppuccin.png) | ![eevee](docs/previews/eevee.png) |
| :---------------------------: | :-------------------------------: | :-------------------------------: | :---------------------------------: | :-----------------------------------------: | :-------------------------------: |
|              Ace              |               Black               |               Bunny               |               Calico                |                 Catppuccin                  |               Eevee               |

| ![esmeralda](docs/previews/esmeralda.png) | ![fox](docs/previews/fox.png) | ![ghost](docs/previews/ghost.png) | ![gray](docs/previews/gray.png) | ![jess](docs/previews/jess.png) | ![kina](docs/previews/kina.png) |
| :---------------------------------------: | :---------------------------: | :-------------------------------: | :-----------------------------: | :-----------------------------: | :-----------------------------: |
|                 Esmeralda                 |              Fox              |               Ghost               |              Gray               |              Jess               |              Kina               |

| ![lucy](docs/previews/lucy.png) | ![maia](docs/previews/maia.png) | ![maria](docs/previews/maria.png) | ![mike](docs/previews/mike.png) | ![silver](docs/previews/silver.png) | ![silversky](docs/previews/silversky.png) |
| :-----------------------------: | :-----------------------------: | :-------------------------------: | :-----------------------------: | :---------------------------------: | :---------------------------------------: |
|              Lucy               |              Maia               |               Maria               |              Mike               |               Silver                |                Silver Sky                 |

| ![spirit](docs/previews/spirit.png) | ![valentine](docs/previews/valentine.png) | ![vaporwave](docs/previews/vaporwave.png) |
| :---------------------------------: | :---------------------------------------: | :---------------------------------------: |
|               Spirit                |                 Valentine                 |                 Vaporwave                 |

## License

All code is [MIT-licensed](LICENSE). The sprite art in `Resources/` is **not**
covered by the MIT license — it belongs to its original creators, listed under
[Credits](#credits).

## Credits

All sprite art belongs to its original creators.

- **Cat** (`Resources/oneko.png`) — the classic oneko sprite set, taken from
  [adryd325/oneko.js](https://github.com/adryd325/oneko.js), which in turn
  traces back to the original X11
  [oneko](<https://en.wikipedia.org/wiki/Neko_(software)>) by Masayuki Koba.
- **Dog, Tora, Sakura, Tomoyo, BSD Daemon** — generated with
  `tools/makesheet.swift` from the original oneko XBM bitmaps and transparency
  masks (oneko-sakura sources, mirrored at
  [tie/oneko](https://github.com/tie/oneko)). Tora ships without its own masks
  upstream because it shares the cat's silhouette, so the cat masks are used.
  Sakura and Tomoyo are the Cardcaptor Sakura characters added by the
  oneko-sakura fork; the BSD daemon is the `oneko -bsd` variant.
- **Maia, Vaporwave** — from
  [kyrie25/spicetify-oneko](https://github.com/kyrie25/spicetify-oneko).
- **Catppuccin** — [k01e-01/catppuccineko](https://github.com/k01e-01/catppuccineko)
  (MIT), the oneko cat in [Catppuccin](https://github.com/catppuccin/catppuccin)
  colours.
- **All other Community sheets** (Ace, Black, Bunny, Calico, Eevee, Esmeralda,
  Fox, Ghost, Gray, Jess, Kina, Lucy, Maria, Mike, Silver, Silver Sky,
  Spirit, Valentine) — from the community-maintained Oneko Source
  Database, [tallypaws/oneko_db](https://github.com/tallypaws/oneko_db)
  (linked as the sprite source by
  [lots-o-nekos](https://github.com/raynepaws/lots-o-nekos)). The Fox sheet was
  padded from 255×127 back to the standard 256×128.
