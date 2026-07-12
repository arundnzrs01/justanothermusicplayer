/*
 * Copyright (C) 2026 JAMP contributors
 * Waveform scrubber inspired by JAMP Flutter player and Auxio-style playback UX.
 * Licensed under GPL-3.0. See LICENSE.md and NOTICE.
 */

package org.proninyaroslav.libretorrent.ui.music;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.MotionEvent;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;

import org.proninyaroslav.libretorrent.R;

public class WaveformScrubberView extends View {
    public interface Listener {
        void onSeekProgress(float progress);
    }

    private final Paint[] barPaints = new Paint[4];
    private final Paint mutedPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF barRect = new RectF();
    private float[] waveform = new float[0];
    private float progress;
    private Listener listener;

    public WaveformScrubberView(Context context) {
        super(context);
        init(context);
    }

    public WaveformScrubberView(Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
        init(context);
    }

    private void init(Context context) {
        int[] colors = new int[] {
                ContextCompat.getColor(context, R.color.waveform_blue),
                ContextCompat.getColor(context, R.color.waveform_red),
                ContextCompat.getColor(context, R.color.waveform_pink),
                ContextCompat.getColor(context, R.color.waveform_muted),
        };
        for (int i = 0; i < barPaints.length; i++) {
            barPaints[i] = new Paint(Paint.ANTI_ALIAS_FLAG);
            barPaints[i].setColor(colors[i]);
        }
        mutedPaint.setColor(ContextCompat.getColor(context, R.color.waveform_unplayed));
    }

    public void setWaveform(@NonNull float[] values) {
        waveform = values;
        invalidate();
    }

    public void setProgress(float value) {
        progress = Math.max(0f, Math.min(1f, value));
        invalidate();
    }

    public void setListener(@Nullable Listener listener) {
        this.listener = listener;
    }

    @Override
    protected void onDraw(@NonNull Canvas canvas) {
        super.onDraw(canvas);
        if (waveform.length == 0) {
            return;
        }
        float barWidth = (float) getWidth() / waveform.length;
        for (int i = 0; i < waveform.length; i++) {
            float x = i * barWidth;
            float barHeight = waveform[i] * getHeight();
            float y = (getHeight() - barHeight) / 2f;
            barRect.set(x + 1f, y, x + barWidth - 1f, y + barHeight);
            boolean played = ((float) i / waveform.length) <= progress;
            Paint paint = played ? barPaints[i % barPaints.length] : mutedPaint;
            canvas.drawRoundRect(barRect, 4f, 4f, paint);
        }
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        if (waveform.length == 0 || getWidth() == 0) {
            return super.onTouchEvent(event);
        }
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
            case MotionEvent.ACTION_MOVE:
                float p = event.getX() / getWidth();
                progress = Math.max(0f, Math.min(1f, p));
                if (listener != null) {
                    listener.onSeekProgress(progress);
                }
                invalidate();
                return true;
            default:
                return super.onTouchEvent(event);
        }
    }
}
