/*
 * Copyright (C) 2026 JAMP contributors
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.core.model.data.entity;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.room.Entity;
import androidx.room.Index;
import androidx.room.PrimaryKey;

@Entity(
        tableName = "music_tracks",
        indices = {
                @Index(value = {"path"}, unique = true),
                @Index("album"),
                @Index("artist"),
                @Index("genre"),
                @Index("year")
        }
)
public class MusicTrack {
    @PrimaryKey(autoGenerate = true)
    public long id;

    @NonNull
    public String path = "";

    @NonNull
    public String title = "";

    @NonNull
    public String artist = "";

    @NonNull
    public String album = "";

    @Nullable
    public String genre;

    @Nullable
    public Integer year;

    public long durationMs;

    @Nullable
    public Integer trackNumber;

    public long dateAdded;
}
