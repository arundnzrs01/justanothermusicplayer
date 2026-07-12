/*
 * Copyright (C) 2026 JAMP contributors
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.core.music;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.media.MediaMetadataRetriever;
import android.widget.ImageView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.proninyaroslav.libretorrent.core.model.data.entity.MusicTrack;

import java.util.Random;

public final class AlbumArtLoader {
    private AlbumArtLoader() {
    }

    @Nullable
    public static Bitmap loadBitmap(@NonNull String path) {
        var retriever = new MediaMetadataRetriever();
        try {
            retriever.setDataSource(path);
            byte[] art = retriever.getEmbeddedPicture();
            if (art != null) {
                return BitmapFactory.decodeByteArray(art, 0, art.length);
            }
        } catch (Exception ignored) {
        } finally {
            try {
                retriever.release();
            } catch (Exception ignored) {
            }
        }
        return null;
    }

    public static void bind(@NonNull ImageView view, @Nullable MusicTrack track) {
        if (track == null) {
            view.setImageDrawable(null);
            view.setContentDescription(null);
            return;
        }
        Bitmap bitmap = loadBitmap(track.path);
        if (bitmap != null) {
            view.setImageBitmap(bitmap);
            view.setScaleType(ImageView.ScaleType.CENTER_CROP);
        } else {
            view.setImageDrawable(null);
        }
        view.setContentDescription(track.album);
    }

    @NonNull
    public static float[] waveformForTrack(@NonNull MusicTrack track) {
        Random random = new Random(track.path.hashCode());
        float[] bars = new float[48];
        for (int i = 0; i < bars.length; i++) {
            bars[i] = 0.25f + random.nextFloat() * 0.75f;
        }
        return bars;
    }
}
