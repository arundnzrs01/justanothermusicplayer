/*
 * Copyright (C) 2026 JAMP contributors
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.core.storage.dao;

import androidx.room.Dao;
import androidx.room.Insert;
import androidx.room.OnConflictStrategy;
import androidx.room.Query;

import org.proninyaroslav.libretorrent.core.model.data.entity.MusicTrack;

import java.util.List;

import io.reactivex.rxjava3.core.Flowable;
import io.reactivex.rxjava3.core.Single;

@Dao
public interface MusicDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    void insertAll(List<MusicTrack> tracks);

    @Query("DELETE FROM music_tracks")
    void deleteAll();

    @Query("SELECT * FROM music_tracks ORDER BY album COLLATE NOCASE, trackNumber, title COLLATE NOCASE")
    Flowable<List<MusicTrack>> observeAll();

    @Query("SELECT * FROM music_tracks ORDER BY album COLLATE NOCASE, trackNumber, title COLLATE NOCASE")
    Single<List<MusicTrack>> getAllSingle();

    @Query("SELECT * FROM music_tracks WHERE path = :path LIMIT 1")
    MusicTrack getByPath(String path);
}
