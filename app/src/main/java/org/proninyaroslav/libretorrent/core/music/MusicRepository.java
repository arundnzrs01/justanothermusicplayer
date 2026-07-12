/*
 * Copyright (C) 2026 JAMP contributors
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.core.music;

import android.content.Context;

import androidx.annotation.NonNull;

import org.proninyaroslav.libretorrent.core.model.data.entity.MusicTrack;
import org.proninyaroslav.libretorrent.core.storage.AppDatabase;

import java.util.List;

import io.reactivex.rxjava3.core.Completable;
import io.reactivex.rxjava3.core.Flowable;
import io.reactivex.rxjava3.core.Single;
import io.reactivex.rxjava3.schedulers.Schedulers;

public class MusicRepository {
    private final AppDatabase db;
    private final Context appContext;

    public MusicRepository(@NonNull Context appContext) {
        this.appContext = appContext.getApplicationContext();
        this.db = AppDatabase.getInstance(this.appContext);
    }

    public Flowable<List<MusicTrack>> observeTracks() {
        return db.musicDao().observeAll();
    }

    public Completable rescanLibrary() {
        return Completable.fromAction(() -> {
            List<MusicTrack> scanned = MusicScanner.scanDownloadFolder(appContext);
            db.runInTransaction(() -> {
                db.musicDao().deleteAll();
                if (!scanned.isEmpty()) {
                    db.musicDao().insertAll(scanned);
                }
            });
        }).subscribeOn(Schedulers.io());
    }

    public Single<List<MusicTrack>> getTracksOnce() {
        return db.musicDao().getAllSingle().subscribeOn(Schedulers.io());
    }
}
