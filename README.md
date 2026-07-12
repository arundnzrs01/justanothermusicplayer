# Just Another Music Player (JAMP)

Android music player with torrent downloads (libtorrent4j / LibreTorrent engine), local library playback, and a Dribbble-inspired Now Playing screen.

## Features

- **Library** — browse by songs, artists, albums, genres, years; search and filter
- **Now Playing** — album art, spinning vinyl, waveform scrubber, queue pill
- **Themes** — Pastel Meadow default; built-in presets and custom theme builder
- **Downloads** — paste magnet links or import `.torrent` files via the + button
- **Settings** — appearance, network limits, playback options

## Getting started

Requires Flutter SDK and an Android device or emulator (API 24+).

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Build a release APK:

```bash
flutter build apk --release
```

## Project structure

- `lib/core/` — theme engine, router, providers, branding
- `lib/data/` — Drift database, models, repositories
- `lib/features/` — library, player, downloads, settings
- `lib/services/` — torrent engine bridge, library scanner, audio
- `android/` — Kotlin libtorrent4j integration

## Notes

- **libtorrent4j** powers real P2P downloads on Android (same engine family as [LibreTorrent](https://github.com/proninyaroslav/libretorrent)).
- **audio_service** provides lock-screen and notification playback controls.
- **Share intents**: open magnet links or `.torrent` files from other apps via `app_links` + `receive_sharing_intent`.
- This project targets **Android only**; iOS, desktop, and web platforms are not supported.

## License

GPL-3.0 — see [LICENSE](LICENSE).
