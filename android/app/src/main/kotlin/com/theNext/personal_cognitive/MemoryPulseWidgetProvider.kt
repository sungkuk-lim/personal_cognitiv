package com.theNext.personal_cognitive

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class MemoryPulseWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.memory_pulse_widget).apply {
                setTextViewText(
                    R.id.widget_title,
                    widgetData.getString("widget_title", context.getString(R.string.widget_default_title)),
                )
                setTextViewText(
                    R.id.widget_count,
                    widgetData.getString("widget_count", context.getString(R.string.widget_default_count)),
                )
                setTextViewText(
                    R.id.widget_latest,
                    widgetData.getString("widget_latest", context.getString(R.string.widget_empty)),
                )
                setTextViewText(R.id.widget_time, widgetData.getString("widget_time", ""))
                setTextViewText(
                    R.id.widget_mic_label,
                    widgetData.getString("widget_mic_label", context.getString(R.string.widget_mic)),
                )
                setTextViewText(
                    R.id.widget_search_label,
                    widgetData.getString("widget_search_label", context.getString(R.string.widget_search)),
                )
                setTextViewText(
                    R.id.widget_graph_label,
                    widgetData.getString("widget_graph_label", context.getString(R.string.widget_graph)),
                )

                applyWidgetTheme(context, widgetData)

                val openApp = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("memoryos://open"),
                )
                val capture = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("memoryos://capture"),
                )
                val search = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("memoryos://search"),
                )
                val graph = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("memoryos://graph"),
                )

                setOnClickPendingIntent(R.id.widget_btn_mic, capture)
                setOnClickPendingIntent(R.id.widget_btn_search, search)
                setOnClickPendingIntent(R.id.widget_btn_graph, graph)
                setOnClickPendingIntent(R.id.widget_memory_card, openApp)
                setOnClickPendingIntent(R.id.widget_root, openApp)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (_: Exception) {
                // 미지원 뷰·비트맵 오류 시 최소 레이아웃으로 폴백
                val fallback = RemoteViews(context.packageName, R.layout.memory_pulse_widget).apply {
                    setTextViewText(R.id.widget_title, context.getString(R.string.widget_default_title))
                    setTextViewText(R.id.widget_latest, context.getString(R.string.widget_empty))
                }
                appWidgetManager.updateAppWidget(widgetId, fallback)
            }
        }
    }
}
