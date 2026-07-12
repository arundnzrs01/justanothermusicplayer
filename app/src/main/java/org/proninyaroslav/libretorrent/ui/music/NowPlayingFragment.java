/*
 * Copyright (C) 2026 JAMP contributors
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.ui.music;

import android.animation.ObjectAnimator;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.animation.LinearInterpolator;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.navigation.Navigation;

import org.proninyaroslav.libretorrent.core.model.data.entity.MusicTrack;
import org.proninyaroslav.libretorrent.core.music.MusicPlayerManager;
import org.proninyaroslav.libretorrent.databinding.FragmentNowPlayingBinding;

public class NowPlayingFragment extends Fragment {
    private FragmentNowPlayingBinding binding;
    private MusicPlayerManager player;
    private ObjectAnimator vinylSpin;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable progressTick = new Runnable() {
        @Override
        public void run() {
            if (player != null) {
                player.tickProgress();
            }
            handler.postDelayed(this, 500);
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

        vinylSpin = ObjectAnimator.ofFloat(binding.vinyl, View.ROTATION, 0f, 360f);
        vinylSpin.setDuration(8000);
        vinylSpin.setInterpolator(new LinearInterpolator());
        vinylSpin.setRepeatCount(ObjectAnimator.INFINITE);

        player.observeCurrentTrack().observe(getViewLifecycleOwner(), this::bindTrack);
        player.observePlaying().observe(getViewLifecycleOwner(), this::bindPlaying);
        player.observePositionMs().observe(getViewLifecycleOwner(), pos -> {
            if (pos != null && binding.seekBar.getMax() > 0) {
                binding.seekBar.setProgress(pos.intValue());
            }
        });
        player.observeDurationMs().observe(getViewLifecycleOwner(), dur -> {
            if (dur != null && dur > 0) {
                binding.seekBar.setMax(dur.intValue());
            }
        });

        handler.post(progressTick);
    }

    private void bindTrack(@Nullable MusicTrack track) {
        if (track == null) {
            return;
        }
        binding.title.setText(track.title);
        binding.artist.setText(track.artist);
        binding.album.setText(track.album);
        binding.artInitial.setText(track.album.isEmpty() ? "?" : track.album.substring(0, 1).toUpperCase());
    }

    private void bindPlaying(@Nullable Boolean playing) {
        boolean isPlaying = Boolean.TRUE.equals(playing);
        binding.playPause.setImageResource(isPlaying
                ? org.proninyaroslav.libretorrent.R.drawable.ic_pause_24px
                : org.proninyaroslav.libretorrent.R.drawable.ic_play_arrow_24px);
        if (isPlaying) {
            if (!vinylSpin.isStarted()) {
                vinylSpin.start();
            } else if (vinylSpin.isPaused()) {
                vinylSpin.resume();
            }
        } else {
            vinylSpin.pause();
        }
    }

    @Override
    public void onDestroyView() {
        handler.removeCallbacks(progressTick);
        if (vinylSpin != null) {
            vinylSpin.cancel();
        }
        binding = null;
        super.onDestroyView();
    }
}
