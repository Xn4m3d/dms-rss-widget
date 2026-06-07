# Dank RSS Widget+ (v2)

RSS and Atom feeds for [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell), three ways:
a desktop **card**, a full-width scrolling **ticker bar**, and an optional in-bar **pill**.

> **Fork of [`BrendonJL/dms-rss-widget`](https://github.com/BrendonJL/dms-rss-widget)** by [@Xn4m3d](https://github.com/Xn4m3d).
> v1 was BrendonJL's desktop RSS widget — all credit for the original goes to him. **v2** keeps the desktop
> card and adds a scrolling **ticker bar** (overlay) plus an optional **bar pill companion**, on top of a set
> of fixes and security hardening (the core fixes were also offered back upstream as PRs). Same MIT license.

## What's in this repo

Two DMS plugins:

| Folder | Plugin | What it is |
|--------|--------|------------|
| `dankRssWidget/` | **Dank RSS Widget+** (`desktop`) | The desktop card **and** the full-width scrolling ticker bar (overlay) |
| `dankRssTicker/` | **Dank RSS Widget+ (Pill companion)** (`widget`) | A small scrolling pill **inside** the DankBar, reading the same feeds |

Only **one** ticker can be active at a time (the desktop overlay **or** the bar pill) — enabling one
automatically disables the other.

## Features

### Desktop card
- RSS 2.0 and Atom with auto-detection, configurable refresh interval (5 min – 24 h)
- Add/edit/remove feeds, OPML import, quick-add presets (US/global news, tech, Reddit)
- Sort modes (newest / oldest / grouped by feed), compact & expanded views, thumbnails
- Read/unread tracking with mark-all, new-item toast notifications, per-source filter tags
- Optional **Name** label, appearance customization (font size, background opacity, borders)
- Settings organized in **3 tabs**: General / Card / Ticker bar

### Ticker bar — overlay (new in v2)
- Full-width scrolling headlines; reuses the card's in-memory items (no extra fetching)
- **Adapts to the main bar's position** (see below): docks under a **top** bar, **follows** a
  **bottom** bar (docks just above it), or — for a **vertical** (left/right) bar — sits at the top
  with its width reduced to the space beside the bar
- **Docks** to a screen edge (reserves space, foreground) or **floats** in between (behind windows),
  with a **magnet** snap to the edges while dragging
- Right-click-and-drag to move it; drag the **right edge** to resize the width (snaps back to full);
  **scroll** while holding right-click to tune the background opacity; press **S** to toggle 100%/50%
- Tunable width, horizontal position, vertical offset (when docked), height, corner radius, border,
  fonts, scroll speed, item spacing; option to show/hide while the compositor overview is open
- Latest-N items or per-source round-robin; click a headline to open it; pause on hover

#### Main bar position

The ticker stays consistent with where you put your DankBar:

| Main bar | Ticker bar |
|----------|------------|
| **Top** | docks just under it (reserves space) |
| **Bottom** | follows it — docks just **above** it (reserves space) |
| **Left / Right** (vertical) | docks at the top **or** bottom of the screen, width reduced to the area **beside** the bar — and reserves just that strip (the vertical bar keeps its full height, no corner gap); the **pill mode is disabled** |

Moving the bar — even **live**, from the DankBar settings — re-settles the ticker automatically: it
follows to the new edge without overlapping or shoving the bar around.

> **Multi-bar setups:** the ticker positions itself relative to the **first** bar config only; extra
> bars (a second bar on another edge or monitor) aren't accounted for yet. Open an issue if you need it.

### Bar pill — companion (new in v2)
- The same scrolling headlines as a compact widget **inside** the DankBar (horizontal bars only — it's
  automatically disabled when the main bar is vertical)
- Mutually exclusive with the desktop overlay, with shortcut buttons to jump between the two settings pages

### Hardening & fixes (also offered upstream)
- 🔒 Hardened `curl` (http/https only, bounded redirects & response size, ReDoS-capped parsing,
  `isSafeUrl()` allowlist for opened links & thumbnails)
- 🩹 No blank flash on resize/recreate · 🖱️ ignores stray Niri-overview clicks · 💾 item cache for instant redraw

## Installation

Clone the repo and symlink **each plugin** you want into your DMS plugins directory:

```bash
git clone https://github.com/Xn4m3d/dms-rss-widget.git
cd dms-rss-widget

# the desktop card + ticker bar (required):
ln -s "$PWD/dankRssWidget" ~/.config/DankMaterialShell/plugins/dankRssWidget

# optional — the in-bar pill companion:
ln -s "$PWD/dankRssTicker" ~/.config/DankMaterialShell/plugins/dankRssTicker
```

Reload DMS (Ctrl+Shift+R) or restart your compositor. To use the pill, add it to a bar via
**Settings → Bar**, then enable it from its plugin settings.

## Configuration

Open **Settings → Desktop Widgets → Dank RSS Widget+** and use the tabs:

1. **General** — add feeds (or quick-add presets / OPML), refresh interval, max items, sort order, notifications
2. **Card** — name label, view mode, font size, background opacity, borders
3. **Ticker bar** — enable the overlay, width/position, height, opacity, corners, border, fonts, item mode

The pill has its own settings in **Settings → Plugins → Dank RSS Widget+ (Pill companion)**.

## Requirements

- DankMaterialShell >= 1.2.0
- `curl` (used for fetching feeds)

## Testing

The core feed-parsing logic is mirrored in a standalone JS module
(`dankRssWidget/feed-parser-tests/feed-parser.js`) so it can be unit-tested with Node.js without the QML runtime.

```bash
node --test dankRssWidget/feed-parser-tests/feed-parser.test.js
```

Requires Node.js 18+ (uses the built-in `node:test` runner). 60 tests across 9 suites cover tag
extraction, CDATA, HTML entity decoding, RSS/Atom parsing, image extraction, relative timestamps and OPML import.

## Screenshots

![Desktop card and the full-width scrolling ticker bar](screenshots/screen1.png)

![The ticker bar and desktop card on another setup](screenshots/screen2.png)

![Pill mode — the ticker running as a compact pill in the main bar](screenshots/pill-plugin.png)

![Settings — General, Card and Ticker bar tabs (plus the pill companion)](screenshots/settings.png)

![The in-bar pill companion and its settings](screenshots/pill.png)

## License

MIT — the original work is © [@BrendonJL](https://github.com/BrendonJL) and contributors
(see the [upstream repository](https://github.com/BrendonJL/dms-rss-widget)). Changes in this
fork are released under the same MIT license.
