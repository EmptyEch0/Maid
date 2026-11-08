package com.maid.app.maid

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/** Receives voice alarm triggers, and boot/time-change events to re-arm all alarms. */
class AlarmVoiceReceiver : BroadcastReceiver() {
    companion object {
        const val EXTRA_IS_SNOOZE = "is_snooze"
        private const val TAG = "MaidVoiceAlarm"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AlarmVoiceScheduler.ACTION_FIRE) {
            AlarmVoiceScheduler.rescheduleAll(context)
            return
        }

        val id = intent.getStringExtra(AlarmVoiceScheduler.EXTRA_ALARM_ID) ?: return
        val isSnooze = intent.getBooleanExtra(EXTRA_IS_SNOOZE, false)
        AlarmVoiceScheduler.onFired(context, id, isSnooze)
        if (AlarmVoiceScheduler.getAlarm(context, id) == null) return

        val serviceIntent = Intent(context, AlarmVoiceService::class.java)
            .putExtra(AlarmVoiceScheduler.EXTRA_ALARM_ID, id)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Could not start voice alarm service", e)
        }
    }
}
