package com.maid.app.maid

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class MaidTodoWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // Date and "today" are computed here rather than in Flutter, so the widget rolls over at
        // midnight on its periodic update even when the app hasn't been opened.
        val dateStr = SimpleDateFormat("EEE, MMM d", Locale.getDefault()).format(Calendar.getInstance().time)
        val tasksText = buildWidgetText(context)
            ?: getStoredString(context, "widget_tasks_text")
            ?: "🎉 All caught up!\nNothing planned."

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

    /** Today's events, then upcoming one-off events, then pending tasks. Null if no data saved yet. */
    private fun buildWidgetText(context: Context): String? {
        val eventsJson = getStoredString(context, "widget_events_json") ?: return null
        val tasksJson = getStoredString(context, "widget_pending_tasks_json") ?: "[]"

        return try {
            val keyFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val labelFormat = SimpleDateFormat("EEE d", Locale.getDefault())
            val today = keyFormat.format(Calendar.getInstance().time)
            val events = toObjects(JSONArray(eventsJson))
            val tasks = toObjects(JSONArray(tasksJson))

            val lines = mutableListOf<String>()

            // 1. Today's events
            val todayEvents = events.filter { it.optString("date") == today }
            for (event in todayEvents.take(4)) {
                lines.add("📅 ${event.optString("time")}  ${event.optString("title")}")
            }
            if (todayEvents.size > 4) lines.add("   +${todayEvents.size - 4} more events today")

            // 2. Next upcoming one-off events on later dates (daily/weekly routines are skipped)
            val upcoming = events.filter { it.optString("date") > today && it.optString("recurring") != "1" }
            for (event in upcoming.take(2)) {
                val label = try {
                    labelFormat.format(keyFormat.parse(event.optString("date"))!!)
                } catch (_: Exception) {
                    event.optString("date")
                }
                lines.add("🔜 $label · ${event.optString("title")}")
            }

            // 3. Pending tasks due today, undated or overdue; otherwise any pending task
            val todayTasks = tasks.filter {
                val due = it.optString("due")
                due.isEmpty() || due <= today
            }
            val tasksToShow = if (todayTasks.isNotEmpty()) todayTasks else tasks
            val taskRoom = maxOf(2, 8 - lines.size)
            for (task in tasksToShow.take(taskRoom)) {
                val icon = when (task.optInt("priority")) {
                    3 -> "🔴"
                    2 -> "🟡"
                    else -> "•"
                }
                lines.add("$icon ${task.optString("title")}")
            }
            if (tasksToShow.size > taskRoom) lines.add("+${tasksToShow.size - taskRoom} more tasks...")

            if (lines.isEmpty()) "🎉 All caught up!\nNothing planned." else lines.joinToString("\n")
        } catch (_: Exception) {
            null
        }
    }

    private fun toObjects(array: JSONArray): List<JSONObject> =
        (0 until array.length()).map { array.getJSONObject(it) }

    private fun getStoredString(context: Context, key: String): String? {
        val candidatePrefs = listOf(
            "HomeWidgetPreferences",
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
