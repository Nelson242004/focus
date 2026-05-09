package com.example.focus_app

import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Base64
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val channelName = "focus_mode_total"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> {
                        thread(name = "focus-app-loader") {
                            val apps = runCatching { getInstalledApps() }.getOrDefault(emptyList())
                            runOnUiThread { result.success(apps) }
                        }
                    }

                    "getAppIcon" -> {
                        val targetPackage = call.argument<String>("packageName").orEmpty()
                        thread(name = "focus-app-icon-loader") {
                            val icon = runCatching { getAppIcon(targetPackage) }.getOrDefault("")
                            runOnUiThread { result.success(icon) }
                        }
                    }

                    "hasUsageAccessPermission" -> result.success(hasUsageAccessPermission())
                    "openUsageAccessSettings" -> {
                        openUsageAccessSettings()
                        result.success(null)
                    }

                    "hasAccessibilityPermission" -> result.success(hasAccessibilityPermission())
                    "openAccessibilitySettings" -> {
                        openAccessibilitySettings()
                        result.success(null)
                    }

                    "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
                    "openOverlaySettings" -> {
                        openOverlaySettings()
                        result.success(null)
                    }

                    "hasIgnoreBatteryOptimizationPermission" ->
                        result.success(hasIgnoreBatteryOptimizationPermission())

                    "openIgnoreBatteryOptimizationSettings" -> {
                        openIgnoreBatteryOptimizationSettings()
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
        val ownPackage = packageName
        val launchableApps = linkedMapOf<String, Map<String, String>>()

        queryLauncherActivities().forEach { resolveInfo ->
            val resolvedPackage = resolveInfo.activityInfo?.packageName ?: return@forEach
            if (resolvedPackage == ownPackage) return@forEach
            buildAppMap(resolveInfo, resolvedPackage)?.let { app ->
                launchableApps[resolvedPackage] = app
            }
        }

        queryLaunchableInstalledApps().forEach { appInfo ->
            val resolvedPackage = appInfo.packageName
            if (resolvedPackage == ownPackage) return@forEach
            if (launchableApps.containsKey(resolvedPackage)) return@forEach
            buildAppMap(appInfo)?.let { app ->
                launchableApps[resolvedPackage] = app
            }
        }

        return launchableApps
            .values
            .distinctBy { it["packageName"] }
            .sortedBy { it["label"]?.lowercase() ?: "" }
    }

    private fun queryLauncherActivities(): List<ResolveInfo> {
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                launcherIntent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_ALL.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(launcherIntent, PackageManager.MATCH_ALL)
        }
    }

    private fun queryLaunchableInstalledApps(): List<ApplicationInfo> {
        val installedApps =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getInstalledApplications(
                    PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
            }

        return installedApps.filter { appInfo ->
            packageManager.getLaunchIntentForPackage(appInfo.packageName) != null
        }
    }

    private fun buildAppMap(
        resolveInfo: ResolveInfo,
        packageName: String,
    ): Map<String, String>? {
        return runCatching {
            mapOf(
                "packageName" to packageName,
                "label" to resolveInfo.loadLabel(packageManager).toString(),
            )
        }.getOrNull()
    }

    private fun buildAppMap(appInfo: ApplicationInfo): Map<String, String>? {
        return runCatching {
            mapOf(
                "packageName" to appInfo.packageName,
                "label" to appInfo.loadLabel(packageManager).toString(),
            )
        }.getOrNull()
    }

    private fun getAppIcon(packageName: String): String {
        if (packageName.isBlank()) return ""
        return runCatching {
            iconToBase64(packageManager.getApplicationIcon(packageName))
        }.getOrDefault("")
    }

    private fun iconToBase64(drawable: Drawable): String {
        val sizePx = 56
        val bitmap =
            if (drawable is BitmapDrawable && drawable.bitmap != null) {
                Bitmap.createScaledBitmap(drawable.bitmap, sizePx, sizePx, true)
            } else {
                val createdBitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(createdBitmap)
                drawable.setBounds(0, 0, sizePx, sizePx)
                drawable.draw(canvas)
                createdBitmap
            }

        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 86, outputStream)
        return Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
    }

    private fun hasUsageAccessPermission(): Boolean {
        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        return usageStatsManager
            .queryAndAggregateUsageStats(now - 86_400_000L, now)
            .isNotEmpty()
    }

    private fun openUsageAccessSettings() {
        startActivity(
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                data = Uri.parse("package:$packageName")
            },
        )
    }

    private fun hasAccessibilityPermission(): Boolean {
        val expectedService = "$packageName/${FocusAccessibilityService::class.java.name}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledServices)
        while (splitter.hasNext()) {
            if (splitter.next().equals(expectedService, ignoreCase = true)) {
                return true
            }
        }
        return false
    }

    private fun openAccessibilitySettings() {
        startActivity(
            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
    }

    private fun openOverlaySettings() {
        startActivity(
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                data = Uri.parse("package:$packageName")
            },
        )
    }

    private fun hasIgnoreBatteryOptimizationPermission(): Boolean {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun openIgnoreBatteryOptimizationSettings() {
        val requestIntent =
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                data = Uri.parse("package:$packageName")
            }

        val fallbackIntent =
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

        runCatching { startActivity(requestIntent) }
            .onFailure { startActivity(fallbackIntent) }
    }

    private fun startFocusSession(
        subject: String,
        durationSeconds: Int,
        blockedApps: List<Map<String, Any?>>, 
    ) {
        stopService(Intent(this, FocusShieldService::class.java))
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
            "lastBlockedAtMillis" to prefs.getLong(FocusShieldService.KEY_LAST_BLOCKED_AT_MILLIS, 0L),
        )
    }
}
