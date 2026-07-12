/*
 * Copyright (C) 2026 JAMP contributors
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.ui.music;

import android.content.Context;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.ViewModelProvider;
import androidx.navigation.Navigation;
import androidx.recyclerview.widget.GridLayoutManager;

import com.google.android.material.chip.Chip;

import org.proninyaroslav.libretorrent.R;
import org.proninyaroslav.libretorrent.core.music.MusicPlayerManager;
import org.proninyaroslav.libretorrent.databinding.FragmentMusicLibraryBinding;

public class MusicLibraryFragment extends Fragment implements MusicLibraryAdapter.Listener {
    private FragmentMusicLibraryBinding binding;
    private MusicLibraryViewModel viewModel;
    private MusicLibraryAdapter adapter;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        binding = FragmentMusicLibraryBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        viewModel = new ViewModelProvider(this).get(MusicLibraryViewModel.class);
        adapter = new MusicLibraryAdapter(this);
        binding.recycler.setLayoutManager(new GridLayoutManager(requireContext(), 2));
        binding.recycler.setAdapter(adapter);

        setupViewModeChips();
        binding.search.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) {
                viewModel.setQuery(s == null ? "" : s.toString());
            }
            @Override public void afterTextChanged(Editable s) {}
        });

        binding.refresh.setOnClickListener(v -> viewModel.rescan());
        binding.clearFilters.setOnClickListener(v -> {
            viewModel.clearFilters();
            viewModel.setViewMode(MusicViewMode.ALBUMS);
            selectChip(MusicViewMode.ALBUMS);
        });

        viewModel.observeItems().observe(getViewLifecycleOwner(), items -> {
            adapter.submitList(items);
            if (binding != null) {
                binding.empty.setVisibility(items == null || items.isEmpty() ? View.VISIBLE : View.GONE);
            }
        });
        viewModel.observeScanning().observe(getViewLifecycleOwner(), scanning -> {
            binding.refresh.setEnabled(!Boolean.TRUE.equals(scanning));
            binding.progress.setVisibility(Boolean.TRUE.equals(scanning) ? View.VISIBLE : View.GONE);
        });
        viewModel.observeMessage().observe(getViewLifecycleOwner(), msg -> {
            binding.empty.setVisibility(adapter.getCurrentList().isEmpty() ? View.VISIBLE : View.GONE);
            if (msg != null) {
                binding.empty.setText(msg);
            }
        });

        if (savedInstanceState == null) {
            var prefs = requireContext().getSharedPreferences("jamp_music", Context.MODE_PRIVATE);
            if (prefs.getBoolean(getString(R.string.pref_key_music_auto_scan), true)) {
                viewModel.rescan();
            }
        }
    }

    private void setupViewModeChips() {
        binding.chipAlbums.setOnClickListener(v -> setMode(MusicViewMode.ALBUMS));
        binding.chipArtists.setOnClickListener(v -> setMode(MusicViewMode.ARTISTS));
        binding.chipGenres.setOnClickListener(v -> setMode(MusicViewMode.GENRES));
        binding.chipYears.setOnClickListener(v -> setMode(MusicViewMode.YEARS));
        binding.chipSongs.setOnClickListener(v -> setMode(MusicViewMode.SONGS));
        selectChip(MusicViewMode.ALBUMS);
    }

    private void setMode(@NonNull MusicViewMode mode) {
        viewModel.setViewMode(mode);
        selectChip(mode);
        binding.clearFilters.setVisibility(viewModel.hasActiveFilters() ? View.VISIBLE : View.GONE);
    }

    private void selectChip(@NonNull MusicViewMode mode) {
        setChipChecked(binding.chipAlbums, mode == MusicViewMode.ALBUMS);
        setChipChecked(binding.chipArtists, mode == MusicViewMode.ARTISTS);
        setChipChecked(binding.chipGenres, mode == MusicViewMode.GENRES);
        setChipChecked(binding.chipYears, mode == MusicViewMode.YEARS);
        setChipChecked(binding.chipSongs, mode == MusicViewMode.SONGS);
    }

    private void setChipChecked(@NonNull Chip chip, boolean checked) {
        chip.setChecked(checked);
    }

    @Override
    public void onItemClick(@NonNull MusicLibraryItem item) {
        MusicPlayerManager.getInstance(requireContext()).playQueue(item.tracks, 0);
        Navigation.findNavController(requireView()).navigate(R.id.action_music_to_now_playing);
    }

    @Override
    public void onDestroyView() {
        binding = null;
        super.onDestroyView();
    }
}
