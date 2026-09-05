# play

Source for the "play" games list — a plain list of free standalone games
from devisant, each with "Play in browser" and "Download APK". Static site,
no build step.

Only public, free games belong in this repo. Anything not free/public stays
out.

## Hosting

The site lives at **https://devisant.com/play/** — mounted as a path under
the main devisant.com site (served by GitHub Pages from the public artifact
repo `isa-kit/isa-app`). This repo is no longer served directly and no
longer owns a custom domain or GitHub Pages of its own; it is the SOURCE
tree (and the GitHub Releases host for APKs). isan's deploy carries this
repo's tree into `isa-app/play/` on every prod promote, so this repo stays
the thing you edit and publish games from.

Every link in the site is path-relative (`landsmith/`, not `/landsmith/`;
`fetch('games.json')`, not an absolute path) so it can be mounted at any
path. The current mount point is `/play/`, set as `MOUNT_PATH` at the top of
`tool/publish-game.sh` (used for the web bundle's `--base-href` and the
printed URLs). If the Games applet is ever renamed and this list moves to
`/games/`, that's a one-line change to `MOUNT_PATH` — nothing else in the
site or script depends on the mount point.

## Structure

- `index.html`, `styles.css` — the page. Renders from `games.json` via a
  small inline script; a `<noscript>` fallback covers no-JS.
- `games.json` — the registry the page reads: id, name, tagline, version,
  date, apk url/size/sha256/preview flag.
- `<id>/` — one directory per game's built web bundle (e.g. `landsmith/`),
  each built with `--base-href <MOUNT_PATH><id>/` (currently
  `/play/landsmith/`).
- `tool/publish-game.sh` — publishes a game (see below).
- `.nojekyll`, `robots.txt` — static-site config kept for when the tree is
  copied into the deploy.

Binaries (APKs) are never committed here — they're uploaded as GitHub
release assets on this repo and linked from `games.json`.

## Publishing a game

Full publish (new build + APK release):

```
tool/publish-game.sh <id> <web-bundle-dir> <apk-path> --version v0.1.0 [--notes notes.txt] [--dry-run]
```

This copies the web bundle into `<id>/`, creates or updates a GitHub release
on `isa-kit/play` tagged `<id>-<version>` with the APK uploaded as
`<id>-<version>-arm64.apk` plus a `<id>-latest.apk` alias, writes size and
sha256 into `games.json`, and commits + pushes `<id>/` and `games.json`.

Web-only refresh (APK on the release is unchanged, just rebuild the web
bundle — e.g. after a mount-path change):

```
tool/publish-game.sh <id> <web-bundle-dir> --web-only --version v0.1.0
```

This skips the GitHub release entirely and only refreshes `<id>/` plus
`version`/`date` in `games.json` (the existing `apk` block is left as-is).

After either form, get the refreshed tree onto the live site by re-running
whatever carries this repo's tree into `isa-app/play/` (isan's deploy, once
that unit lands) or by copying it there manually for an immediate push.
