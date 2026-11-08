package com.maid.app.maid

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Rings a voice alarm like an incoming call: a female voice repeatedly says
 * "Likhith, wake up! You have Meet with Satish..." at full alarm volume, with vibration,
 * until the alarm is dismissed or snoozed (or [MAX_RING_MS] passes).
 */
class AlarmVoiceService : Service() {
    companion object {
        const val ACTION_DISMISS = "com.maid.app.maid.VOICE_ALARM_DISMISS"
        const val ACTION_SNOOZE = "com.maid.app.maid.VOICE_ALARM_SNOOZE"

        private const val CHANNEL_ID = "maid_voice_alarm"
        private const val RINGING_NOTIFICATION_ID = 9201
        private const val INFO_NOTIFICATION_ID = 9202
        private const val MAX_RING_MS = 10 * 60 * 1000L
        private const val PAUSE_BETWEEN_REPEATS_MS = 1200L

        // Known female voice ids: Google TTS ("en-us-x-sfg-local", "en-in-x-ahp-local"...) and Samsung ("...smtf00")
        private val FEMALE_VOICE_HINTS = listOf("female", "-x-sfg", "-x-tpf", "-x-tpc", "-x-iob", "-x-iog", "-x-ahp", "-x-cxx", "smtf")
        private val MALE_VOICE_HINTS = listOf("-x-iol", "-x-iom", "-x-tpd", "-x-end", "smtm")

        /** Currently ringing alarm id, read by [AlarmRingActivity]. */
        @Volatile var ringingAlarmId: String? = null
            private set
    }

    private val handler = Handler(Looper.getMainLooper())
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var fallbackPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var screenLock: PowerManager.WakeLock? = null
    private var focusRequest: AudioFocusRequest? = null
    private var originalAlarmVolume: Int? = null
    private var alarm: AlarmVoiceScheduler.VoiceAlarm? = null
    private var speech = ""

