# Just Another Music Player (JAMP)

Cross-platform local music player for Android and iOS with P2P acquisition, multi-source discover search, and a Dribbble-inspired Now Playing screen.

## Features

- **Library** — browse by songs, artists, albums, genres, years; search and filter
- **Now Playing** — album art, spinning vinyl, waveform scrubber, queue pill
- **Themes** — Pastel Meadow default; built-in presets and custom theme builder
- **Discover** — multi-source search with source badges and peer counts
- **Downloads** — magnet links, package file import, speed limits, tracker management
- **Settings** — appearance, network limits, playback options

## Getting started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Project structure

- `lib/core/` — theme engine, router, providers, branding
- `lib/data/` — Drift database, models, repositories
- `lib/features/` — library, player, discover, downloads, settings
- `lib/services/` — P2P engine, search adapters, library scanner

## Notes

- **libtorrent_flutter** powers real P2P downloads on device; falls back to simulation if native init fails (e.g. desktop without binaries).
- **audio_service** provides lock-screen and notification playback controls.
- **Share intents**: open magnet links or `.torrent` files from other apps; uses `app_links` + `receive_sharing_intent`.
- Discover search scrapes LimeTorrents and TorrentGalaxy HTML with offline fallback placeholders.
- Store listings should use neutral copy ("local music player", "add link", "discover").

## License

GPL-3.0 — see [LICENSE](LICENSE).
