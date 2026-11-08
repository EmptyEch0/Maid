package com.maid.app.maid

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.airbnb.lottie.LottieAnimationView
import com.airbnb.lottie.LottieDrawable
import java.lang.ref.WeakReference
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Full-screen "Maid is calling" screen shown over the lock screen while a voice alarm rings. */
class AlarmRingActivity : Activity() {
    companion object {
        private var current: WeakReference<AlarmRingActivity>? = null

        fun closeIfOpen() {
            current?.get()?.let { if (!it.isFinishing) it.finish() }
            current = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        current = WeakReference(this)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val alarmId = AlarmVoiceService.ringingAlarmId
        val alarm = alarmId?.let { AlarmVoiceScheduler.getAlarm(this, it) }
        if (alarm == null) {
            finish()
            return
        }
        setContentView(buildLayout(alarm))
    }

    // singleInstance: a second alarm while this screen is open reuses it, so rebuild for the new alarm
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        recreate()
    }

    override fun onResume() {
        super.onResume()
        // Alarm already handled from the notification
        if (AlarmVoiceService.ringingAlarmId == null) finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Like an incoming call: you must choose Snooze or Dismiss
    }

    override fun onDestroy() {
        if (current?.get() === this) current = null
        super.onDestroy()
    }

    private fun send(action: String) {
        startService(Intent(this, AlarmVoiceService::class.java).setAction(action))
        finish()
    }

    private fun buildLayout(alarm: AlarmVoiceScheduler.VoiceAlarm): View {
        val name = AlarmVoiceScheduler.userName(this)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(72), dp(24), dp(56))
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.parseColor("#0B0F19"), Color.parseColor("#312E81"), Color.parseColor("#4F46E5"))
            )
        }

        root.addView(text("📞  Maid is calling…", 16f, "#C7D2FE"))

        // Caller "avatar": the panda
        root.addView(lottie("panda_call.json"), LinearLayout.LayoutParams(dp(200), dp(200)).apply { topMargin = dp(16); bottomMargin = dp(12) })

        root.addView(text(if (name.isBlank()) "Wake up!" else "$name, wake up!", 30f, "#FFFFFF", bold = true))
        root.addView(text(alarm.title.ifBlank { "Alarm" }, 21f, "#E0E7FF").apply { setPadding(0, dp(10), 0, 0) })
        if (alarm.description.isNotBlank() && !alarm.description.startsWith("Alarm for", ignoreCase = true)) {
            root.addView(text(alarm.description, 15f, "#A5B4FC").apply { setPadding(0, dp(6), 0, 0) })
        }
        root.addView(text(SimpleDateFormat("h:mm a", Locale.US).format(Date()), 54f, "#FFFFFF").apply {
            typeface = Typeface.create("sans-serif-light", Typeface.NORMAL)
            setPadding(0, dp(24), 0, 0)
        })

        // Fills the space above the buttons (pushing them to the bottom, like a call screen)
        root.addView(lottie("panda_noodles.json"), LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))

        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        buttons.addView(roundButton("😴", "Snooze ${alarm.snoozeMinutes}m", "#F59E0B") { send(AlarmVoiceService.ACTION_SNOOZE) })
        buttons.addView(View(this), LinearLayout.LayoutParams(dp(64), 1))
        buttons.addView(roundButton("✖", "Dismiss", "#EF4444") { send(AlarmVoiceService.ACTION_DISMISS) })
        root.addView(buttons)

        return root
    }

    private fun roundButton(icon: String, label: String, color: String, onClick: () -> Unit): View {
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        column.addView(TextView(this).apply {
            text = icon
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 30f)
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor(color))
            }
            layoutParams = LinearLayout.LayoutParams(dp(84), dp(84))
            setOnClickListener { onClick() }
        })
        column.addView(text(label, 14f, "#FFFFFF", bold = true).apply { setPadding(0, dp(10), 0, 0) })
        return column
    }

    private fun lottie(asset: String) = LottieAnimationView(this).apply {
        setAnimation(asset)
        repeatCount = LottieDrawable.INFINITE
        scaleType = ImageView.ScaleType.FIT_CENTER
        playAnimation()
    }

    private fun text(value: String, sizeSp: Float, color: String, bold: Boolean = false) = TextView(this).apply {
        text = value
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        setTextColor(Color.parseColor(color))
        gravity = Gravity.CENTER
        if (bold) setTypeface(typeface, Typeface.BOLD)
    }

    private fun dp(value: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics
    ).toInt()
}
