/*
 * Copyright (C) 2026 JAMP contributors
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.ui.music;

import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.navigation.Navigation;

import org.proninyaroslav.libretorrent.R;
import org.proninyaroslav.libretorrent.core.model.data.entity.MusicTrack;
import org.proninyaroslav.libretorrent.core.music.AlbumArtLoader;
import org.proninyaroslav.libretorrent.core.music.MusicPlayerManager;
import org.proninyaroslav.libretorrent.databinding.FragmentNowPlayingBinding;

import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

public class NowPlayingFragment extends Fragment {
    private FragmentNowPlayingBinding binding;
    private MusicPlayerManager player;
    private float[] waveform = new float[0];
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable progressTick = new Runnable() {
        @Override
        public void run() {
            if (player != null) {
                player.tickProgress();
            }
            handler.postDelayed(this, 400);
        }
    };

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        binding = FragmentNowPlayingBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        player = MusicPlayerManager.getInstance(requireContext());

        binding.back.setOnClickListener(v -> Navigation.findNavController(v).navigateUp());
        binding.playPause.setOnClickListener(v -> player.togglePlayPause());
        binding.prev.setOnClickListener(v -> player.skipPrevious());
        binding.next.setOnClickListener(v -> player.skipNext());
        binding.queue.setOnClickListener(v -> Navigation.findNavController(v).navigateUp());
        binding.favorite.setOnClickListener(v -> { /* reserved */ });

        binding.waveform.setListener(progress -> {
            Long duration = player.observeDurationMs().getValue();
            if (duration != null && duration > 0) {
                player.seekTo((long) (duration * progress));
            }
        });

        binding.seekBar.setOnSeekBarChangeListener(new android.widget.SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(android.widget.SeekBar seekBar, int progress, boolean fromUser) {
                if (fromUser) {
                    player.seekTo(progress);
                }
            }
            @Override public void onStartTrackingTouch(android.widget.SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(android.widget.SeekBar seekBar) {}
        });

        player.observeCurrentTrack().observe(getViewLifecycleOwner(), this::bindTrack);
        player.observePlaying().observe(getViewLifecycleOwner(), this::bindPlaying);
        player.observeQueue().observe(getViewLifecycleOwner(), this::bindQueue);
        player.observePositionMs().observe(getViewLifecycleOwner(), this::bindPosition);
        player.observeDurationMs().observe(getViewLifecycleOwner(), this::bindDuration);

        handler.post(progressTick);
    }

    private void bindTrack(@Nullable MusicTrack track) {
        if (track == null || binding == null) {
            return;
        }
        binding.title.setText(track.title);
        binding.artist.setText(track.artist);
        binding.albumArt.setClipToOutline(true);
        binding.albumArt.setOutlineProvider(new android.view.ViewOutlineProvider() {
            @Override
            public void getOutline(View view, android.graphics.Outline outline) {
                outline.setRoundRect(0, 0, view.getWidth(), view.getHeight(), 24f);
            }
        });
        binding.artInitial.setText(track.album.isEmpty() ? "?" : track.album.substring(0, 1).toUpperCase(Locale.US));
        var bitmap = AlbumArtLoader.loadBitmap(track.path);
        if (bitmap != null) {
            binding.albumArt.setImageBitmap(bitmap);
            binding.artInitial.setVisibility(View.GONE);
        } else {
            binding.albumArt.setImageDrawable(null);
            binding.artInitial.setVisibility(View.VISIBLE);
        }
        waveform = AlbumArtLoader.waveformForTrack(track);
        binding.waveform.setWaveform(waveform);
    }

    private void bindPlaying(@Nullable Boolean playing) {
        if (binding == null) {
            return;
        }
        binding.playPause.setImageResource(Boolean.TRUE.equals(playing)
                ? R.drawable.ic_pause_24px
                : R.drawable.ic_play_arrow_24px);
    }

    private void bindQueue(@Nullable List<MusicTrack> queue) {
        if (binding == null || queue == null || queue.isEmpty()) {
            return;
        }
        int current = player.getQueueIndex();
        if (current < 0 || current >= queue.size()) {
            binding.queuePill.setText(R.string.music_queue_empty);
            return;
        }
        String upcoming = queue.subList(current + 1, queue.size()).stream()
                .limit(4)
                .map(t -> t.title)
                .collect(Collectors.joining(", "));
        binding.queuePill.setText(upcoming.isEmpty()
                ? getString(R.string.music_queue_empty)
                : upcoming);
    }

    private void bindPosition(@Nullable Long positionMs) {
        if (binding == null || positionMs == null) {
            return;
        }
        binding.positionText.setText(formatDuration(positionMs));
        Long duration = player.observeDurationMs().getValue();
        if (duration != null && duration > 0) {
            binding.waveform.setProgress(positionMs / (float) duration);
            binding.seekBar.setProgress(positionMs.intValue());
        }
    }

    private void bindDuration(@Nullable Long durationMs) {
        if (binding == null || durationMs == null || durationMs <= 0) {
            return;
        }
        binding.durationText.setText(formatDuration(durationMs));
        binding.seekBar.setMax(durationMs.intValue());
    }

    @NonNull
    private static String formatDuration(long ms) {
        long totalSec = ms / 1000;
        long min = totalSec / 60;
        long sec = totalSec % 60;
        return min + ":" + (sec < 10 ? "0" : "") + sec;
    }

    @Override
    public void onDestroyView() {
        handler.removeCallbacks(progressTick);
        binding = null;
        super.onDestroyView();
    }
}
