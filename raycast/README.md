# Oneko for Raycast

Control [Oneko](https://github.com/oneko-swift/oneko-swift), the desktop cat
that chases your cursor, without leaving Raycast.

## Commands

- **Toggle Cat** — show or hide the cat, starting Oneko if needed
- **Change Skin** — pick from all 27 sprites, with previews
- **Set Speed** — slow, normal, or fast
- **Quit Oneko** — quit the app

The extension requires the Oneko app (macOS 13+):

```sh
brew install --cask oneko-swift/tap/oneko
```

All commands talk to the app through its `oneko://` URL scheme (Oneko 1.2+),
so the extension needs no permissions of its own.

## Development

```sh
npm install
npx ray develop
```

The skin thumbnails in `assets/skins/` are generated from the sprite sheets:
`swift ../tools/makethumbs.swift ../Resources assets/skins`.

Before publishing to the Raycast Store, set `author` in `package.json` to
the publishing Raycast account's handle (`ray lint` validates it against
raycast.com).
