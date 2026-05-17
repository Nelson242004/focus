package com.example.focus_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class FocusShieldService : Service() {
    private val tag = "FocusShieldService"
    private var blockedAppsRaw: String = ""
    private var blockedApps: Map<String, String> = emptyMap()
    private var subject: String = "General"
    private var totalDurationSeconds: Int = 0
    private var endAtMillis: Long = 0L
    private var timerExecutor: ScheduledExecutorService? = null
    private var overlayManager: FocusOverlayManager? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        overlayManager = FocusOverlayManager(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        debugLog("onStartCommand called")
        blockedApps = parseBlockedApps(intent).toMap()
        blockedAppsRaw = blockedApps.entries.joinToString("||") { "${it.key}::${it.value}" }
        subject = intent?.getStringExtra(EXTRA_SUBJECT)?.takeIf { it.isNotBlank() } ?: "General"
        totalDurationSeconds = intent?.getIntExtra(EXTRA_DURATION_SECONDS, 0) ?: 0
        debugLog("session payload duration=$totalDurationSeconds blockedCount=${blockedApps.size}")

        if (blockedAppsRaw.isBlank() || totalDurationSeconds <= 0) {
            warnLog("Invalid session payload; stopping service")
            stopSelf()
            return START_NOT_STICKY
        }

        endAtMillis = System.currentTimeMillis() + totalDurationSeconds * 1000L
        createNotificationChannels()
        persistSessionState(
            active = true,
            remainingSeconds = totalDurationSeconds,
            resetCounters = true,
        )
        startFocusForeground(totalDurationSeconds)
        startTimer()
        debugLog("Foreground service started successfully")
        return START_STICKY
    }

    override fun onDestroy() {
        debugLog("onDestroy called")
        timerExecutor?.shutdownNow()
        timerExecutor = null
        overlayManager?.dismissOverlay(immediate = true)
        persistSessionState(active = false, remainingSeconds = 0, keepCounters = true)
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun startTimer() {
        timerExecutor?.shutdownNow()
        timerExecutor = Executors.newSingleThreadScheduledExecutor()
        timerExecutor?.scheduleWithFixedDelay(
            { runCatching { onTick() }.onFailure { stopSelf() } },
            0L,
            1L,
            TimeUnit.SECONDS,
        )
    }

    private fun onTick() {
        val remainingMs = endAtMillis - System.currentTimeMillis()
        if (remainingMs <= 0L) {
            debugLog("Session finished; stopping service")
            persistSessionState(active = false, remainingSeconds = 0, keepCounters = true)
            stopSelf()
            return
        }

        val remainingSeconds = (remainingMs / 1000L).toInt().coerceAtLeast(0)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildOngoingNotification(remainingSeconds))
        persistSessionState(active = true, remainingSeconds = remainingSeconds, keepCounters = true)
    }

    private fun persistSessionState(
        active: Boolean,
        remainingSeconds: Int,
        resetCounters: Boolean = false,
        keepCounters: Boolean = false,
    ) {
        debugLog("persistSessionState active=$active remaining=$remainingSeconds reset=$resetCounters keep=$keepCounters")
        val prefs = prefs()
        val editor = prefs.edit()
            .putBoolean(KEY_ACTIVE, active)
            .putInt(KEY_REMAINING_SECONDS, remainingSeconds)
            .putString(KEY_BLOCKED_APPS_RAW, blockedAppsRaw)
            .putString(KEY_SUBJECT, subject)

        if (resetCounters) {
            editor
                .putInt(KEY_BLOCKED_ATTEMPTS, 0)
                .putString(KEY_LAST_BLOCKED_APP, "")
                .putString(KEY_LAST_BLOCKED_PACKAGE, "")
                .putLong(KEY_LAST_BLOCKED_AT_MILLIS, 0L)
        } else if (!keepCounters) {
            editor
                .putInt(KEY_BLOCKED_ATTEMPTS, prefs.getInt(KEY_BLOCKED_ATTEMPTS, 0))
                .putString(KEY_LAST_BLOCKED_APP, prefs.getString(KEY_LAST_BLOCKED_APP, "") ?: "")
                .putString(KEY_LAST_BLOCKED_PACKAGE, prefs.getString(KEY_LAST_BLOCKED_PACKAGE, "") ?: "")
                .putLong(KEY_LAST_BLOCKED_AT_MILLIS, prefs.getLong(KEY_LAST_BLOCKED_AT_MILLIS, 0L))
        }

        editor.apply()
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
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Enfoque · ${formatTime(remainingSeconds)}")
            .setContentText(subject)
            .setStyle(NotificationCompat.BigTextStyle().bigText(subject))
            .setSubText(subject)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setShowWhen(false)
            .setProgress(100, progressFor(remainingSeconds), false)
            .build()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val sessionChannel = NotificationChannel(
            CHANNEL_SESSION,
            "Modo Enfoque Total",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Mantiene visible la sesión activa de enfoque."
            setShowBadge(false)
        }
        manager.createNotificationChannel(sessionChannel)
    }

    private fun startFocusForeground(remainingSeconds: Int) {
        val notification = buildOngoingNotification(remainingSeconds)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun prefs() = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun formatTime(totalSeconds: Int): String {
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return String.format("%02d:%02d", minutes, seconds)
    }

    private fun progressFor(remainingSeconds: Int): Int {
        if (totalDurationSeconds <= 0) return 0
        return (((totalDurationSeconds - remainingSeconds).toDouble() / totalDurationSeconds) * 100)
            .toInt()
            .coerceIn(0, 100)
    }

    private fun debugLog(message: String) {
        if (BuildConfig.DEBUG) Log.d(tag, message)
    }

    private fun warnLog(message: String) {
        if (BuildConfig.DEBUG) Log.w(tag, message)
    }

    companion object {
        const val PREFS_NAME = "focus_mode_total_prefs"
        const val KEY_ACTIVE = "active"
        const val KEY_BLOCKED_ATTEMPTS = "blocked_attempts"
        const val KEY_LAST_BLOCKED_APP = "last_blocked_app"
        const val KEY_LAST_BLOCKED_PACKAGE = "last_blocked_package"
        const val KEY_REMAINING_SECONDS = "remaining_seconds"
        const val KEY_LAST_BLOCKED_AT_MILLIS = "last_blocked_at_millis"
        const val KEY_BLOCKED_APPS_RAW = "blocked_apps_raw"
        const val KEY_SUBJECT = "subject"

        const val EXTRA_SUBJECT = "subject"
        const val EXTRA_DURATION_SECONDS = "duration_seconds"
        const val EXTRA_BLOCKED_APPS = "blocked_apps"

        private const val CHANNEL_SESSION = "focus_mode_total_session"
        private const val NOTIFICATION_ID = 42420
    }
}
