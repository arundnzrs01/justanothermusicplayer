/*
 * Copyright (C) 2026 JAMP contributors
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.ui.settings.pages;

import android.content.Context;
import android.os.Bundle;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.preference.Preference;
import androidx.preference.SwitchPreferenceCompat;

import org.proninyaroslav.libretorrent.R;
import org.proninyaroslav.libretorrent.core.music.MusicRepository;
import org.proninyaroslav.libretorrent.core.utils.Utils;
import com.google.android.material.snackbar.Snackbar;
import org.proninyaroslav.libretorrent.databinding.FragmentPreferenceBinding;
import org.proninyaroslav.libretorrent.ui.settings.CustomPreferenceFragment;

import io.reactivex.rxjava3.android.schedulers.AndroidSchedulers;
import io.reactivex.rxjava3.disposables.CompositeDisposable;

public class MusicSettingsFragment extends CustomPreferenceFragment {
    private AppCompatActivity activity;
    private final CompositeDisposable disposables = new CompositeDisposable();

    @Override
    public void onAttach(@NonNull Context context) {
        super.onAttach(context);
        if (context instanceof AppCompatActivity a) {
            activity = a;
        }
    }

    @Override
    public void onCreatePreferences(@Nullable Bundle savedInstanceState, @Nullable String rootKey) {
        addPreferencesFromResource(R.xml.pref_music);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        var binding = FragmentPreferenceBinding.bind(view);
        binding.appBar.setTitle(R.string.pref_header_music);
        binding.appBar.setNavigationOnClickListener(v -> requireActivity().getOnBackPressedDispatcher().onBackPressed());

        if (activity == null) {
            activity = (AppCompatActivity) requireActivity();
        }

        Preference folder = findPreference(getString(R.string.pref_key_music_library_folder));
        if (folder != null) {
            var uri = Utils.getTorrentDownloadPath(requireContext());
            folder.setSummary(uri != null ? uri.toString() : getString(R.string.music_library_folder_summary));
        }

        Preference rescan = findPreference(getString(R.string.pref_key_music_rescan));
        if (rescan != null) {
            rescan.setOnPreferenceClickListener(p -> {
                disposables.add(new MusicRepository(requireContext()).rescanLibrary()
                        .observeOn(AndroidSchedulers.mainThread())
                        .subscribe(() -> Snackbar.make(view, R.string.music_rescan_done, Snackbar.LENGTH_SHORT).show(),
                                (e) -> Snackbar.make(view, e.getMessage(), Snackbar.LENGTH_LONG).show()));
                return true;
            });
        }

        SwitchPreferenceCompat autoScan = findPreference(getString(R.string.pref_key_music_auto_scan));
        if (autoScan != null) {
            var prefs = requireContext().getSharedPreferences("jamp_music", Context.MODE_PRIVATE);
            autoScan.setChecked(prefs.getBoolean(getString(R.string.pref_key_music_auto_scan), true));
            autoScan.setOnPreferenceChangeListener((p, v) -> {
                prefs.edit().putBoolean(getString(R.string.pref_key_music_auto_scan), (Boolean) v).apply();
                return true;
            });
        }

        super.onViewCreated(view, savedInstanceState);
    }

    @Override
    public void onDestroyView() {
        disposables.clear();
        super.onDestroyView();
    }
}
