/*
 * Copyright (C) 2026 JAMP contributors
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.ui.music;

import android.view.LayoutInflater;
import android.view.ViewGroup;

import androidx.annotation.NonNull;
import androidx.recyclerview.widget.DiffUtil;
import androidx.recyclerview.widget.ListAdapter;
import androidx.recyclerview.widget.RecyclerView;

import org.proninyaroslav.libretorrent.databinding.ItemMusicLibraryBinding;

public class MusicLibraryAdapter extends ListAdapter<MusicLibraryItem, MusicLibraryAdapter.Holder> {
    public interface Listener {
        void onItemClick(@NonNull MusicLibraryItem item);
    }

    private final Listener listener;

    public MusicLibraryAdapter(@NonNull Listener listener) {
        super(DIFF);
        this.listener = listener;
    }

    @NonNull
    @Override
    public Holder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        var binding = ItemMusicLibraryBinding.inflate(
                LayoutInflater.from(parent.getContext()), parent, false);
        return new Holder(binding);
    }

    @Override
    public void onBindViewHolder(@NonNull Holder holder, int position) {
        holder.bind(getItem(position));
    }

    class Holder extends RecyclerView.ViewHolder {
        private final ItemMusicLibraryBinding binding;

        Holder(@NonNull ItemMusicLibraryBinding binding) {
            super(binding.getRoot());
            this.binding = binding;
        }

        void bind(@NonNull MusicLibraryItem item) {
            binding.title.setText(item.title);
            binding.subtitle.setText(item.subtitle);
            binding.count.setText(item.type == MusicLibraryItem.Type.SONG
                    ? formatDuration(item.tracks.get(0).durationMs)
                    : item.trackCount + " tracks");
            binding.artInitial.setText(item.title.isEmpty() ? "?" : item.title.substring(0, 1).toUpperCase());
            binding.getRoot().setOnClickListener(v -> listener.onItemClick(item));
        }

        @NonNull
        private String formatDuration(long ms) {
            long totalSec = ms / 1000;
            long min = totalSec / 60;
            long sec = totalSec % 60;
            return min + ":" + (sec < 10 ? "0" : "") + sec;
        }
    }

    private static final DiffUtil.ItemCallback<MusicLibraryItem> DIFF =
            new DiffUtil.ItemCallback<>() {
                @Override
                public boolean areItemsTheSame(@NonNull MusicLibraryItem oldItem, @NonNull MusicLibraryItem newItem) {
                    return oldItem.title.equals(newItem.title) && oldItem.type == newItem.type;
                }

                @Override
                public boolean areContentsTheSame(@NonNull MusicLibraryItem oldItem, @NonNull MusicLibraryItem newItem) {
                    return oldItem.trackCount == newItem.trackCount
                            && oldItem.subtitle.equals(newItem.subtitle);
                }
            };
}
