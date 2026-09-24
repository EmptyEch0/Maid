package com.maid.app.maid

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class MaidTodoWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val dateStr = getStoredString(context, "widget_date") ?: "Today"
        val tasksText = getStoredString(context, "widget_tasks_text") ?: "🎉 All caught up!\nNothing planned."

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.maid_todo_widget).apply {
                setTextViewText(R.id.widget_date, dateStr)
                setTextViewText(R.id.widget_tasks_text, tasksText)

                // PendingIntent for Mic Button (triggers Voice Read Out Loud)
                val micIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("maid://read_aloud")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val micPendingIntent = PendingIntent.getActivity(
                    context,
                    101,
                    micIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_mic_button, micPendingIntent)

                // PendingIntent for Plus Button (triggers Add Task)
                val addIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("maid://add_task")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val addPendingIntent = PendingIntent.getActivity(
                    context,
                    102,
                    addIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_add_button, addPendingIntent)

                // PendingIntent for Open Button / Card (opens Tasks Inbox)
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("maid://tasks")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val openPendingIntent = PendingIntent.getActivity(
                    context,
                    103,
                    openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_open_button, openPendingIntent)
                setOnClickPendingIntent(R.id.widget_root, openPendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun getStoredString(context: Context, key: String): String? {
        val candidatePrefs = listOf(
            "group.com.maid.app.maid",
            "${context.packageName}_preferences",
            "FlutterSharedPreferences",
            context.packageName
        )
        for (prefName in candidatePrefs) {
            try {
                val sp = context.getSharedPreferences(prefName, Context.MODE_PRIVATE)
                val directVal = sp.getString(key, null)
                if (!directVal.isNullOrBlank()) return directVal

                val flutterVal = sp.getString("flutter.$key", null)
                if (!flutterVal.isNullOrBlank()) return flutterVal
            } catch (_: Exception) {}
        }
        return null
    }
}
