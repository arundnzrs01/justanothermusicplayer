# JAMP Torrent

Android torrent client forked from [LibreTorrent](https://github.com/proninyaroslav/libretorrent), powered by [libtorrent4j](https://github.com/aldenml/libtorrent4j).

## Features

- Magnet links and `.torrent` file import
- Real-time download progress, speeds, seeds, and peers
- Background downloads via foreground service
- **Music player** — scans your torrent download folder, browse by album/artist/genre/year
- Pastel Meadow dark theme with mini player + now playing screen
- Settings grouped into **Torrent downloads** and **Music player**
- Wi-Fi only mode, proxy support, and scheduling (from upstream)

RSS feeds removed from the app (sources stashed in `stash/rss/` for future restore).

## Build

Requires Java 17 and Android SDK 36.

```bash
./gradlew :app:assembleBaseDebug
```

Release APK (base flavor, full storage access):

```bash
./gradlew :app:assembleBaseRelease
```

Install the debug APK from `app/build/outputs/apk/base/debug/`.

## License

GPL-3.0 — this project is a derivative of LibreTorrent. See [LICENSE.md](LICENSE.md) and [NOTICE](NOTICE).
