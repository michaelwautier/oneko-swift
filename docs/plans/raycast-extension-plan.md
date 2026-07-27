# Plan: Raycast extension for Oneko

> Temporary planning doc — delete once shipped.

## Goal

Control Oneko from Raycast: show/hide the cat, toggle horizontal-only mode, set dock edge, speed, and sprite variant — without opening the menu-bar menu.

## Current state

- The app is a menu-bar-only AppKit app (`LSUIElement`), bundle ID `com.michael.oneko`.
- All settings live in `UserDefaults` (`catHidden`, `catSpeed`, `horizontalMode`, `dockEdge`, `spriteVariant`) but are only re-read when a menu action calls `applySettings()` — there is **no external control surface**. A Raycast extension can't do anything useful until the app exposes one.

## Key decision: IPC mechanism

1. **Custom URL scheme (`oneko://`) — recommended.** Register `CFBundleURLTypes` in `Info.plist`, handle `application(_:open:)` in `AppDelegate`. Raycast runs `open -g "oneko://speed/fast"`. Pros: trivial from Node, auto-launches the app if not running, human-usable from scripts/Shortcuts too. Cons: none significant for a toy app.
2. `defaults write` + cross-process KVO observation in the app. More moving parts, silent-failure prone, and can't express verbs like "toggle".
3. DistributedNotificationCenter. Needs a posting helper binary; more friction than URL scheme.

Go with **option 1**.

## Phase 1 — App: URL command surface

- [ ] Add `CFBundleURLTypes` for scheme `oneko` to `Info.plist`.
- [ ] In `AppDelegate`, implement `application(_:open:)` parsing:
  - `oneko://show`, `oneko://hide`, `oneko://toggle`
  - `oneko://horizontal/on|off|toggle`
  - `oneko://edge/top|bottom`
  - `oneko://speed/slow|normal|fast` (map to existing 5/10/20)
  - `oneko://variant/<rawValue>` (validate against `SpriteVariant`)
  - `oneko://quit`
- [ ] Refactor the existing `@objc` menu actions so both menu and URL paths call shared setter methods (`setSpeed(_ value:)`, `setVariant(_ raw:)`, …) ending in `applySettings()` + `refreshMenuState()`. Menu wrappers stay thin.
- [ ] Unknown/invalid URLs: ignore with an `NSLog`, never crash.
- [ ] Manual test: `open -g "oneko://variant/dog"` etc. from a terminal, including when the app is not running (URL open should launch it — verify settings apply post-launch).
- [ ] Cut a release containing this (ties into the Homebrew plan's Phase 2 — sequence this first so the brew-installed app is controllable).

## Phase 2 — Extension scaffold

- [ ] `npm init raycast-extension` (React + TypeScript, `@raycast/api`). Keep it in a separate repo (`oneko-raycast`) or a top-level `raycast/` folder here — separate repo preferred if publishing to the store (store PRs vendor the extension into `raycast/extensions`).
- [ ] Extension metadata: name `oneko`, icon 512×512 (reuse a sprite frame from `docs/previews`, upscaled nearest-neighbor).

## Phase 3 — Commands

All "fire URL" commands are `mode: "no-view"` running `open -g` via `child_process.execFile`, then a `showHUD` confirmation.

- [ ] **Toggle Cat** (no-view) → `oneko://toggle`
- [ ] **Toggle Horizontal Mode** (no-view) → `oneko://horizontal/toggle`
- [ ] **Set Dock Edge** (no-view with `arguments` dropdown, or tiny list) → `oneko://edge/...`
- [ ] **Set Speed** (list: Slow/Normal/Fast) → `oneko://speed/...`
- [ ] **Choose Sprite** (list view, grouped by the same groups as `SpriteVariant.groups`, one row per variant with its preview image bundled into the extension's assets) → `oneko://variant/...`
- [ ] **Quit Oneko** (no-view) → `oneko://quit`
- [ ] Nice-to-have: read current settings for checkmarks in lists via `defaults read com.michael.oneko` (read-only is safe — writes stay URL-only).
- [ ] Error handling: if `open` fails because the app isn't installed, show a toast linking to install instructions (brew command from the Homebrew plan).

## Phase 4 — Ship

- [ ] Use locally via `npm run dev` / `npm run build` (works forever without publishing).
- [ ] Optional: publish to the Raycast Store — PR to `raycast/extensions`, needs screenshots, README, icon, and passing `npm run lint` / store review guidelines.

## Acceptance criteria

- With Oneko running: every command takes effect within ~1s and the menu-bar menu reflects the new state.
- With Oneko installed but not running: any command launches it and applies the action.
- With Oneko not installed: commands fail with a helpful toast, no cryptic errors.

## Risks / open questions

- `open -g` keeps Raycast focused (`-g` = don't bring app forward) — verify the URL still gets delivered to an `LSUIElement` app in the background.
- Launch Services can be sticky about URL-scheme registration for ad-hoc-signed apps living outside `/Applications`; test with the brew-installed copy in `/Applications`.
- Sprite preview assets duplicate repo images into the extension; regenerate them if variants change (note in extension README).
