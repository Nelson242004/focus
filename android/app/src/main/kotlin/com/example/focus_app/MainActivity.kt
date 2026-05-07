package com.example.focus_app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "focus_mode_total"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> result.success(getInstalledApps())
                    "hasUsageAccessPermission" -> result.success(hasUsageAccessPermission())
                    "openUsageAccessSettings" -> {
                        openUsageAccessSettings()
                        result.success(null)
                    }
                    "startFocusSession" -> {
                        startFocusSession(
                            subject = call.argument<String>("subject") ?: "General",
                            durationSeconds = call.argument<Int>("durationSeconds") ?: 0,
                            blockedApps = call.argument<List<Map<String, Any?>>>("blockedApps") ?: emptyList(),
                        )
                        result.success(null)
                    }
                    "stopFocusSession" -> {
                        stopService(Intent(this, FocusShieldService::class.java))
                        result.success(null)
                    }
                    "getFocusSessionStatus" -> result.success(getFocusSessionStatus())
                    else -> result.notImplemented()
                }
            }
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val launcherIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val apps = packageManager.queryIntentActivities(launcherIntent, PackageManager.MATCH_ALL)
        val ownPackage = packageName
        return apps
            .mapNotNull { resolveInfo ->
                val packageName = resolveInfo.activityInfo?.packageName ?: return@mapNotNull null
                if (packageName == ownPackage) return@mapNotNull null
                mapOf(
                    "packageName" to packageName,
                    "label" to resolveInfo.loadLabel(packageManager).toString(),
                )
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["label"]?.lowercase() ?: "" }
    }

    private fun hasUsageAccessPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        startActivity(
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
    }

    private fun startFocusSession(
        subject: String,
        durationSeconds: Int,
        blockedApps: List<Map<String, Any?>>,
    ) {
        val serializedApps = ArrayList<String>()
        blockedApps.forEach { app ->
            val packageName = app["packageName"]?.toString()?.trim().orEmpty()
            if (packageName.isBlank()) return@forEach
            val label = app["label"]?.toString()?.trim().takeUnless { it.isNullOrBlank() } ?: packageName
            serializedApps.add("$packageName::$label")
        }

        val intent = Intent(this, FocusShieldService::class.java).apply {
            putExtra(FocusShieldService.EXTRA_SUBJECT, subject)
            putExtra(FocusShieldService.EXTRA_DURATION_SECONDS, durationSeconds)
            putStringArrayListExtra(FocusShieldService.EXTRA_BLOCKED_APPS, serializedApps)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun getFocusSessionStatus(): Map<String, Any> {
        val prefs = getSharedPreferences(FocusShieldService.PREFS_NAME, Context.MODE_PRIVATE)
        return mapOf(
            "active" to prefs.getBoolean(FocusShieldService.KEY_ACTIVE, false),
            "blockedAttempts" to prefs.getInt(FocusShieldService.KEY_BLOCKED_ATTEMPTS, 0),
            "lastBlockedApp" to (prefs.getString(FocusShieldService.KEY_LAST_BLOCKED_APP, "") ?: ""),
            "remainingSeconds" to prefs.getInt(FocusShieldService.KEY_REMAINING_SECONDS, 0),
        )
    }
}
