package com.maid.app.maid

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/** Receives the briefing alarm (and boot/time-change events, to re-arm the alarms). */
class BriefingAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val EXTRA_IS_TEST = "is_test"
        private const val TAG = "MaidBriefing"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != BriefingScheduler.ACTION_FIRE) {
            // BOOT_COMPLETED, MY_PACKAGE_REPLACED, TIME_SET, TIMEZONE_CHANGED...
            BriefingScheduler.scheduleAll(context)
            return
        }

        val kind = intent.getStringExtra(BriefingScheduler.EXTRA_KIND) ?: BriefingScheduler.KIND_MORNING
        val isTest = intent.getBooleanExtra(EXTRA_IS_TEST, false)

        if (!isTest) {
            // Arm tomorrow's occurrence first so one failure never breaks the daily chain
            BriefingScheduler.scheduleNext(context, kind)
            if (!BriefingScheduler.isEnabled(context)) return
        }

        if (!BriefingScheduler.shouldSpeak(context)) {
            BriefingNotifications.postDone(context, kind, BriefingScheduler.textFor(context, kind), withSound = true)
            return
        }

        val serviceIntent = Intent(context, BriefingSpeechService::class.java)
            .putExtra(BriefingScheduler.EXTRA_KIND, kind)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            // Background start blocked (e.g. OEM restrictions): at least show the briefing
            Log.e(TAG, "Could not start briefing voice service", e)
            BriefingNotifications.postDone(context, kind, BriefingScheduler.textFor(context, kind), withSound = true)
        }
    }
}
