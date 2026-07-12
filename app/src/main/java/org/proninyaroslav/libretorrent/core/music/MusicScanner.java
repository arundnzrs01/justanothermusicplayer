/*
 * Copyright (C) 2026 JAMP contributors
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.core.music;

import android.content.Context;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Build;

import androidx.annotation.NonNull;

import org.apache.commons.io.FileUtils;
import org.apache.commons.io.filefilter.IOFileFilter;
import org.apache.commons.io.filefilter.TrueFileFilter;
import org.proninyaroslav.libretorrent.core.model.data.entity.MusicTrack;
import org.proninyaroslav.libretorrent.core.system.FileSystemFacade;
import org.proninyaroslav.libretorrent.core.system.SystemFacadeHelper;
import org.proninyaroslav.libretorrent.core.utils.Utils;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public final class MusicScanner {
    private static final String[] EXTENSIONS = {
            "mp3", "flac", "m4a", "ogg", "wav", "aac", "opus", "wma"
    };

    private MusicScanner() {
    }

    @NonNull
    public static List<MusicTrack> scanDownloadFolder(@NonNull Context appContext) {
        var tracks = new ArrayList<MusicTrack>();
        Uri rootUri = Utils.getTorrentDownloadPath(appContext);
        if (rootUri == null) {
            return tracks;
        }

        FileSystemFacade fs = SystemFacadeHelper.getFileSystemFacade(appContext);
        try {
            String dirPath = fs.getDirPath(rootUri);
            if (dirPath != null) {
                collectFromDirectory(appContext, new File(dirPath), tracks);
            }
        } catch (Exception ignored) {
            /* SAF-only paths may not map to java.io.File */
        }
        return tracks;
    }

    private static void collectFromDirectory(
            @NonNull Context appContext,
            @NonNull File dir,
            @NonNull List<MusicTrack> out) {
        if (!dir.isDirectory()) {
            return;
        }
        IOFileFilter filter = new IOFileFilter() {
            @Override
            public boolean accept(File file) {
                if (file.isDirectory()) {
                    return true;
                }
                return isMusicFile(file.getName());
            }

            @Override
            public boolean accept(File dir, String name) {
                return accept(new File(dir, name));
            }
        };
        for (File file : FileUtils.listFiles(dir, filter, TrueFileFilter.INSTANCE)) {
            if (file.isFile()) {
                MusicTrack track = readMetadata(appContext, file);
                if (track != null) {
                    out.add(track);
                }
            }
        }
    }

    private static boolean isMusicFile(@NonNull String name) {
        int dot = name.lastIndexOf('.');
        if (dot < 0) {
            return false;
        }
        String ext = name.substring(dot + 1).toLowerCase(Locale.US);
        for (String allowed : EXTENSIONS) {
            if (allowed.equals(ext)) {
                return true;
            }
        }
        return false;
    }

    private static MusicTrack readMetadata(@NonNull Context appContext, @NonNull File file) {
        var retriever = new MediaMetadataRetriever();
        try {
            retriever.setDataSource(file.getAbsolutePath());
            var track = new MusicTrack();
            track.path = file.getAbsolutePath();
            track.title = firstNonEmpty(
                    retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE),
                    stripExtension(file.getName()));
            track.artist = firstNonEmpty(
                    retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST),
                    "Unknown Artist");
            track.album = firstNonEmpty(
                    retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM),
                    "Unknown Album");
            track.genre = emptyToNull(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_GENRE));
            track.year = parseYear(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_YEAR));
            track.durationMs = parseLong(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                track.trackNumber = parseInt(retriever.extractMetadata(
                        MediaMetadataRetriever.METADATA_KEY_CD_TRACK_NUMBER));
            }
            track.dateAdded = System.currentTimeMillis();
            return track;
        } catch (Exception e) {
            return null;
        } finally {
            try {
                retriever.release();
            } catch (Exception ignored) {
            }
        }
    }

    @NonNull
    private static String firstNonEmpty(String value, @NonNull String fallback) {
        if (value == null || value.trim().isEmpty()) {
            return fallback;
        }
        return value.trim();
    }

    private static String emptyToNull(String value) {
        if (value == null || value.trim().isEmpty()) {
            return null;
        }
        return value.trim();
    }

    private static Integer parseYear(String value) {
        if (value == null || value.isEmpty()) {
            return null;
        }
        try {
            String digits = value.replaceAll("[^0-9]", "");
            if (digits.length() >= 4) {
                return Integer.parseInt(digits.substring(0, 4));
            }
        } catch (NumberFormatException ignored) {
        }
        return null;
    }

    private static long parseLong(String value) {
        if (value == null) {
            return 0L;
        }
        try {
            return Long.parseLong(value);
        } catch (NumberFormatException e) {
            return 0L;
        }
    }

    private static Integer parseInt(String value) {
        if (value == null || value.isEmpty()) {
            return null;
        }
        try {
            int slash = value.indexOf('/');
            if (slash > 0) {
                value = value.substring(0, slash);
            }
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    @NonNull
    private static String stripExtension(@NonNull String name) {
        int dot = name.lastIndexOf('.');
        return dot > 0 ? name.substring(0, dot) : name;
    }
}
