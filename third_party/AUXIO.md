# Auxio / musikr integration

JAMP uses code from [Auxio](https://github.com/OxygenCobalt/Auxio) (GPL-3.0).

## Included

- **`musikr/`** — Auxio's metadata and library indexing engine (taglib native, Room cache).
  Vendored from Auxio v4.1.3.

## Playback UI

Now playing and mini player follow the Dribbble reference layout with:
- Square album art with embedded tag artwork
- Waveform scrubber with multi-color bars
- Queue / previous / play / next / favorite controls
- Upcoming queue pill

Playback uses Media3 ExoPlayer (same family as Auxio). Full Auxio playback
service integration (Hilt, vendored Media3+FFmpeg, gapless, ReplayGain) is
planned as a follow-up once musikr scanning replaces the Java scanner.

## Restore full Auxio player

To embed Auxio's complete player stack, also vendor:
- `media/` submodule (patched ExoPlayer + FFmpeg decoder)
- Auxio `playback/` and `music/` packages with Hilt modules
- Kotlin 21 toolchain

See Auxio build docs: https://github.com/OxygenCobalt/Auxio