    private val alarmAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_DISMISS -> {
                alarm?.let { AlarmVoiceScheduler.complete(this, it.id) }
                stopRinging()
                return START_NOT_STICKY
            }
            ACTION_SNOOZE -> {
                alarm?.let { current ->
                    AlarmVoiceScheduler.snooze(this, current.id, current.snoozeMinutes * 60)
                    postInfo("😴 Snoozed: ${displayTitle(current)}", "Maid will call you again at ${formatTime(System.currentTimeMillis() + current.snoozeMinutes * 60_000L)}")
                }
                stopRinging()
                return START_NOT_STICKY
            }
        }

        val id = intent?.getStringExtra(AlarmVoiceScheduler.EXTRA_ALARM_ID)
        val next = id?.let { AlarmVoiceScheduler.getAlarm(this, it) }
        if (next == null) {
            if (alarm == null) stopSelf()
            return START_NOT_STICKY
        }

        // A second alarm while one is ringing: finish the first and switch to the new one
        alarm?.let { if (it.id != next.id) AlarmVoiceScheduler.complete(this, it.id) }
        alarm = next
        ringingAlarmId = next.id
        speech = buildSpeech(next)

        // Light the display first, like an incoming call: many phones otherwise launch the call
        // screen (or just the notification) while the display stays dark. The keyguard is still
        // showing, so the full-screen intent below still takes over the screen.
        wakeScreen()

        val notification = ringingNotification(next)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(RINGING_NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(RINGING_NOTIFICATION_ID, notification)
        }

        // The full-screen intent only takes over the screen when the phone is locked; while it's in
        // use Android shows a heads-up banner instead. "Display over other apps" lets us open the call screen directly.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)) {
            try {
                startActivity(Intent(this, AlarmRingActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            } catch (_: Exception) {}
        }

        startRinging(next)
        return START_NOT_STICKY
    }

    // ---------------------------------------------------------------- Ringing

    private fun startRinging(current: AlarmVoiceScheduler.VoiceAlarm) {
        handler.removeCallbacksAndMessages(null)
        acquireWakeLock()
        maximizeAlarmVolume()
        requestAudioFocus()
        if (current.vibrate) startVibration() else stopVibration()

        // Auto-stop so a forgotten alarm doesn't drain the battery; treated like a dismiss
        handler.postDelayed({
            alarm?.let {
                AlarmVoiceScheduler.complete(this, it.id)
                postInfo("⏰ Missed alarm: ${displayTitle(it)}", "Maid called for 10 minutes at ${formatTime(System.currentTimeMillis() - MAX_RING_MS)}")
            }
            stopRinging()
        }, MAX_RING_MS)

        if (ttsReady) {
            speakNow()
            return
        }
        tts?.shutdown()
        tts = TextToSpeech(this) { status ->
            val engine = tts
            if (status != TextToSpeech.SUCCESS || engine == null) {
                playFallbackRingtone()
                return@TextToSpeech
            }
            configureVoice(engine)
            engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(utteranceId: String?) {
                    handler.postDelayed({ speakNow() }, PAUSE_BETWEEN_REPEATS_MS)
                }
                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    handler.post { playFallbackRingtone() }
                }
            })
            ttsReady = true
            speakNow()
        }
    }

    private fun speakNow() {
        val engine = tts ?: return
        if (alarm == null || !ttsReady) return
        val params = android.os.Bundle().apply { putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f) }
        if (engine.speak(speech, TextToSpeech.QUEUE_FLUSH, params, "maid_alarm") != TextToSpeech.SUCCESS) {
            playFallbackRingtone()
        }
    }

    private fun configureVoice(engine: TextToSpeech) {
        engine.setAudioAttributes(alarmAttributes)
        val female = pickFemaleVoice(engine)
        if (female != null) {
            engine.voice = female
            engine.setPitch(1.05f)
        } else {
            // No identifiable female voice: raise the pitch of the default voice instead
            if (engine.setLanguage(Locale("en", "IN")) < TextToSpeech.LANG_AVAILABLE) {
                engine.setLanguage(Locale.US)
            }
            engine.setPitch(1.25f)
        }
        engine.setSpeechRate(0.92f)
    }

    private fun pickFemaleVoice(engine: TextToSpeech): Voice? {
        val voices = try {
            engine.voices
        } catch (_: Exception) {
            null
        } ?: return null

        fun score(voice: Voice): Int {
            val name = voice.name.lowercase(Locale.US)
            var score = 0
            if (FEMALE_VOICE_HINTS.any { name.contains(it) }) score += 100
            if (MALE_VOICE_HINTS.any { name.contains(it) } || (name.contains("male") && !name.contains("female"))) score -= 200
            when (voice.locale.country) {
                "IN" -> score += 20
                "US" -> score += 10
            }
            return score + voice.quality / 100
        }

        return voices
            .filter { voice ->
                voice.locale.language == "en" &&
                    !voice.isNetworkConnectionRequired &&
                    !voice.features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED)
            }
            .maxByOrNull(::score)
            ?.takeIf { score(it) >= 100 }
    }

    /** Used only if text-to-speech is unavailable, so the alarm still wakes you up. */
    private fun playFallbackRingtone() {
        if (fallbackPlayer != null || alarm == null) return
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            fallbackPlayer = MediaPlayer().apply {
                setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
                setDataSource(this@AlarmVoiceService, uri)
                isLooping = true
                prepare()
                start()
            }
        } catch (_: Exception) {}
    }

    private fun stopRinging() {
        handler.removeCallbacksAndMessages(null)
        ringingAlarmId = null
        alarm = null

        tts?.stop()
        tts?.shutdown()
        tts = null
        ttsReady = false

        fallbackPlayer?.let {
            try { it.stop() } catch (_: Exception) {}
            it.release()
        }
        fallbackPlayer = null

        stopVibration()
        abandonAudioFocus()
        restoreAlarmVolume()
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        screenLock?.let { if (it.isHeld) it.release() }
        screenLock = null

        AlarmRingActivity.closeIfOpen()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        if (alarm != null) stopRinging()
        super.onDestroy()
    }

    // ---------------------------------------------------------------- Speech text

    private fun buildSpeech(current: AlarmVoiceScheduler.VoiceAlarm): String {
        val name = AlarmVoiceScheduler.userName(this).trim()
        val title = current.title.trim()
        val isGeneric = title.isEmpty() || title.equals("Wake Up Alarm", true) ||
            title.equals("Alarm", true) || title.equals("Wake up", true)
        val now = formatTime(System.currentTimeMillis())

        val parts = mutableListOf<String>()
        parts.add(if (name.isEmpty()) "Wake up!" else "$name, wake up!")
        parts.add(if (isGeneric) "It's $now. Time to get up!" else "You have $title. It's $now.")

        val description = current.description.trim().trimEnd('.')
        if (description.isNotEmpty() &&
            !description.startsWith("Alarm for", ignoreCase = true) &&
            !description.equals(title, ignoreCase = true)
        ) {
            parts.add("$description.")
        }
        parts.add(if (name.isEmpty()) "Wake up now!" else "Wake up, $name!")
        return parts.joinToString(" ")
    }

    private fun displayTitle(current: AlarmVoiceScheduler.VoiceAlarm) =
        current.title.ifBlank { "Alarm" }

    private fun formatTime(millis: Long): String =
        SimpleDateFormat("h:mm a", Locale.US).format(Calendar.getInstance().apply { timeInMillis = millis }.time)

    // ---------------------------------------------------------------- Volume, vibration, wake

    private fun maximizeAlarmVolume() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (originalAlarmVolume == null) originalAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM), 0)
        } catch (_: Exception) {}
    }

    private fun restoreAlarmVolume() {
        val original = originalAlarmVolume ?: return
        try {
            (getSystemService(Context.AUDIO_SERVICE) as AudioManager).setStreamVolume(AudioManager.STREAM_ALARM, original, 0)
        } catch (_: Exception) {}
        originalAlarmVolume = null
    }

    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || focusRequest != null) return
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(alarmAttributes)
            .build()
        focusRequest = request
        (getSystemService(Context.AUDIO_SERVICE) as AudioManager).requestAudioFocus(request)
    }

    private fun abandonAudioFocus() {
        focusRequest?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                (getSystemService(Context.AUDIO_SERVICE) as AudioManager).abandonAudioFocusRequest(it)
            }
        }
        focusRequest = null
    }

    private fun vibrator(): Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }

    private fun startVibration() {
        val pattern = longArrayOf(0, 900, 700)
        try {
            val vib = vibrator() ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                @Suppress("DEPRECATION")
                vib.vibrate(VibrationEffect.createWaveform(pattern, 0), AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
            } else {
                @Suppress("DEPRECATION")
                vib.vibrate(pattern, 0)
            }
        } catch (_: Exception) {}
    }

    private fun stopVibration() {
        try { vibrator()?.cancel() } catch (_: Exception) {}
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Maid:VoiceAlarm")
            .apply { acquire(MAX_RING_MS + 60_000L) }
    }

    /** Turns the display on. Deprecated flags, but still the only way a service can wake the screen. */
    private fun wakeScreen() {
        if (screenLock?.isHeld == true) return
        try {
            @Suppress("DEPRECATION")
            screenLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP, "Maid:VoiceAlarmScreen")
                // The call screen keeps itself on (FLAG_KEEP_SCREEN_ON); this only has to cover the launch
                .apply { acquire(60_000L) }
        } catch (_: Exception) {}
    }

    // ---------------------------------------------------------------- Notifications

    private fun ringingNotification(current: AlarmVoiceScheduler.VoiceAlarm): Notification {
        ensureChannel()
        val name = AlarmVoiceScheduler.userName(this)
        val fullScreen = PendingIntent.getActivity(
            this, 3100,
            Intent(this, AlarmRingActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val dismiss = PendingIntent.getService(
            this, 3101, Intent(this, AlarmVoiceService::class.java).setAction(ACTION_DISMISS),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val snooze = PendingIntent.getService(
            this, 3102, Intent(this, AlarmVoiceService::class.java).setAction(ACTION_SNOOZE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return builder()
            .setContentTitle("📞 Maid is calling…")
            .setContentText(if (name.isBlank()) "Wake up! ${displayTitle(current)}" else "$name, wake up! ${displayTitle(current)}")
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setFullScreenIntent(fullScreen, true)
            .setContentIntent(fullScreen)
            .addAction(Notification.Action.Builder(null as android.graphics.drawable.Icon?, "😴 Snooze ${current.snoozeMinutes} min", snooze).build())
            .addAction(Notification.Action.Builder(null as android.graphics.drawable.Icon?, "✖ Dismiss", dismiss).build())
            .build()
    }

    private fun postInfo(title: String, text: String) {
        ensureChannel()
        val open = PendingIntent.getActivity(
            this, 3103, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = builder()
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(INFO_NOTIFICATION_ID, notification)
    }

    private fun builder(): Notification.Builder {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_MAX)
        }
        return builder.setSmallIcon(R.mipmap.ic_launcher).setShowWhen(true)
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Maid Voice Alarms", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Alarms where Maid calls you and speaks your alarm aloud"
                // The voice is the sound; vibration is handled by the service
                setSound(null, null)
                enableVibration(false)
                setBypassDnd(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        )
    }
}
