package com.maid.app.maid

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale

/** Short-lived foreground service that reads the briefing aloud, then stops itself. */
class BriefingSpeechService : Service() {
    companion object {
        const val ACTION_STOP = "com.maid.app.maid.BRIEFING_STOP"
        private const val UTTERANCE_ID = "maid_briefing"
        private const val MAX_SPEAK_MS = 3 * 60 * 1000L
    }

    private var tts: TextToSpeech? = null
    private var focusRequest: AudioFocusRequest? = null
    private val handler = Handler(Looper.getMainLooper())
    private var kind = BriefingScheduler.KIND_MORNING
    private var text = ""
    private var finished = false

    private val speechAttributes = AudioAttributes.Builder()
        // Alarm stream so the briefing is heard even when media volume is down
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            finish()
            return START_NOT_STICKY
        }

        kind = intent?.getStringExtra(BriefingScheduler.EXTRA_KIND) ?: BriefingScheduler.KIND_MORNING
        text = BriefingScheduler.textFor(this, kind)

        val notification = BriefingNotifications.speaking(this, kind, text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(BriefingNotifications.SPEAKING_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(BriefingNotifications.SPEAKING_ID, notification)
        }

        handler.postDelayed({ finish() }, MAX_SPEAK_MS)
        startSpeaking()
        return START_NOT_STICKY
    }

    private fun startSpeaking() {
        tts = TextToSpeech(this) { status ->
            val engine = tts
            if (status != TextToSpeech.SUCCESS || engine == null) {
                finish()
                return@TextToSpeech
            }

            // Same voice the in-app assistant uses
            if (engine.setLanguage(Locale.US) < TextToSpeech.LANG_AVAILABLE) {
                engine.setLanguage(Locale.getDefault())
            }
            engine.setAudioAttributes(speechAttributes)
            engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {}
                override fun onDone(utteranceId: String?) { handler.post { finish() } }
                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) { handler.post { finish() } }
            })

            requestAudioFocus()
            engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, UTTERANCE_ID)
        }
    }

    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            .setAudioAttributes(speechAttributes)
            .build()
        focusRequest = request
        audioManager.requestAudioFocus(request)
    }

    private fun finish() {
        if (finished) return
        finished = true
        handler.removeCallbacksAndMessages(null)

        tts?.stop()
        tts?.shutdown()
        tts = null

        focusRequest?.let {
            (getSystemService(Context.AUDIO_SERVICE) as AudioManager).abandonAudioFocusRequest(it)
        }

        stopForeground(STOP_FOREGROUND_REMOVE)
        if (text.isNotBlank()) {
            BriefingNotifications.postDone(this, kind, text, withSound = false)
        }
        stopSelf()
    }

    override fun onDestroy() {
        if (!finished) finish()
        super.onDestroy()
    }
}
