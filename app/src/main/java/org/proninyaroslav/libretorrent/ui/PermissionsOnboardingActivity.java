/*
 * Copyright (C) 2026 JAMP contributors
 *
 * This file is part of JAMP Torrent, a derivative of LibreTorrent.
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.ui;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.provider.Settings;
import android.view.View;
import android.widget.TextView;

import androidx.annotation.Nullable;

import com.google.android.material.button.MaterialButton;

import org.proninyaroslav.libretorrent.MainActivity;
import org.proninyaroslav.libretorrent.R;
import org.proninyaroslav.libretorrent.core.utils.Utils;
import org.proninyaroslav.libretorrent.ui.base.ThemeActivity;

public class PermissionsOnboardingActivity extends ThemeActivity {
    private static final String PREFS = "jamp_onboarding";
    private static final String KEY_DONE = "completed";

    private PermissionManager permissionManager;
    private TextView messageView;
    private MaterialButton openSettingsButton;

    public static boolean isComplete(SharedPreferences prefs) {
        return prefs.getBoolean(KEY_DONE, false);
    }

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        var prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
        if (isComplete(prefs)) {
            launchMainAndFinish();
            return;
        }

        Utils.enableEdgeToEdge(this);
        setContentView(R.layout.activity_permissions_onboarding);

        messageView = findViewById(R.id.onboarding_message);
        openSettingsButton = findViewById(R.id.open_settings);
        var grantButton = findViewById(R.id.grant_permissions);
        var skipButton = findViewById(R.id.skip_permissions);

        permissionManager = new PermissionManager(this, new PermissionManager.Callback() {
            @Override
            public void onStorageResult(boolean isGranted, boolean shouldRequestStoragePermission) {
                updateMessage();
                if (essentialsGranted()) {
                    completeAndLaunch();
                } else if (!isGranted) {
                    openSettingsButton.setVisibility(View.VISIBLE);
                }
            }

            @Override
            public void onNotificationResult(boolean isGranted, boolean shouldRequestNotificationPermission) {
                updateMessage();
                if (essentialsGranted()) {
                    completeAndLaunch();
                }
            }
        });

        grantButton.setOnClickListener(v -> {
            messageView.setVisibility(View.GONE);
            permissionManager.requestPermissions();
        });

        openSettingsButton.setOnClickListener(v ->
                startActivity(new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(android.net.Uri.fromParts("package", getPackageName(), null))));

        skipButton.setOnClickListener(v -> completeAndLaunch());
    }

    private boolean essentialsGranted() {
        return permissionManager.checkStoragePermissions();
    }

    private void updateMessage() {
        if (essentialsGranted()) {
            messageView.setVisibility(View.GONE);
            return;
        }
        messageView.setText(R.string.perm_denied_warning);
        messageView.setVisibility(View.VISIBLE);
    }

    private void completeAndLaunch() {
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(KEY_DONE, true).apply();
        launchMainAndFinish();
    }

    private void launchMainAndFinish() {
        startActivity(new Intent(this, MainActivity.class));
        finish();
    }
}
