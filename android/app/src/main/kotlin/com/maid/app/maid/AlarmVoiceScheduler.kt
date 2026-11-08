package com.maid.app.maid

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Native scheduling for voice alarms ("Maid is calling"). Flutter pushes each alarm here; it is
 * persisted so alarms survive reboots and can ring with the app closed. One-time alarms that are
 * dismissed natively are reported back to Flutter via [takeCompletedOneTime].
 */
object AlarmVoiceScheduler {
    const val ACTION_FIRE = "com.maid.app.maid.VOICE_ALARM_FIRE"
    const val EXTRA_ALARM_ID = "alarm_id"
    const val EXTRA_IS_TEST = "is_test"

    private const val PREFS = "maid_voice_alarms"
    private const val KEY_ALARMS = "alarms"
    private const val KEY_USER_NAME = "user_name"
    private const val KEY_COMPLETED = "completed_one_time"
    const val TEST_ALARM_ID = "__maid_test_alarm__"

    data class VoiceAlarm(
        val id: String,
        val title: String,
        val description: String,
        val hour: Int,
        val minute: Int,
        /** ISO weekdays, 1 = Monday ... 7 = Sunday. Empty = one-time. */
        val days: List<Int>,
        val vibrate: Boolean,
        val snoozeMinutes: Int,
    ) {
        val isRepeating get() = days.isNotEmpty()

        fun toJson(): JSONObject = JSONObject()
            .put("id", id).put("title", title).put("description", description)
            .put("hour", hour).put("minute", minute).put("days", JSONArray(days))
            .put("vibrate", vibrate).put("snoozeMinutes", snoozeMinutes)

        companion object {
            fun fromJson(json: JSONObject): VoiceAlarm {
                val days = json.optJSONArray("days") ?: JSONArray()
                return VoiceAlarm(
                    id = json.getString("id"),
                    title = json.optString("title"),
                    description = json.optString("description"),
                    hour = json.optInt("hour", 7),
                    minute = json.optInt("minute", 0),
                    days = (0 until days.length()).map { days.getInt(it) },
                    vibrate = json.optBoolean("vibrate", true),
                    snoozeMinutes = json.optInt("snoozeMinutes", 5),
                )
            }

            fun fromArgs(args: Map<*, *>): VoiceAlarm = VoiceAlarm(
                id = args["id"].toString(),
                title = args["title"] as? String ?: "",
                description = args["description"] as? String ?: "",
                hour = (args["hour"] as? Number)?.toInt() ?: 7,
                minute = (args["minute"] as? Number)?.toInt() ?: 0,
                days = (args["days"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() } ?: emptyList(),
                vibrate = args["vibrate"] as? Boolean ?: true,
                snoozeMinutes = (args["snoozeMinutes"] as? Number)?.toInt()?.coerceAtLeast(1) ?: 5,
            )
        }
    }

    // ---------------------------------------------------------------- Flutter-facing operations

    fun schedule(context: Context, args: Map<*, *>) {
        saveUserName(context, args["userName"] as? String)
        val alarm = VoiceAlarm.fromArgs(args)
        putAlarm(context, alarm)
        scheduleNext(context, alarm)
    }

    /** Removes the alarm entirely, including any pending snooze. */
    fun cancel(context: Context, id: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(firePendingIntent(context, id, snooze = false))
        alarmManager.cancel(firePendingIntent(context, id, snooze = true))
        removeAlarm(context, id)
    }

    fun snooze(context: Context, id: String, delaySeconds: Int) {
        setAlarm(context, System.currentTimeMillis() + delaySeconds * 1000L, firePendingIntent(context, id, snooze = true))
    }

    /** Rings a sample alarm right away (Alarms screen test button). */
    fun ringTest(context: Context, args: Map<*, *>) {
        saveUserName(context, args["userName"] as? String)
        putAlarm(context, VoiceAlarm.fromArgs(args).copy(id = TEST_ALARM_ID, days = emptyList()))
        val intent = Intent(context, AlarmVoiceService::class.java)
            .putExtra(EXTRA_ALARM_ID, TEST_ALARM_ID)
            .putExtra(EXTRA_IS_TEST, true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    /** One-time alarms dismissed natively since the last call, so Flutter can switch them off. */
    fun takeCompletedOneTime(context: Context): List<String> {
        val raw = prefs(context).getString(KEY_COMPLETED, "[]") ?: "[]"
        prefs(context).edit().putString(KEY_COMPLETED, "[]").apply()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { array.getString(it) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    // ---------------------------------------------------------------- Native lifecycle

    fun rescheduleAll(context: Context) {
        for (alarm in allAlarms(context)) {
            if (alarm.id != TEST_ALARM_ID) scheduleNext(context, alarm)
        }
    }

    /** Called when an alarm fires: arms the next weekly occurrence for repeating alarms. */
    fun onFired(context: Context, id: String, isSnooze: Boolean) {
        val alarm = getAlarm(context, id) ?: return
        if (!isSnooze && alarm.isRepeating) scheduleNext(context, alarm)
    }

    /** Dismissed (or timed out): one-time alarms are finished and reported back to Flutter. */
    fun complete(context: Context, id: String) {
        val alarm = getAlarm(context, id) ?: return
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(firePendingIntent(context, id, snooze = true))
        if (alarm.isRepeating) return

        alarmManager.cancel(firePendingIntent(context, id, snooze = false))
        removeAlarm(context, id)
        if (id == TEST_ALARM_ID) return

        val completed = try {
            JSONArray(prefs(context).getString(KEY_COMPLETED, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        completed.put(id)
        prefs(context).edit().putString(KEY_COMPLETED, completed.toString()).apply()
    }

    fun getAlarm(context: Context, id: String): VoiceAlarm? = try {
        JSONObject(prefs(context).getString(KEY_ALARMS, "{}") ?: "{}").optJSONObject(id)?.let { VoiceAlarm.fromJson(it) }
    } catch (_: Exception) {
        null
    }

    fun userName(context: Context): String = prefs(context).getString(KEY_USER_NAME, "").orEmpty()

    // ---------------------------------------------------------------- Internals

    private fun scheduleNext(context: Context, alarm: VoiceAlarm) {
        val next = nextTrigger(alarm) ?: return
        setAlarm(context, next, firePendingIntent(context, alarm.id, snooze = false))
    }

    private fun nextTrigger(alarm: VoiceAlarm): Long? {
        val now = System.currentTimeMillis()
        for (dayOffset in 0..7) {
            val candidate = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, dayOffset)
                set(Calendar.HOUR_OF_DAY, alarm.hour)
                set(Calendar.MINUTE, alarm.minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (candidate.timeInMillis <= now + 1000) continue
            if (!alarm.isRepeating) return candidate.timeInMillis

            val dow = candidate.get(Calendar.DAY_OF_WEEK)
            val isoDay = if (dow == Calendar.SUNDAY) 7 else dow - 1
            if (alarm.days.contains(isoDay)) return candidate.timeInMillis
        }
        return null
    }

    private fun setAlarm(context: Context, triggerAt: Long, pendingIntent: PendingIntent) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()
        if (canExact) {
            // setAlarmClock: highest reliability (exempt from Doze/battery savers), like the Clock app
            val showIntent = PendingIntent.getActivity(
                context, 3000, Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAt, showIntent), pendingIntent)
        } else {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    private fun firePendingIntent(context: Context, id: String, snooze: Boolean): PendingIntent {
        val intent = Intent(context, AlarmVoiceReceiver::class.java).apply {
            action = ACTION_FIRE
            // Distinct data URI per alarm (and per snooze) keeps each PendingIntent separate
            data = Uri.parse("maid-alarm://${if (snooze) "snooze" else "main"}/${Uri.encode(id)}")
            putExtra(EXTRA_ALARM_ID, id)
            putExtra(AlarmVoiceReceiver.EXTRA_IS_SNOOZE, snooze)
        }
        return PendingIntent.getBroadcast(
            context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun allAlarms(context: Context): List<VoiceAlarm> = try {
        val json = JSONObject(prefs(context).getString(KEY_ALARMS, "{}") ?: "{}")
        json.keys().asSequence().mapNotNull { json.optJSONObject(it)?.let(VoiceAlarm::fromJson) }.toList()
    } catch (_: Exception) {
        emptyList()
    }

    private fun putAlarm(context: Context, alarm: VoiceAlarm) {
        val json = try {
            JSONObject(prefs(context).getString(KEY_ALARMS, "{}") ?: "{}")
        } catch (_: Exception) {
            JSONObject()
        }
        json.put(alarm.id, alarm.toJson())
        prefs(context).edit().putString(KEY_ALARMS, json.toString()).apply()
    }

    private fun removeAlarm(context: Context, id: String) {
        val json = try {
            JSONObject(prefs(context).getString(KEY_ALARMS, "{}") ?: "{}")
        } catch (_: Exception) {
            return
        }
        json.remove(id)
        prefs(context).edit().putString(KEY_ALARMS, json.toString()).apply()
    }

    private fun saveUserName(context: Context, name: String?) {
        if (name != null) prefs(context).edit().putString(KEY_USER_NAME, name).apply()
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
