package com.maid.app.maid

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Schedules the daily morning/evening voice briefings natively, so they can be spoken with
 * Android TextToSpeech at the set time even when the Flutter app isn't running.
 *
 * Flutter pushes the settings and pre-written briefing texts (one per date) via [configure];
 * everything is persisted so [BriefingAlarmReceiver] can re-arm the alarms after a reboot.
 */
object BriefingScheduler {
    const val KIND_MORNING = "morning"
    const val KIND_EVENING = "evening"
    const val EXTRA_KIND = "kind"
    const val ACTION_FIRE = "com.maid.app.maid.BRIEFING_FIRE"

    private const val PREFS = "maid_briefing"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_SPEAK = "speak"
    private const val KEY_USER_NAME = "user_name"
    private const val KEY_TEXTS = "texts"

    fun configure(context: Context, args: Map<*, *>) {
        val texts = (args["texts"] as? Map<*, *>)
            ?.entries
            ?.associate { it.key.toString() to it.value.toString() }
            ?: emptyMap()

        prefs(context).edit()
            .putBoolean(KEY_ENABLED, args["enabled"] as? Boolean ?: true)
            .putBoolean(KEY_SPEAK, args["speak"] as? Boolean ?: true)
            .putInt(minutesKey(KIND_MORNING), (args["morningMinutes"] as? Number)?.toInt() ?: 8 * 60)
            .putInt(minutesKey(KIND_EVENING), (args["eveningMinutes"] as? Number)?.toInt() ?: 21 * 60)
            .putString(KEY_USER_NAME, args["userName"] as? String ?: "")
            .putString(KEY_TEXTS, JSONObject(texts).toString())
            .apply()

        scheduleAll(context)
    }

    fun scheduleAll(context: Context) {
        scheduleNext(context, KIND_MORNING)
        scheduleNext(context, KIND_EVENING)
    }

    fun isEnabled(context: Context) = prefs(context).getBoolean(KEY_ENABLED, false)

    fun shouldSpeak(context: Context) = prefs(context).getBoolean(KEY_SPEAK, true)

    /** Arms the next occurrence of [kind] (strictly in the future), or cancels it if disabled. */
    fun scheduleNext(context: Context, kind: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = firePendingIntent(context, kind)

        if (!isEnabled(context)) {
            alarmManager.cancel(pendingIntent)
            return
        }

        val minutes = prefs(context).getInt(minutesKey(kind), if (kind == KIND_MORNING) 8 * 60 else 21 * 60)
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, minutes / 60)
            set(Calendar.MINUTE, minutes % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis() + 1000) add(Calendar.DAY_OF_YEAR, 1)
        }
        setAlarm(context, next.timeInMillis, pendingIntent)
    }

    /** Fires a briefing of [kind] after [delaySeconds] — used by the Settings test button. */
    fun scheduleTest(context: Context, kind: String, delaySeconds: Int) {
        val intent = Intent(context, BriefingAlarmReceiver::class.java).apply {
            action = ACTION_FIRE
            putExtra(EXTRA_KIND, kind)
            putExtra(BriefingAlarmReceiver.EXTRA_IS_TEST, true)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, 2100, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        setAlarm(context, System.currentTimeMillis() + delaySeconds * 1000L, pendingIntent)
    }

    private fun setAlarm(context: Context, triggerAt: Long, pendingIntent: PendingIntent) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()
        if (canExact) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        } else {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    /** Briefing text for today, falling back to a generic greeting if the app hasn't synced it. */
    fun textFor(context: Context, kind: String): String {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Calendar.getInstance().time)
        val stored = try {
            JSONObject(prefs(context).getString(KEY_TEXTS, "{}") ?: "{}").optString("${kind}_$today", "")
        } catch (_: Exception) {
            ""
        }
        if (stored.isNotBlank()) return stored

        val name = prefs(context).getString(KEY_USER_NAME, "").orEmpty()
        val greetingName = if (name.isBlank()) "" else " $name"
        return if (kind == KIND_MORNING) {
            "Good morning$greetingName! Open Maid to see your tasks and plan for today."
        } else {
            "Good evening$greetingName! Open Maid to review what's left on your list today."
        }
    }

    fun titleFor(context: Context, kind: String): String {
        val name = prefs(context).getString(KEY_USER_NAME, "").orEmpty()
        return if (kind == KIND_MORNING) {
            if (name.isBlank()) "☀️ Good Morning!" else "☀️ Good Morning $name!"
        } else {
            "🌙 Evening Wrap-Up"
        }
    }

    private fun firePendingIntent(context: Context, kind: String): PendingIntent {
        val intent = Intent(context, BriefingAlarmReceiver::class.java).apply {
            action = ACTION_FIRE
            putExtra(EXTRA_KIND, kind)
        }
        val requestCode = if (kind == KIND_MORNING) 2001 else 2002
        return PendingIntent.getBroadcast(
            context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun minutesKey(kind: String) = "${kind}_minutes"

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
