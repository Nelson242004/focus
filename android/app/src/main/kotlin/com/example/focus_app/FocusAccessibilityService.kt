package com.example.focus_app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent

class FocusAccessibilityService : AccessibilityService() {
    private lateinit var overlayManager: FocusOverlayManager
    private val handler = Handler(Looper.getMainLooper())
    private val homePackages by lazy { resolveHomePackages() }
    private var lastBlockedPackage = ""
    private var lastBlockedAt = 0L
    private val activeWindowMonitor =
        object : Runnable {
            override fun run() {
                runCatching { inspectCurrentWindow() }
                handler.postDelayed(this, 800L)
            }
        }

    override fun onCreate() {
        super.onCreate()
        overlayManager = FocusOverlayManager(applicationContext)
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        handler.removeCallbacks(activeWindowMonitor)
        handler.post(activeWindowMonitor)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        ) {
            return
        }

        val packageCandidates = linkedSetOf<String>()
        event.packageName?.toString()?.takeIf { it.isNotBlank() }?.let(packageCandidates::add)
        rootInActiveWindow?.packageName
            ?.toString()
            ?.takeIf { it.isNotBlank() }
            ?.let(packageCandidates::add)
        inspectPackages(packageCandidates)
    }

    private fun inspectCurrentWindow() {
        val packageCandidates = linkedSetOf<String>()
        rootInActiveWindow?.packageName
            ?.toString()
            ?.takeIf { it.isNotBlank() }
            ?.let(packageCandidates::add)
        inspectPackages(packageCandidates)
    }

    private fun inspectPackages(packageCandidates: Set<String>) {
        val packageName = packageCandidates.firstOrNull { !shouldIgnorePackage(it) } ?: return
        val prefs = getSharedPreferences(FocusShieldService.PREFS_NAME, MODE_PRIVATE)
        val active = prefs.getBoolean(FocusShieldService.KEY_ACTIVE, false)
        if (!active) {
            overlayManager.dismissOverlay()
            lastBlockedPackage = ""
            return
        }

        val blockedApps = parseBlockedApps(
            prefs.getString(FocusShieldService.KEY_BLOCKED_APPS_RAW, "").orEmpty(),
        )
        if (blockedApps.isEmpty()) {
            overlayManager.dismissOverlay()
            lastBlockedPackage = ""
            return
        }

        val blockedPackage = packageCandidates.firstOrNull { blockedApps.containsKey(it) }
        if (blockedPackage == null) {
            if (overlayManager.isShowing() &&
                packageName != lastBlockedPackage &&
                !homePackages.contains(packageName)
            ) {
                overlayManager.dismissOverlay()
            }
            if (packageName != lastBlockedPackage) {
                lastBlockedPackage = ""
            }
            return
        }

        val now = System.currentTimeMillis()
        if (overlayManager.isShowing() &&
            blockedPackage == lastBlockedPackage &&
            now - lastBlockedAt < 2500L
        ) {
            return
        }

        val appLabel = blockedApps[blockedPackage] ?: blockedPackage
        prefs.edit()
            .putInt(
                FocusShieldService.KEY_BLOCKED_ATTEMPTS,
                prefs.getInt(FocusShieldService.KEY_BLOCKED_ATTEMPTS, 0) + 1,
            )
            .putString(FocusShieldService.KEY_LAST_BLOCKED_APP, appLabel)
            .putLong(FocusShieldService.KEY_LAST_BLOCKED_AT_MILLIS, now)
            .apply()

        lastBlockedPackage = blockedPackage
        lastBlockedAt = now

        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({
            val stillActive = prefs.getBoolean(FocusShieldService.KEY_ACTIVE, false)
            if (!stillActive) return@postDelayed

            overlayManager.showBlockedOverlay(
                packageName = blockedPackage,
                appLabel = appLabel,
                subject = prefs.getString(FocusShieldService.KEY_SUBJECT, "General")
                    ?: "General",
                onCloseApp = {
                    performGlobalAction(GLOBAL_ACTION_HOME)
                    handler.postDelayed({
                        overlayManager.dismissOverlay()
                        lastBlockedPackage = ""
                    }, 140L)
                },
            )
        }, 120L)
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        handler.removeCallbacks(activeWindowMonitor)
        handler.removeCallbacksAndMessages(null)
        overlayManager.dismissOverlay()
        super.onDestroy()
    }

    private fun parseBlockedApps(raw: String): Map<String, String> {
        if (raw.isBlank()) return emptyMap()
        return raw.split("||")
            .mapNotNull {
                val parts = it.split("::", limit = 2)
                if (parts.isEmpty() || parts[0].isBlank()) {
                    null
                } else {
                    parts[0] to parts.getOrElse(1) { parts[0] }
                }
            }
            .toMap()
    }

    private fun shouldIgnorePackage(packageName: String): Boolean {
        if (packageName == this.packageName) return true
        if (packageName == "android") return true
        if (packageName == "com.android.systemui") return true
        if (packageName == "com.google.android.permissioncontroller") return true
        if (packageName == "com.android.permissioncontroller") return true
        if (packageName == "com.google.android.packageinstaller") return true
        if (packageName == "com.samsung.android.permissioncontroller") return true
        return false
    }

    private fun resolveHomePackages(): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        return runCatching {
            packageManager.queryIntentActivities(intent, 0)
                .mapNotNull { it.activityInfo?.packageName }
                .toSet()
        }.getOrDefault(emptySet())
    }
}
