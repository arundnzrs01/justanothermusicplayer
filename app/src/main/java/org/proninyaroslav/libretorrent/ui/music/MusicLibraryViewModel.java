/*
 * Copyright (C) 2026 JAMP contributors
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.ui.music;

import android.app.Application;
import android.text.TextUtils;

import androidx.annotation.NonNull;
import androidx.lifecycle.AndroidViewModel;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;

import org.proninyaroslav.libretorrent.core.model.data.entity.MusicTrack;
import org.proninyaroslav.libretorrent.core.music.MusicRepository;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers;
import io.reactivex.rxjava3.disposables.CompositeDisposable;
import io.reactivex.rxjava3.schedulers.Schedulers;

public class MusicLibraryViewModel extends AndroidViewModel {
    private final MusicRepository repository;
    private final CompositeDisposable disposables = new CompositeDisposable();

    private final MutableLiveData<List<MusicLibraryItem>> items = new MutableLiveData<>(List.of());
    private final MutableLiveData<Boolean> scanning = new MutableLiveData<>(false);
    private final MutableLiveData<String> message = new MutableLiveData<>(null);

    private List<MusicTrack> allTracks = List.of();
    private MusicViewMode viewMode = MusicViewMode.ALBUMS;
    private String query = "";
    private String filterArtist;
    private String filterAlbum;
    private Integer filterYear;
    private String filterGenre;

    public MusicLibraryViewModel(@NonNull Application application) {
        super(application);
        repository = new MusicRepository(application);
        observeTracks();
    }

    @NonNull
    public LiveData<List<MusicLibraryItem>> observeItems() {
        return items;
    }

    @NonNull
    public LiveData<Boolean> observeScanning() {
        return scanning;
    }

    @NonNull
    public LiveData<String> observeMessage() {
        return message;
    }

    @NonNull
    public MusicViewMode getViewMode() {
        return viewMode;
    }

    public void setViewMode(@NonNull MusicViewMode mode) {
        viewMode = mode;
        clearFilters();
        publishItems();
    }

    public void setQuery(@NonNull String value) {
        query = value.trim().toLowerCase(Locale.US);
        publishItems();
    }

    public void applyFilter(@NonNull MusicLibraryItem item) {
        switch (item.type) {
            case ARTIST -> filterArtist = item.title;
            case ALBUM -> {
                filterAlbum = item.title;
                if (!item.tracks.isEmpty()) {
                    filterArtist = item.tracks.get(0).artist;
                }
            }
            case GENRE -> filterGenre = item.title;
            case YEAR -> {
                try {
                    filterYear = Integer.parseInt(item.title);
                } catch (NumberFormatException ignored) {
                    filterYear = null;
                }
            }
            default -> {
            }
        }
        viewMode = MusicViewMode.SONGS;
        publishItems();
    }

    public void clearFilters() {
        filterArtist = null;
        filterAlbum = null;
        filterYear = null;
        filterGenre = null;
    }

    public boolean hasActiveFilters() {
        return filterArtist != null || filterAlbum != null || filterYear != null || filterGenre != null;
    }

    public void rescan() {
        scanning.setValue(true);
        disposables.add(repository.rescanLibrary()
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe(() -> {
                    scanning.setValue(false);
                    message.setValue(null);
                }, (e) -> {
                    scanning.setValue(false);
                    message.setValue(e.getMessage());
                }));
    }

    private void observeTracks() {
        disposables.add(repository.observeTracks()
                .subscribeOn(Schedulers.io())
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe((tracks) -> {
                    allTracks = tracks;
                    publishItems();
                }, (e) -> message.setValue(e.getMessage())));
    }

    private void publishItems() {
        List<MusicTrack> filtered = filterTracks(allTracks);
        if (viewMode == MusicViewMode.SONGS && !hasActiveFilters()) {
            items.setValue(MusicLibraryItem.group(filtered, MusicViewMode.SONGS));
        } else if (hasActiveFilters()) {
            items.setValue(MusicLibraryItem.group(filtered, MusicViewMode.SONGS));
        } else {
            items.setValue(MusicLibraryItem.group(filtered, viewMode));
        }
    }

    @NonNull
    private List<MusicTrack> filterTracks(@NonNull List<MusicTrack> source) {
        var out = new ArrayList<MusicTrack>();
        for (MusicTrack track : source) {
            if (filterArtist != null && !track.artist.equals(filterArtist)) {
                continue;
            }
            if (filterAlbum != null && !track.album.equals(filterAlbum)) {
                continue;
            }
            if (filterGenre != null) {
                String genre = track.genre != null ? track.genre : "Unknown Genre";
                if (!genre.equals(filterGenre)) {
                    continue;
                }
            }
            if (filterYear != null && (track.year == null || !track.year.equals(filterYear))) {
                continue;
            }
            if (!TextUtils.isEmpty(query)) {
                String haystack = (track.title + " " + track.artist + " " + track.album + " "
                        + (track.genre != null ? track.genre : "")).toLowerCase(Locale.US);
                if (!haystack.contains(query)) {
                    continue;
                }
            }
            out.add(track);
        }
        return out;
    }

    @Override
    protected void onCleared() {
        disposables.clear();
        super.onCleared();
    }
}
