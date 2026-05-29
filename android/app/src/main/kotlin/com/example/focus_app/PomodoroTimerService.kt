package com.example.focus_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class PomodoroTimerService : Service() {
    private var mode: String = "focus"
    private var subject: String = "General"
    private var totalSeconds: Int = 0
    private var endAtMillis: Long = 0L
    private var timerExecutor: ScheduledExecutorService? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        mode = intent?.getStringExtra(EXTRA_MODE) ?: "focus"
        subject = intent?.getStringExtra(EXTRA_SUBJECT)?.takeIf { it.isNotBlank() } ?: "General"
        totalSeconds = intent?.getIntExtra(EXTRA_TOTAL_SECONDS, 0) ?: 0
        val remainingSeconds = intent?.getIntExtra(EXTRA_REMAINING_SECONDS, 0) ?: 0

        if (totalSeconds <= 0 || remainingSeconds <= 0) {
            stopSelf()
            return START_NOT_STICKY
        }

        endAtMillis = System.currentTimeMillis() + remainingSeconds * 1000L
        createNotificationChannel()
        startPomodoroForeground(remainingSeconds)
        startTimer()
        return START_STICKY
    }

    override fun onDestroy() {
        timerExecutor?.shutdownNow()
        timerExecutor = null
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
            stopSelf()
            return
        }
        val remainingSeconds = (remainingMs / 1000L).toInt().coerceAtLeast(0)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(remainingSeconds))
    }

    private fun startPomodoroForeground(remainingSeconds: Int) {
        val notification = buildNotification(remainingSeconds)
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

    private fun buildNotification(remainingSeconds: Int): Notification {
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val modeLabel = when (mode) {
            "longBreak" -> "Descanso largo"
            "shortBreak" -> "Descanso corto"
            else -> "Enfoque"
        }
        val body = if (mode == "focus") {
            "Materia: $subject"
        } else {
            when (mode) {
                "longBreak" -> "Descanso largo activo"
                else -> "Descanso corto activo"
            }
        }
        val progress = if (totalSeconds <= 0) {
            0
        } else {
            (((totalSeconds - remainingSeconds).toDouble() / totalSeconds) * 100)
                .toInt()
                .coerceIn(0, 100)
        }
        val timeLeft = formatTime(remainingSeconds)
        val accentColor = when (mode) {
            "longBreak" -> 0xFFF59E0B.toInt()
            "shortBreak" -> 0xFF10B981.toInt()
            else -> 0xFF2563EB.toInt()
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_focus)
            .setLargeIcon(BitmapFactory.decodeResource(resources, R.drawable.focus_app_icon))
            .setContentTitle("Focus · $timeLeft")
            .setContentText("$modeLabel · $body")
            .setStyle(NotificationCompat.BigTextStyle().bigText("$modeLabel · $body"))
            .setSubText(modeLabel)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setShowWhen(false)
            .setLocalOnly(true)
            .setColor(accentColor)
            .setProgress(100, progress, false)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Temporizador Pomodoro",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Mantiene visible el contador activo del Pomodoro."
            setShowBadge(false)
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun formatTime(totalSeconds: Int): String {
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return String.format("%02d:%02d", minutes, seconds)
    }

    companion object {
        const val EXTRA_MODE = "mode"
        const val EXTRA_SUBJECT = "subject"
        const val EXTRA_REMAINING_SECONDS = "remaining_seconds"
        const val EXTRA_TOTAL_SECONDS = "total_seconds"
        private const val CHANNEL_ID = "focus_pomodoro_timer"
        private const val NOTIFICATION_ID = 880001
    }
}
