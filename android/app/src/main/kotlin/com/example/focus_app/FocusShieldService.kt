package com.example.focus_app

import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class FocusShieldService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var blockedApps: List<Pair<String, String>> = emptyList()
    private var subject: String = "General"
    private var endAtMillis: Long = 0L
    private var lastDetectedPackage: String = ""

    private val tick = object : Runnable {
        override fun run() {
            val remainingMs = endAtMillis - System.currentTimeMillis()
            if (remainingMs <= 0) {
                saveStatus(active = false, remainingSeconds = 0)
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return
            }

            val currentPackage = currentForegroundPackage()
            if (currentPackage.isNotBlank() && currentPackage != packageName) {
                val match = blockedApps.firstOrNull { it.first == currentPackage }
                if (match != null && currentPackage != lastDetectedPackage) {
                    lastDetectedPackage = currentPackage
                    val previousHits = prefs().getInt(KEY_BLOCKED_ATTEMPTS, 0)
                    saveStatus(
                        active = true,
                        blockedAttempts = previousHits + 1,
                        lastBlockedApp = match.second,
                        remainingSeconds = (remainingMs / 1000L).toInt(),
                    )
                    showWarningNotification(match.second, (remainingMs / 1000L).toInt())
                }
            } else if (currentPackage.isBlank() || blockedApps.none { it.first == currentPackage }) {
                lastDetectedPackage = ""
            }

            updateOngoingNotification((remainingMs / 1000L).toInt())
            handler.postDelayed(this, 1500L)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        blockedApps = parseBlockedApps(intent)
        subject = intent?.getStringExtra(EXTRA_SUBJECT)?.takeIf { it.isNotBlank() } ?: "General"
        val durationSeconds = intent?.getIntExtra(EXTRA_DURATION_SECONDS, 0) ?: 0
        endAtMillis = System.currentTimeMillis() + durationSeconds * 1000L

        createNotificationChannels()
        startForeground(NOTIFICATION_ID, buildOngoingNotification(durationSeconds))
        saveStatus(active = true, blockedAttempts = 0, lastBlockedApp = "", remainingSeconds = durationSeconds)

        handler.removeCallbacksAndMessages(null)
        handler.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        saveStatus(active = false, remainingSeconds = 0)
        super.onDestroy()
    }

    private fun parseBlockedApps(intent: Intent?): List<Pair<String, String>> {
        val raw = intent?.getStringArrayListExtra(EXTRA_BLOCKED_APPS) ?: arrayListOf()
        return raw.mapNotNull { value ->
            val parts = value.split("::", limit = 2)
            if (parts.isEmpty()) null else Pair(parts[0], parts.getOrElse(1) { parts[0] })
        }
    }

    private fun buildOngoingNotification(remainingSeconds: Int): Notification {
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_SESSION)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Modo Enfoque Total activo")
            .setContentText("${formatTime(remainingSeconds)} restantes · $subject")
            .setSubText("Focus vigila apps distractoras")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateOngoingNotification(remainingSeconds: Int) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildOngoingNotification(remainingSeconds))
        saveStatus(
            active = true,
            blockedAttempts = prefs().getInt(KEY_BLOCKED_ATTEMPTS, 0),
            lastBlockedApp = prefs().getString(KEY_LAST_BLOCKED_APP, "") ?: "",
            remainingSeconds = remainingSeconds,
        )
    }

    private fun showWarningNotification(appLabel: String, remainingSeconds: Int) {
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            1,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_WARNING)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Vuelve al enfoque")
            .setContentText("$appLabel está bloqueada durante esta sesión.")
            .setSubText("${formatTime(remainingSeconds)} restantes · $subject")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(WARNING_NOTIFICATION_ID, notification)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val sessionChannel = NotificationChannel(
            CHANNEL_SESSION,
            "Modo Enfoque Total",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Mantiene visible la sesión de enfoque total."
        }
        val warningChannel = NotificationChannel(
            CHANNEL_WARNING,
            "Alertas de enfoque total",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Avisa cuando abres una app distractora en medio del foco."
        }
        manager.createNotificationChannel(sessionChannel)
        manager.createNotificationChannel(warningChannel)
    }

    private fun currentForegroundPackage(): String {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = end - 15_000L
        val events = usageStatsManager.queryEvents(start, end)
        val event = UsageEvents.Event()
        var latestPackage = ""
        var latestTime = 0L

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND &&
                event.timeStamp >= latestTime
            ) {
                latestTime = event.timeStamp
                latestPackage = event.packageName ?: ""
            }
        }
        return latestPackage
    }

    private fun saveStatus(
        active: Boolean,
        blockedAttempts: Int = prefs().getInt(KEY_BLOCKED_ATTEMPTS, 0),
        lastBlockedApp: String = prefs().getString(KEY_LAST_BLOCKED_APP, "") ?: "",
        remainingSeconds: Int,
    ) {
        prefs()
            .edit()
            .putBoolean(KEY_ACTIVE, active)
            .putInt(KEY_BLOCKED_ATTEMPTS, blockedAttempts)
            .putString(KEY_LAST_BLOCKED_APP, lastBlockedApp)
            .putInt(KEY_REMAINING_SECONDS, remainingSeconds)
            .apply()
    }

    private fun prefs() =
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun formatTime(totalSeconds: Int): String {
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return String.format("%02d:%02d", minutes, seconds)
    }

    companion object {
        const val PREFS_NAME = "focus_mode_total_prefs"
        const val KEY_ACTIVE = "active"
        const val KEY_BLOCKED_ATTEMPTS = "blocked_attempts"
        const val KEY_LAST_BLOCKED_APP = "last_blocked_app"
        const val KEY_REMAINING_SECONDS = "remaining_seconds"

        const val EXTRA_SUBJECT = "subject"
        const val EXTRA_DURATION_SECONDS = "duration_seconds"
        const val EXTRA_BLOCKED_APPS = "blocked_apps"

        private const val CHANNEL_SESSION = "focus_mode_total_session"
        private const val CHANNEL_WARNING = "focus_mode_total_warning"
        private const val NOTIFICATION_ID = 42420
        private const val WARNING_NOTIFICATION_ID = 42421
    }
}
