/*
 * Copyright (C) 2026 JAMP contributors
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.ui.music;

import androidx.annotation.NonNull;

import org.proninyaroslav.libretorrent.core.model.data.entity.MusicTrack;

import java.util.ArrayList;
import java.util.List;

public final class MusicLibraryItem {
    public enum Type { ALBUM, ARTIST, GENRE, YEAR, SONG }

    @NonNull
    public final Type type;
    @NonNull
    public final String title;
    @NonNull
    public final String subtitle;
    public final int trackCount;
    @NonNull
    public final List<MusicTrack> tracks;

    public MusicLibraryItem(
            @NonNull Type type,
            @NonNull String title,
            @NonNull String subtitle,
            @NonNull List<MusicTrack> tracks) {
        this.type = type;
        this.title = title;
        this.subtitle = subtitle;
        this.tracks = tracks;
        this.trackCount = tracks.size();
    }

    @NonNull
    public static List<MusicLibraryItem> group(
            @NonNull List<MusicTrack> tracks,
            @NonNull MusicViewMode mode) {
        var groups = new java.util.LinkedHashMap<String, List<MusicTrack>>();
        for (MusicTrack track : tracks) {
            String key = switch (mode) {
                case ALBUMS -> track.album + "\0" + track.artist;
                case ARTISTS -> track.artist;
                case GENRES -> track.genre != null ? track.genre : "Unknown Genre";
                case YEARS -> track.year != null ? Integer.toString(track.year) : "Unknown Year";
                case SONGS -> track.path;
            };
            groups.computeIfAbsent(key, k -> new ArrayList<>()).add(track);
        }

        var items = new ArrayList<MusicLibraryItem>();
        for (var entry : groups.entrySet()) {
            List<MusicTrack> groupTracks = entry.getValue();
            MusicTrack first = groupTracks.get(0);
            String title;
            String subtitle;
            MusicLibraryItem.Type type;
            switch (mode) {
                case ALBUMS -> {
                    type = Type.ALBUM;
                    title = first.album;
                    subtitle = first.artist;
                }
                case ARTISTS -> {
                    type = Type.ARTIST;
                    title = first.artist;
                    subtitle = groupTracks.size() + " songs";
                }
                case GENRES -> {
                    type = Type.GENRE;
                    title = first.genre != null ? first.genre : "Unknown Genre";
                    subtitle = groupTracks.size() + " songs";
                }
                case YEARS -> {
                    type = Type.YEAR;
                    title = first.year != null ? Integer.toString(first.year) : "Unknown Year";
                    subtitle = groupTracks.size() + " songs";
                }
                default -> {
                    type = Type.SONG;
                    title = first.title;
                    subtitle = first.artist + " · " + first.album;
                }
            }
            items.add(new MusicLibraryItem(type, title, subtitle, groupTracks));
        }
        items.sort((a, b) -> a.title.compareToIgnoreCase(b.title));
        return items;
    }
}
