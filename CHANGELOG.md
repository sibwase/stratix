# Changelog

All notable changes to Stratix will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

## [1.0.0] — 2026-09-06

### Added
- Library-first shell: Full library is the default browse surface; the side rail uses Library and Local.
- Local (My Consoles) screen restyle with shared chrome and header actions for refresh/troubleshoot.
- Stream launch cancel gate so a held A press does not immediately dismiss a new stream.
- TLS/auth fallback to cached tokens when Microsoft login is unreachable.
- Alphabetical letter rail that tracks live library scrolling and settles on the focused card.
- `Tools/dev/install-apple-tv.sh` to build and install onto a paired Apple TV.

### Changed
- Game tiles keep title/studio left-aligned and scaled with the focused poster.
- Artwork decode and poster prefetch are tighter for large library grids.

### Removed
- Home browse route UI and unused home lockup design tokens.

## [0.1.0-alpha] — 2026-04-07

### Initial public release

First public open-source release of Stratix — a native tvOS Xbox Game Pass cloud gaming client for Apple TV.

### What works

- Microsoft device-code sign-in with full token lifecycle and automatic refresh
- Cloud library browsing: home rails, full library grid, search, and title detail screens
- xCloud game streaming (primary cloud streaming path)
- xHome console streaming (local Xbox console remote play)
- Controller input capture and 125 Hz input channel to server
- Metal-backed video rendering with sample-buffer fallback
- In-stream guide overlay with settings and stats
- Library persistence: disk-cached, restored across launches
- Xbox profile, presence, and achievements API integration
- Diagnostics, in-stream stats, and logging pipeline

### Known limitations

- Single Microsoft account only (no multi-account support)
- No party or invite features
- Stereo audio requires a custom WebRTC build flag; mono by default with the vendored binary
- Auto-reconnect exists but is conservative — not seamless
- Some documentation sections are still being refined

### Requirements

- Xcode 26+
- Swift 6.2
- tvOS 26.0
- Apple Silicon Mac recommended
