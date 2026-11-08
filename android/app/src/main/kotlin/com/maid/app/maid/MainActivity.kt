package com.maid.app.maid

import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.maid.app/briefing")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        BriefingScheduler.configure(applicationContext, call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                        result.success(null)
                    }
                    "test" -> {
                        val kind = call.argument<String>("kind") ?: BriefingScheduler.KIND_MORNING
                        val delaySeconds = call.argument<Int>("delaySeconds") ?: 60
                        BriefingScheduler.scheduleTest(applicationContext, kind, delaySeconds)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.maid.app/alarm")
            .setMethodCallHandler { call, result ->
                val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                when (call.method) {
                    "schedule" -> {
                        AlarmVoiceScheduler.schedule(applicationContext, args)
                        result.success(null)
                    }
                    "cancel" -> {
                        AlarmVoiceScheduler.cancel(applicationContext, args["id"].toString())
                        result.success(null)
                    }
                    "snooze" -> {
                        val delaySeconds = (args["delaySeconds"] as? Number)?.toInt() ?: 300
                        AlarmVoiceScheduler.snooze(applicationContext, args["id"].toString(), delaySeconds)
                        result.success(null)
                    }
                    "ringTest" -> {
                        AlarmVoiceScheduler.ringTest(applicationContext, args)
                        result.success(null)
                    }
                    "takeCompletedOneTime" -> result.success(AlarmVoiceScheduler.takeCompletedOneTime(applicationContext))
                    "ensureFullScreenIntent" -> result.success(ensureFullScreenIntentAllowed())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Android 14+ may deny full-screen intents by default; without it the "Maid is calling"
     * screen can't appear over the lock screen (the voice still plays). Opens the setting once.
     */
    private fun ensureFullScreenIntentAllowed(): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.canUseFullScreenIntent()) return true
        try {
            startActivity(
                Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName"))
            )
        } catch (_: Exception) {}
        return false
    }
}
