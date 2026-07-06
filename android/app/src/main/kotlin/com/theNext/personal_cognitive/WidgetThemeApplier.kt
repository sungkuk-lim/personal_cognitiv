package com.theNext.personal_cognitive

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.widget.RemoteViews

internal object WidgetThemeBitmaps {
    fun roundedRect(context: Context, color: Int, radiusDp: Float, widthDp: Int = 120, heightDp: Int = 48): Bitmap {
        val density = context.resources.displayMetrics.density
        val width = (widthDp * density).toInt().coerceAtLeast(8)
        val height = (heightDp * density).toInt().coerceAtLeast(8)
        val radius = radiusDp * density
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        canvas.drawRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), radius, radius, paint)
        return bitmap
    }

    fun verticalGradient(
        context: Context,
        topColor: Int,
        bottomColor: Int,
        radiusDp: Float,
        widthDp: Int = 320,
        heightDp: Int = 200,
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val width = (widthDp * density).toInt().coerceAtLeast(8)
        val height = (heightDp * density).toInt().coerceAtLeast(8)
        val radius = radiusDp * density
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val rect = RectF(0f, 0f, width.toFloat(), height.toFloat())
        val path = Path().apply { addRoundRect(rect, radius, radius, Path.Direction.CW) }
        canvas.save()
        canvas.clipPath(path)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f,
                0f,
                0f,
                height.toFloat(),
                topColor,
                bottomColor,
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(rect, paint)
        canvas.restore()
        return bitmap
    }
}

internal fun RemoteViews.applyWidgetTheme(context: Context, widgetData: android.content.SharedPreferences) {
    fun readColor(key: String): Int {
        if (!widgetData.contains(key)) return 0
        return try {
            widgetData.getInt(key, 0)
        } catch (_: ClassCastException) {
            widgetData.getLong(key, 0L).toInt()
        }
    }

    fun readInt(prefs: android.content.SharedPreferences, key: String, default: Int): Int {
        if (!prefs.contains(key)) return default
        return try {
            prefs.getInt(key, default)
        } catch (_: ClassCastException) {
            prefs.getLong(key, default.toLong()).toInt()
        }
    }

    val bgTop = readColor("widget_bg_color")
    val bgBottom = readColor("widget_bg_color_end")
    if (bgTop != 0) {
        val bgBitmap = if (bgBottom != 0) {
            WidgetThemeBitmaps.verticalGradient(context, bgTop, bgBottom, 24f)
        } else {
            WidgetThemeBitmaps.roundedRect(context, bgTop, 24f, 320, 200)
        }
        setImageViewBitmap(R.id.widget_bg, bgBitmap)
    }

    val accent = readColor("widget_accent_color")
    val isDark = readInt(widgetData, "widget_is_dark", 1) != 0
    if (accent != 0) {
        setImageViewBitmap(
            R.id.widget_graph_network,
            WidgetGraphBackgroundRenderer.render(context, accent, isDark, widthDp = 480, heightDp = 300),
        )
        setInt(R.id.widget_brand_dot, "setColorFilter", accent)
    } else {
        setImageViewResource(R.id.widget_graph_network, R.drawable.widget_graph_network)
    }

    val textPrimary = readColor("widget_text_primary")
    if (textPrimary != 0) {
        setTextColor(R.id.widget_title, textPrimary)
    }

    val textCard = readColor("widget_text_card")
    if (textCard != 0) {
        setTextColor(R.id.widget_latest, textCard)
    }
    val textCardMuted = readColor("widget_text_card_muted")
    if (textCardMuted != 0) {
        setTextColor(R.id.widget_time, textCardMuted)
    }

    val cardBg = readColor("widget_card_bg")
    if (cardBg != 0) {
        setImageViewBitmap(R.id.widget_memory_card_bg, WidgetThemeBitmaps.roundedRect(context, cardBg, 16f, 280, 120))
    }

    applyChip(
        context = context,
        bgViewId = R.id.widget_graph_chip_bg,
        bgColor = readColor("widget_graph_chip_bg"),
        onColor = readColor("widget_graph_chip_on"),
        labelViewId = R.id.widget_graph_label,
        iconViewId = R.id.widget_graph_icon,
        radiusDp = 13f,
        widthDp = 88,
        heightDp = 26,
    )

    applyChip(
        context = context,
        bgViewId = R.id.widget_count_chip_bg,
        bgColor = readColor("widget_count_chip_bg"),
        onColor = readColor("widget_count_chip_on"),
        labelViewId = R.id.widget_count,
        iconViewId = null,
        radiusDp = 13f,
        widthDp = 72,
        heightDp = 26,
    )

    val btnPrimary = readColor("widget_btn_primary_color")
    val btnPrimaryOn = readColor("widget_btn_primary_on_color")
    if (btnPrimary != 0) {
        setImageViewBitmap(
            R.id.widget_btn_mic_bg,
            WidgetThemeBitmaps.roundedRect(context, btnPrimary, 14f, 160, 44),
        )
        if (btnPrimaryOn != 0) {
            setTextColor(R.id.widget_mic_label, btnPrimaryOn)
            setInt(R.id.widget_mic_icon, "setColorFilter", btnPrimaryOn)
        }
    }

    val btnSecondary = readColor("widget_btn_secondary_color")
    val btnSecondaryOn = readColor("widget_btn_secondary_on_color")
    if (btnSecondary != 0) {
        setImageViewBitmap(
            R.id.widget_btn_search_bg,
            WidgetThemeBitmaps.roundedRect(context, btnSecondary, 14f, 160, 44),
        )
        if (btnSecondaryOn != 0) {
            setTextColor(R.id.widget_search_label, btnSecondaryOn)
            setInt(R.id.widget_search_icon, "setColorFilter", btnSecondaryOn)
        }
    }
}

private fun RemoteViews.applyChip(
    context: Context,
    bgViewId: Int,
    bgColor: Int,
    onColor: Int,
    labelViewId: Int,
    iconViewId: Int?,
    radiusDp: Float,
    widthDp: Int,
    heightDp: Int,
) {
    if (bgColor != 0) {
        setImageViewBitmap(bgViewId, WidgetThemeBitmaps.roundedRect(context, bgColor, radiusDp, widthDp, heightDp))
    }
    if (onColor != 0) {
        setTextColor(labelViewId, onColor)
        iconViewId?.let { setInt(it, "setColorFilter", onColor) }
    }
}
