# RSS / Feed module (stashed)

Removed from JAMP in v0.0.2-beta for a slimmer torrent + music player focus.

## Contents

- `java/` — Feed UI, workers, parser, repository, Room entities/DAO
- `res/` — layouts, menus, navigation, preferences, drawables

## Restore

1. Copy Java sources back under `app/src/main/java/` preserving package paths
2. Copy resources back under `app/src/main/res/`
3. Re-add `feed_nav` to `nav.xml` and `nav_bar_graph.xml`
4. Re-add feed settings to `pref_headers.xml` and `settings_two_pane_graph.xml`
5. Wire `RepositoryHelper.getFeedRepository()`, `NavBarFragment` feed intents, and `Scheduler` feed refresh
6. Re-add RSS intent filters in `AndroidManifest.xml`

Feed Room tables (`feeds`, `feed_items`) remain in the database schema for existing installs.

Based on LibreTorrent (GPL-3.0).
