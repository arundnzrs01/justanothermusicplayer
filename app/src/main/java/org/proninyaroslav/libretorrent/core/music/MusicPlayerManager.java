/*
 * Copyright (C) 2026 JAMP contributors
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.core.music;

import android.content.Context;
import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;
import androidx.media3.common.MediaItem;
import androidx.media3.common.Player;
import androidx.media3.exoplayer.ExoPlayer;

import org.proninyaroslav.libretorrent.core.model.data.entity.MusicTrack;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class MusicPlayerManager implements Player.Listener {
    private static volatile MusicPlayerManager INSTANCE;

    private final ExoPlayer player;
    private final MutableLiveData<MusicTrack> currentTrack = new MutableLiveData<>();
    private final MutableLiveData<Boolean> playing = new MutableLiveData<>(false);
    private final MutableLiveData<Long> positionMs = new MutableLiveData<>(0L);
    private final MutableLiveData<Long> durationMs = new MutableLiveData<>(0L);
    private final MutableLiveData<List<MusicTrack>> queueLive = new MutableLiveData<>(Collections.emptyList());

    private List<MusicTrack> queue = Collections.emptyList();
    private int queueIndex = -1;

    private MusicPlayerManager(@NonNull Context context) {
        player = new ExoPlayer.Builder(context.getApplicationContext()).build();
        player.addListener(this);
    }

    @NonNull
    public static MusicPlayerManager getInstance(@NonNull Context context) {
        if (INSTANCE == null) {
            synchronized (MusicPlayerManager.class) {
                if (INSTANCE == null) {
                    INSTANCE = new MusicPlayerManager(context);
                }
            }
        }
        return INSTANCE;
    }

    @NonNull
    public LiveData<MusicTrack> observeCurrentTrack() {
        return currentTrack;
    }

    @NonNull
    public LiveData<Boolean> observePlaying() {
        return playing;
    }

    @NonNull
    public LiveData<Long> observePositionMs() {
        return positionMs;
    }

    @NonNull
    public LiveData<List<MusicTrack>> observeQueue() {
        return queueLive;
    }

    public int getQueueIndex() {
        return queueIndex;
    }

    @NonNull
    public LiveData<Long> observeDurationMs() {
        return durationMs;
    }

    @Nullable
    public MusicTrack getCurrentTrack() {
        return currentTrack.getValue();
    }

    public boolean hasActiveTrack() {
        return currentTrack.getValue() != null;
    }

    public void playQueue(@NonNull List<MusicTrack> tracks, int startIndex) {
        if (tracks.isEmpty()) {
            return;
        }
        queue = new ArrayList<>(tracks);
        queueIndex = Math.max(0, Math.min(startIndex, tracks.size() - 1));
        queueLive.setValue(queue);
        playIndex(queueIndex);
    }

    public void togglePlayPause() {
        if (player.isPlaying()) {
            player.pause();
        } else {
            player.play();
        }
    }

    public void skipNext() {
        if (queue.isEmpty()) {
            return;
        }
        if (queueIndex + 1 < queue.size()) {
            playIndex(queueIndex + 1);
        }
    }

    public void skipPrevious() {
        if (queue.isEmpty()) {
            return;
        }
        if (player.getCurrentPosition() > 3000) {
            player.seekTo(0);
            return;
        }
        if (queueIndex > 0) {
            playIndex(queueIndex - 1);
        } else {
            player.seekTo(0);
        }
    }

    public void seekTo(long positionMs) {
        player.seekTo(positionMs);
    }

    public void stopAndClear() {
        player.stop();
        player.clearMediaItems();
        queue = Collections.emptyList();
        queueIndex = -1;
        queueLive.setValue(Collections.emptyList());
        currentTrack.setValue(null);
        playing.setValue(false);
    }

    public void tickProgress() {
        if (player.isPlaying()) {
            positionMs.setValue(player.getCurrentPosition());
            durationMs.setValue(Math.max(player.getDuration(), 0));
        }
    }

    private void playIndex(int index) {
        queueIndex = index;
        MusicTrack track = queue.get(index);
        currentTrack.setValue(track);
        player.setMediaItem(MediaItem.fromUri(Uri.fromFile(new File(track.path))));
        player.prepare();
        player.play();
    }

    @Override
    public void onIsPlayingChanged(boolean isPlaying) {
        playing.setValue(isPlaying);
    }

    @Override
    public void onPlaybackStateChanged(int playbackState) {
        if (playbackState == Player.STATE_ENDED) {
            skipNext();
        }
        durationMs.setValue(Math.max(player.getDuration(), 0));
        positionMs.setValue(player.getCurrentPosition());
    }
}
