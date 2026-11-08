package com.maid.app.maid

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build

/** Notifications for the voice briefings, using framework APIs only. */
object BriefingNotifications {
    const val SPEAKING_ID = 9101
    private const val DONE_ID_MORNING = 9102
    private const val DONE_ID_EVENING = 9103

    // Voice channel is silent: the spoken briefing is the sound
    private const val CHANNEL_VOICE = "maid_briefing_voice"
    private const val CHANNEL_SOUND = "maid_briefing_sound"

    fun speaking(context: Context, kind: String, text: String): Notification {
        ensureChannels(context)
        val stopIntent = Intent(context, BriefingSpeechService::class.java).setAction(BriefingSpeechService.ACTION_STOP)
        val stopPending = PendingIntent.getService(
            context, 2200, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return builder(context, CHANNEL_VOICE)
            .setContentTitle(BriefingScheduler.titleFor(context, kind))
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(openAppIntent(context))
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null as android.graphics.drawable.Icon?, "Stop speaking", stopPending).build())
            .build()
    }

    /** Leaves the briefing text in the shade after speaking (or instead of it). */
    fun postDone(context: Context, kind: String, text: String, withSound: Boolean) {
        ensureChannels(context)
        val notification = builder(context, if (withSound) CHANNEL_SOUND else CHANNEL_VOICE)
            .setContentTitle(BriefingScheduler.titleFor(context, kind))
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(openAppIntent(context))
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .build()
        val id = if (kind == BriefingScheduler.KIND_MORNING) DONE_ID_MORNING else DONE_ID_EVENING
        manager(context).notify(id, notification)
    }

    private fun builder(context: Context, channel: String): Notification.Builder {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channel)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
        }
        return builder.setSmallIcon(R.mipmap.ic_launcher).setShowWhen(true)
    }

    private fun openAppIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, 2300, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = manager(context)
        if (manager.getNotificationChannel(CHANNEL_VOICE) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_VOICE, "Maid Voice Briefings", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Morning and evening briefings read aloud by Maid"
                    setSound(null, null)
                    enableVibration(false)
                }
            )
        }
        if (manager.getNotificationChannel(CHANNEL_SOUND) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_SOUND, "Maid Briefings (no voice)", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Morning and evening briefings when voice read-out is turned off"
                    setSound(
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build()
                    )
                }
            )
        }
    }

    private fun manager(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
