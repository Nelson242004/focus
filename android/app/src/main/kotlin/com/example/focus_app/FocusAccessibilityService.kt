package com.example.focus_app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class FocusAccessibilityService : AccessibilityService() {
    private val tag = "FocusAccessibility"
    private lateinit var overlayManager: FocusOverlayManager
    private val handler = Handler(Looper.getMainLooper())
    private val homePackages by lazy { resolveHomePackages() }
    private var lastBlockedPackage = ""
    private var recentlyClosedPackage = ""
    private var recentlyClosedUntilMillis = 0L
    private var pendingOverlayRunnable: Runnable? = null
    private val closeActionSuppressMillis = 2200L

    private val activeWindowMonitor =
        object : Runnable {
            override fun run() {
                runCatching { inspectCurrentWindow() }
                handler.postDelayed(this, 450L)
            }
        }

    override fun onCreate() {
        super.onCreate()
        overlayManager = FocusOverlayManager(this)
        debugLog("Accessibility service created")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        debugLog("Accessibility service connected")
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
        if (packageCandidates.isNotEmpty()) {
            debugLog("Accessibility event packages=$packageCandidates type=${event.eventType}")
        }
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
        debugLog("inspectPackages package=$packageName active=$active")
        if (!active) {
            clearPendingOverlay()
            overlayManager.dismissOverlay()
            lastBlockedPackage = ""
            prefs.edit()
                .putString(FocusShieldService.KEY_LAST_BLOCKED_PACKAGE, "")
                .apply()
            return
        }

        val blockedApps = parseBlockedApps(
            prefs.getString(FocusShieldService.KEY_BLOCKED_APPS_RAW, "").orEmpty(),
        )
        debugLog("blocked apps loaded=${blockedApps.keys}")
        if (blockedApps.isEmpty()) {
            clearPendingOverlay()
            overlayManager.dismissOverlay()
            lastBlockedPackage = ""
            prefs.edit()
                .putString(FocusShieldService.KEY_LAST_BLOCKED_PACKAGE, "")
                .apply()
            return
        }

        val blockedPackage = packageCandidates.firstOrNull { blockedApps.containsKey(it) }
        if (blockedPackage == null) {
            debugLog("Package not blocked: $packageName")
            if (overlayManager.isShowing() &&
                packageName != lastBlockedPackage &&
                !homePackages.contains(packageName)
            ) {
                overlayManager.dismissOverlay()
            }
            if (packageName != lastBlockedPackage) {
                lastBlockedPackage = ""
                prefs.edit()
                    .putString(FocusShieldService.KEY_LAST_BLOCKED_PACKAGE, "")
                    .apply()
            }
            return
        }

        val now = System.currentTimeMillis()
        if (blockedPackage == recentlyClosedPackage && now < recentlyClosedUntilMillis) {
            debugLog("Suppressing overlay after close action for $blockedPackage")
            clearPendingOverlay()
            overlayManager.dismissOverlay(immediate = true)
            return
        }
        if (now >= recentlyClosedUntilMillis) {
            recentlyClosedPackage = ""
            recentlyClosedUntilMillis = 0L
        }

        val lastPersistedPackage =
            prefs.getString(FocusShieldService.KEY_LAST_BLOCKED_PACKAGE, "").orEmpty()
        if (blockedPackage == lastBlockedPackage || blockedPackage == lastPersistedPackage) {
            debugLog("Ignoring repeated active attempt for $blockedPackage")
            return
        }

        val appLabel = blockedApps[blockedPackage] ?: blockedPackage
        prefs.edit()
            .putInt(
                FocusShieldService.KEY_BLOCKED_ATTEMPTS,
                prefs.getInt(FocusShieldService.KEY_BLOCKED_ATTEMPTS, 0) + 1,
            )
            .putString(FocusShieldService.KEY_LAST_BLOCKED_APP, appLabel)
            .putString(FocusShieldService.KEY_LAST_BLOCKED_PACKAGE, blockedPackage)
            .putLong(FocusShieldService.KEY_LAST_BLOCKED_AT_MILLIS, now)
            .apply()

        lastBlockedPackage = blockedPackage

        clearPendingOverlay()
        debugLog("Blocked package detected=$blockedPackage showing overlay soon")

        val runnable =
            Runnable {
                val stillActive = prefs.getBoolean(FocusShieldService.KEY_ACTIVE, false)
                if (!stillActive) return@Runnable
                debugLog("Triggering overlay for $blockedPackage")

                overlayManager.showBlockedOverlay(
                    packageName = blockedPackage,
                    appLabel = appLabel,
                    subject = prefs.getString(FocusShieldService.KEY_SUBJECT, "General")
                        ?: "General",
                    onCloseApp = {
                        debugLog("Overlay requested close for $blockedPackage")
                        suppressClosedPackage(blockedPackage)
                        performGlobalAction(GLOBAL_ACTION_HOME)
                        handler.postDelayed({
                            overlayManager.dismissOverlay()
                            lastBlockedPackage = ""
                            prefs.edit()
                                .putString(FocusShieldService.KEY_LAST_BLOCKED_PACKAGE, "")
                                .apply()
                        }, 180L)
                    },
                    onFailed = {
                        warnLog("Overlay could not be shown; using HOME fallback for $blockedPackage")
                        suppressClosedPackage(blockedPackage)
                        performGlobalAction(GLOBAL_ACTION_HOME)
                        handler.postDelayed({
                            lastBlockedPackage = ""
                            prefs.edit()
                                .putString(FocusShieldService.KEY_LAST_BLOCKED_PACKAGE, "")
                                .apply()
                        }, 220L)
                    },
                )
            }
        pendingOverlayRunnable = runnable
        handler.postDelayed(runnable, 120L)
    }

    private fun suppressClosedPackage(packageName: String) {
        recentlyClosedPackage = packageName
        recentlyClosedUntilMillis = System.currentTimeMillis() + closeActionSuppressMillis
    }

    private fun clearPendingOverlay() {
        pendingOverlayRunnable?.let(handler::removeCallbacks)
        pendingOverlayRunnable = null
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        debugLog("Accessibility service destroyed")
        handler.removeCallbacks(activeWindowMonitor)
        clearPendingOverlay()
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

    private fun debugLog(message: String) {
        if (BuildConfig.DEBUG) Log.d(tag, message)
    }

    private fun warnLog(message: String) {
        if (BuildConfig.DEBUG) Log.w(tag, message)
    }
}
