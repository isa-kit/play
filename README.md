# play

Source for **play.devisant.com** — a plain list of free standalone games from
devisant, each with "Play in browser" and "Download APK". Static site, no
build step, served by GitHub Pages from `main`.

Only public, free games belong in this repo. Anything not free/public stays
out.

## Structure

- `index.html`, `styles.css` — the page. Renders from `games.json` via a
  small inline script; a `<noscript>` fallback covers no-JS.
- `games.json` — the registry the page reads: id, name, tagline, version,
  date, apk url/size/sha256/preview flag.
- `<id>/` — one directory per game's built web bundle (e.g. `landsmith/`),
  each built with `--base-href /<id>/`.
- `tool/publish-game.sh` — publishes a game (see below).
- `CNAME`, `.nojekyll`, `robots.txt` — Pages config.

Binaries (APKs) are never committed here — they're uploaded as GitHub
release assets and linked from `games.json`.

## Publishing a game

```
tool/publish-game.sh <id> <web-bundle-dir> <apk-path> --version v0.1.0 [--notes notes.txt] [--dry-run]
```

This copies the web bundle into `<id>/`, creates or updates a GitHub release
on `isa-kit/play` tagged `<id>-<version>` with the APK uploaded as
`<id>-<version>-arm64.apk` plus a `<id>-latest.apk` alias, writes size and
sha256 into `games.json`, and commits + pushes `<id>/` and `games.json`.

## DNS

The user must add, at their DNS provider:

```
play  CNAME  isa-kit.github.io   (DNS only, no proxy)
```

Same pattern as the existing `devisant.com` and `dev.devisant.com` Pages
sites.
