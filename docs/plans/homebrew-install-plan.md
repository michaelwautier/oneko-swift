# Plan: Install Oneko via Homebrew

> Temporary planning doc — delete once shipped.

## Goal

`brew install --cask michaelwautier/tap/oneko` puts a working `Oneko.app` in `/Applications`.

## Current state

- App builds with `./build.sh`: `swiftc -O Sources/*.swift` → `build/Oneko.app`, ad-hoc signed (needed for SMAppService launch-at-login).
- No SwiftPM package, no versioned releases, no CI. `Info.plist` has `CFBundleVersion` / `CFBundleShortVersionString` hardcoded to `1.0`.
- Repo is public (`michaelwautier/oneko-swift`) but has 0 stars, so the official `homebrew/cask` repo is out for now (notability requirements). A personal tap is the way.

## Key decision: Gatekeeper

Homebrew casks quarantine downloaded apps by default. An ad-hoc-signed, un-notarized app will be blocked by Gatekeeper on first launch. Options:

1. **Developer ID + notarization (recommended if willing to pay).** Requires Apple Developer Program ($99/yr). Sign with `Developer ID Application` cert, notarize with `xcrun notarytool`, staple. Clean install experience.
2. **Ship un-notarized, document the workaround.** Cask installs fine; README/caveats tell users to run `brew install --cask oneko --no-quarantine` or right-click → Open. Free, slightly janky.
3. **Formula instead of cask (build from source).** `brew install` compiles locally with `swiftc`; locally-built binaries get no quarantine flag, and the local ad-hoc signature keeps SMAppService working. Downside: users need Xcode CLT, and installing a `.app` from a formula is unconventional (caveats must tell the user to link it into `/Applications`).

Default choice for this plan: **option 2** to start (zero cost, one-line caveat), with option 1 as a follow-up if the app gets traction. Reassess before starting.

## Phase 1 — Make the build releasable

- [ ] Parameterize version: `build.sh` accepts `VERSION` (env or arg) and stamps `CFBundleVersion` / `CFBundleShortVersionString` into the copied `Info.plist` (e.g. via `plutil -replace`).
- [ ] Build a universal binary: compile twice (`-target arm64-apple-macos13` and `-target x86_64-apple-macos13`) and `lipo -create`. Verify with `lipo -archs`.
- [ ] Add a `release.sh` (or extend `build.sh`) that produces `Oneko-<version>.zip` via `ditto -c -k --keepParent build/Oneko.app ...` and prints its `shasum -a 256`.
- [ ] Smoke-test the zipped app on a clean unzip: launches, menu works, sprites load (`Resources/*.png` are inside the bundle).

## Phase 2 — First GitHub release

- [ ] Tag `v1.1.0` (first properly versioned release; pick up the horizontal-mode fix).
- [ ] `gh release create v1.1.0 Oneko-1.1.0.zip --notes ...`.
- [ ] Record the zip's sha256 for the cask.

## Phase 3 — Tap + cask

- [ ] Create repo `michaelwautier/homebrew-tap` with `Casks/oneko.rb`:

```ruby
cask "oneko" do
  version "1.1.0"
  sha256 "<sha256-of-zip>"

  url "https://github.com/michaelwautier/oneko-swift/releases/download/v#{version}/Oneko-#{version}.zip"
  name "Oneko"
  desc "Cat chases your cursor around the screen (native port of oneko)"
  homepage "https://github.com/michaelwautier/oneko-swift"

  depends_on macos: ">= :ventura"

  app "Oneko.app"

  zap trash: [
    "~/Library/Preferences/com.michael.oneko.plist",
  ]

  caveats <<~EOS
    Oneko is not notarized. On first launch either right-click the app
    and choose Open, or install with:
      brew install --cask oneko --no-quarantine
  EOS
end
```

- [ ] `brew tap michaelwautier/tap && brew install --cask oneko` on this machine; verify app runs, launch-at-login registers, `brew uninstall --cask oneko` and `--zap` clean up.
- [ ] Add install instructions to the README.

## Phase 4 — Automation (optional, later)

- [ ] GitHub Actions workflow on tag push: build universal zip, create release, compute sha256.
- [ ] Second job (or `brew bump-cask-pr`-style script) that opens a PR against `homebrew-tap` bumping `version` + `sha256`.

## Acceptance criteria

- Fresh machine (or fresh brew prefix): `brew install --cask michaelwautier/tap/oneko` → app in `/Applications`, launches (with documented Gatekeeper step if un-notarized), cat appears, launch-at-login works.
- `brew upgrade` path works when a second release is cut.

## Risks / open questions

- SMAppService launch-at-login with an ad-hoc signature installed via brew: verify status isn't `.requiresApproval` weirdness after quarantine removal; re-test after any signing change.
- If notarization is adopted later, the release script needs `codesign --options runtime` (hardened runtime) — check the timer/CGEvent usage still works under hardened runtime (should; no entitlements currently needed).
