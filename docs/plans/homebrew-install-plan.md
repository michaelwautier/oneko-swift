# Plan: Install Oneko via Homebrew

> Temporary planning doc — delete once shipped.

## Goal

`brew install --cask oneko-swift/tap/oneko` puts a working `Oneko.app` in `/Applications`, with no personal name in any user-facing string (neutral-org path; `oneko-swift` is the working org name — checked free on GitHub as of 2026-07-28, along with `oneko-mac`, `oneko-project`, `onekoapp`).

## Current state

- App builds with `./build.sh`: `swiftc -O Sources/*.swift` → `build/Oneko.app`, ad-hoc signed (needed for SMAppService launch-at-login).
- No SwiftPM package, no versioned releases, no CI. `Info.plist` has `CFBundleVersion` / `CFBundleShortVersionString` hardcoded to `1.0`.
- Repo is public (`michaelwautier/oneko-swift`) but has 0 stars, so the official `homebrew/cask` repo is out for now (notability requirements). A tap under a neutral GitHub org is the way.

## Key decision: Gatekeeper

Homebrew casks quarantine downloaded apps by default. An ad-hoc-signed, un-notarized app will be blocked by Gatekeeper on first launch. Options:

1. **Developer ID + notarization (recommended if willing to pay).** Requires Apple Developer Program ($99/yr). Sign with `Developer ID Application` cert, notarize with `xcrun notarytool`, staple. Clean install experience.
2. **Ship un-notarized, document the workaround.** Cask installs fine; README/caveats tell users to run `brew install --cask oneko --no-quarantine` or right-click → Open. Free, slightly janky.
3. **Formula instead of cask (build from source).** `brew install` compiles locally with `swiftc`; locally-built binaries get no quarantine flag, and the local ad-hoc signature keeps SMAppService working. Downside: users need Xcode CLT, and installing a `.app` from a formula is unconventional (caveats must tell the user to link it into `/Applications`).

Default choice for this plan: **option 2** to start (zero cost, one-line caveat), with option 1 as a follow-up if the app gets traction. Reassess before starting.

## Phase 0 — Neutral org (do first)

- [x] Create the GitHub org (web UI only — can't be scripted): `oneko-swift` (free as of 2026-07-28).
- [x] Before pushing anything to the org, set a pseudonymous commit identity so new commits don't carry the personal name/email: `git config user.name` + GitHub noreply email, and enable "Keep my email addresses private" + "Block command line pushes that expose my email" on GitHub. Existing history keeps "Michaël W." unless rewritten — accepted, not worth a rewrite.
- [x] Transfer `michaelwautier/oneko-swift` → `oneko-swift/oneko-swift` (repo Settings → Transfer). GitHub redirects the old URL; still update the local remote: `git remote set-url origin git@github.com:oneko-swift/oneko-swift.git`.
- [x] Update README links (none existed — credits only link upstream art repos)/badges that mention the old owner.
- [x] Optional but on-theme: change `CFBundleIdentifier` from `com.michael.oneko` to `app.oneko.Oneko`. Done 2026-07-28 (prefs/login-item reset on this machine accepted).

## Phase 1 — Make the build releasable

- [x] Parameterize version: `build.sh` accepts `VERSION` (env or arg) and stamps `CFBundleVersion` / `CFBundleShortVersionString` into the copied `Info.plist` (via `plutil -replace`). Default stays `1.0` for dev builds.
- [x] Build a universal binary: compile twice (`-target arm64-apple-macos13` and `-target x86_64-apple-macos13`) and `lipo -create`. Verified with `lipo -archs` → `x86_64 arm64`.
- [x] Add a `release.sh` that produces `Oneko-<version>.zip` via `ditto -c -k --keepParent` and prints its `shasum -a 256`.
- [x] Smoke-test the zipped app on a clean unzip: launches from an isolated directory, 27 sheets + menu icon bundled.

## Phase 2 — First GitHub release

- [x] Tag `v1.1.0` (first properly versioned release; pick up the horizontal-mode fix).
- [x] `gh release create v1.1.0 Oneko-1.1.0.zip --notes ...`.
- [x] Record the zip's sha256 for the cask.

## Phase 3 — Tap + cask

- [x] Create repo `oneko-swift/homebrew-tap` with `Casks/oneko.rb`:

```ruby
cask "oneko" do
  version "1.1.0"
  sha256 "<sha256-of-zip>"

  url "https://github.com/oneko-swift/oneko-swift/releases/download/v#{version}/Oneko-#{version}.zip"
  name "Oneko"
  desc "Cat chases your cursor around the screen (native port of oneko)"
  homepage "https://github.com/oneko-swift/oneko-swift"

  depends_on macos: ">= :ventura"

  app "Oneko.app"

  zap trash: [
    "~/Library/Preferences/app.oneko.Oneko.plist",
  ]

  caveats <<~EOS
    Oneko is not notarized. On first launch either right-click the app
    and choose Open, or install with:
      brew install --cask oneko --no-quarantine
  EOS
end
```

- [x] `brew tap oneko-swift/tap && brew install --cask oneko` on this machine; verify app runs, launch-at-login registers, `brew uninstall --cask oneko` and `--zap` clean up.
- [x] Add install instructions to the README.

## Phase 4 — Automation (optional, later)

- [ ] GitHub Actions workflow on tag push: build universal zip, create release, compute sha256.
- [ ] Second job (or `brew bump-cask-pr`-style script) that opens a PR against `homebrew-tap` bumping `version` + `sha256`.

Workflow added in `.github/workflows/release.yml` (both jobs). Tick after the
first tag-push run succeeds end to end. Setup required first: a fine-grained
PAT (org `oneko-swift`, repo `homebrew-tap`, Contents + Pull requests
read/write) stored as the `TAP_GITHUB_TOKEN` secret in `oneko-swift/oneko-swift`.
Tap-bump commits are authored by `github-actions[bot]` to keep the pseudonym.

## Acceptance criteria

- Fresh machine (or fresh brew prefix): `brew install --cask oneko-swift/tap/oneko` → app in `/Applications`, launches (with documented Gatekeeper step if un-notarized), cat appears, launch-at-login works.
- No personal name/handle in: install command, cask file, release page URLs, README install section.
- `brew upgrade` path works when a second release is cut.

## Risks / open questions

- SMAppService launch-at-login with an ad-hoc signature installed via brew: verify status isn't `.requiresApproval` weirdness after quarantine removal; re-test after any signing change.
- If notarization is adopted later, the release script needs `codesign --options runtime` (hardened runtime) — check the timer/CGEvent usage still works under hardened runtime (should; no entitlements currently needed).
- Notarization under a *personal* Apple Developer account embeds the legal name in the signing certificate — that would undo the neutral-org anonymity. Only an organization Apple account (needs a D-U-N-S number / legal entity) shows a company name; without one, staying un-notarized is the price of the pseudonym.
- Org membership is public by default only if you set it public — keep your membership private (org People page → Private) so the org page doesn't list you.

## Shipped 2026-07-28 — field notes

- Org name ended up `oneko-swift` (user's choice at creation time), not `oneko-app`.
- Homebrew 6 requires `brew trust oneko-swift/tap` before installing from a third-party tap.
- Homebrew 6 removed `--no-quarantine`; macOS 15+ also removed right-click→Open. The documented path is System Settings → Privacy & Security → "Open Anyway".
- `depends_on macos: ">= :ventura"` string form is deprecated → `depends_on macos: :ventura`.
- Full cycle verified locally: tap → install → launch from /Applications → uninstall → `--zap` (trashes `app.oneko.Oneko.plist`) → reinstall.
