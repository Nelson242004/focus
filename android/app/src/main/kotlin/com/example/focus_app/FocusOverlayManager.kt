package com.example.focus_app

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat

class FocusOverlayManager(private val context: Context) {
    private val tag = "FocusOverlay"

    private val handler = Handler(Looper.getMainLooper())
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var overlayView: View? = null

    fun showBlockedOverlay(
        packageName: String,
        appLabel: String,
        subject: String,
        onCloseApp: () -> Unit,
        onFailed: (() -> Unit)? = null,
    ) {
        if (overlayView != null) {
            dismissOverlay(immediate = true)
        }

        handler.post {
            runCatching {
                if (!canShowOverlay()) {
                    warnLog("Overlay unavailable for current device/service state")
                    onFailed?.invoke()
                    return@post
                }
                debugLog("Adding overlay for package=$packageName")
                attachOverlay(buildOverlayView(packageName, appLabel, subject, onCloseApp))
            }.recoverCatching {
                errorLog("Premium overlay failed, using fallback overlay", it)
                clearOverlayNow()
                attachOverlay(buildFallbackOverlayView(appLabel, subject, onCloseApp))
            }.onFailure {
                clearOverlayNow()
                errorLog("Failed to show overlay", it)
                onFailed?.invoke()
            }
        }
    }

    fun dismissOverlay(immediate: Boolean = false) {
        handler.post {
            val current = overlayView ?: return@post
            debugLog("Dismissing overlay")
            if (immediate) {
                runCatching { windowManager.removeView(current) }
                if (overlayView === current) {
                    overlayView = null
                }
                return@post
            }
            current.animate()
                .alpha(0f)
                .translationY(48f)
                .setDuration(240)
                .withEndAction {
                    runCatching { windowManager.removeView(current) }
                    if (overlayView === current) {
                        overlayView = null
                    }
                }
                .start()
        }
    }

    fun isShowing(): Boolean = overlayView != null

    private fun clearOverlayNow() {
        val current = overlayView ?: return
        runCatching { windowManager.removeViewImmediate(current) }
            .recoverCatching { windowManager.removeView(current) }
        if (overlayView === current) {
            overlayView = null
        }
    }

    private fun buildOverlayView(
        packageName: String,
        appLabel: String,
        subject: String,
        onCloseApp: () -> Unit,
    ): FrameLayout {
        val root = FrameLayout(context).apply {
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(
                    Color.parseColor("#F4000000"),
                    Color.parseColor("#F4091118"),
                    Color.parseColor("#F4111C2B"),
                ),
            )
            isClickable = true
            isFocusable = false
            systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        }

        val prefs = context.getSharedPreferences(FocusShieldService.PREFS_NAME, Context.MODE_PRIVATE)
        val remainingSeconds = prefs.getInt(FocusShieldService.KEY_REMAINING_SECONDS, 0)
        val cleanSubject = subject.trim().ifBlank { "General" }

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(18), dp(18), dp(16))
            background = roundedGradient(
                radius = 30,
                colors = intArrayOf(Color.parseColor("#FF182230"), Color.parseColor("#FF0E1520")),
                strokeColor = Color.parseColor("#5538BDF8"),
            )
        }

        val brandRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, dp(14))
        }

        val focusBadge = ImageView(context).apply {
            setImageDrawable(resolveFocusIcon())
            background = roundedGradient(
                radius = 18,
                colors = intArrayOf(Color.parseColor("#222563EB"), Color.parseColor("#2214B8A6")),
                strokeColor = Color.parseColor("#3345E5D9"),
            )
            setPadding(dp(4), dp(4), dp(4), dp(4))
        }

        val brandText = TextView(context).apply {
            text = "Modo Enfoque"
            setTextColor(Color.parseColor("#FFE5F7FF"))
            textSize = 13f
            setTypeface(typeface, Typeface.BOLD)
        }

        val brandSpacer = View(context).apply {
            layoutParams = LinearLayout.LayoutParams(0, 1, 1f)
        }

        val topRow = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }

        val appIcon = ImageView(context).apply {
            layoutParams = LinearLayout.LayoutParams(dp(72), dp(72))
            setImageDrawable(resolveAppIcon(packageName))
            background = ovalDrawable(Color.parseColor("#FF1F2937"), Color.parseColor("#3345E5D9"))
            setPadding(dp(6), dp(6), dp(6), dp(6))
            clipToOutline = true
        }

        val textColumn = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(0, dp(10), 0, 0)
        }

        val appNameText = TextView(context).apply {
            text = appLabel
            setTextColor(Color.WHITE)
            textSize = 20f
            gravity = Gravity.CENTER
            setTypeface(typeface, Typeface.BOLD)
        }

        val modeText = TextView(context).apply {
            text = "Esta app está bloqueada durante tu sesión."
            setTextColor(Color.parseColor("#FF94A3B8"))
            textSize = 13f
            gravity = Gravity.CENTER
        }

        val emergencyButton = TextView(context).apply {
            text = "Emergencia"
            gravity = Gravity.CENTER
            background = roundedSolid(16, Color.parseColor("#14FFFFFF"), Color.parseColor("#1EFFFFFF"))
            setTextColor(Color.parseColor("#FFCBD5E1"))
            textSize = 12f
            setTypeface(typeface, Typeface.BOLD)
            setPadding(dp(12), dp(8), dp(12), dp(8))
            setOnClickListener {
                onCloseApp()
                dismissOverlay()
            }
        }

        val divider = View(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(1),
            ).apply { topMargin = dp(14); bottomMargin = dp(16) }
            setBackgroundColor(Color.parseColor("#1FFFFFFF"))
        }

        val headlineText = TextView(context).apply {
            text = "Volvé a tu enfoque"
            setTextColor(Color.WHITE)
            textSize = 25f
            gravity = Gravity.CENTER
            setTypeface(typeface, Typeface.BOLD)
        }

        val infoPillRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, dp(14), 0, dp(14))
        }

        infoPillRow.addView(
            metricPill("Tiempo", formatTime(remainingSeconds), Color.parseColor("#FF22D3EE")),
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply { marginEnd = dp(8) },
        )
        infoPillRow.addView(
            metricPill("Materia", cleanSubject.take(14), Color.parseColor("#FF34D399")),
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
        )

        val closeButton = Button(context).apply {
            text = "Volver a Focus"
            isAllCaps = false
            background = roundedGradient(
                radius = 20,
                colors = intArrayOf(Color.parseColor("#FF2563EB"), Color.parseColor("#FF14B8A6")),
            )
            setTextColor(Color.WHITE)
            textSize = 15f
            setTypeface(typeface, Typeface.BOLD)
            setPadding(dp(18), dp(16), dp(18), dp(16))
            setOnClickListener {
                returnToFocus()
            }
        }

        brandRow.addView(
            focusBadge,
            LinearLayout.LayoutParams(dp(34), dp(34)).apply { marginEnd = dp(10) },
        )
        brandRow.addView(brandText)
        brandRow.addView(brandSpacer)
        brandRow.addView(emergencyButton)

        textColumn.addView(appNameText)
        textColumn.addView(modeText)
        topRow.addView(appIcon)
        topRow.addView(textColumn)

        card.addView(brandRow)
        card.addView(topRow)
        card.addView(divider)
        card.addView(headlineText)
        card.addView(infoPillRow)
        card.addView(spaceView(dp(8)))
        card.addView(closeButton)

        root.addView(
            card,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
            ).apply {
                leftMargin = dp(16)
                rightMargin = dp(16)
                bottomMargin = dp(18) + systemNavigationBottomInset()
            },
        )

        root.setOnClickListener { }
        appIcon.animate()
            .rotationBy(3f)
            .setDuration(90)
            .withEndAction {
                appIcon.animate().rotationBy(-3f).setDuration(90).start()
            }
            .start()
        return root
    }

    private fun buildFallbackOverlayView(
        appLabel: String,
        subject: String,
        onCloseApp: () -> Unit,
    ): FrameLayout {
        val root = FrameLayout(context).apply {
            setBackgroundColor(Color.parseColor("#F2081118"))
            isClickable = true
            isFocusable = false
        }

        val prefs = context.getSharedPreferences(FocusShieldService.PREFS_NAME, Context.MODE_PRIVATE)
        val remainingSeconds = prefs.getInt(FocusShieldService.KEY_REMAINING_SECONDS, 0)
        val cleanSubject = subject.trim().ifBlank { "General" }

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(20), dp(22), dp(20), dp(18))
            background = roundedSolid(28, Color.parseColor("#FF111827"), Color.parseColor("#3345E5D9"))
        }

        val focusIcon = ImageView(context).apply {
            setImageDrawable(resolveFocusIcon())
            setPadding(dp(5), dp(5), dp(5), dp(5))
            background = ovalDrawable(Color.parseColor("#222563EB"), Color.parseColor("#3345E5D9"))
        }

        val title = TextView(context).apply {
            text = "Volvé a tu enfoque"
            setTextColor(Color.WHITE)
            textSize = 23f
            gravity = Gravity.CENTER
            setTypeface(typeface, Typeface.BOLD)
        }

        val subtitle = TextView(context).apply {
            text = "$appLabel está bloqueada durante tu sesión."
            setTextColor(Color.parseColor("#FFCBD5E1"))
            textSize = 13f
            gravity = Gravity.CENTER
            setPadding(0, dp(6), 0, dp(14))
        }

        val infoText = TextView(context).apply {
            text = "${formatTime(remainingSeconds)} · $cleanSubject"
            setTextColor(Color.parseColor("#FF67E8F9"))
            textSize = 13f
            gravity = Gravity.CENTER
            setTypeface(typeface, Typeface.BOLD)
            background = roundedSolid(18, Color.parseColor("#1422D3EE"), Color.parseColor("#2238BDF8"))
            setPadding(dp(14), dp(8), dp(14), dp(8))
        }

        val primaryButton = Button(context).apply {
            text = "Volver a Focus"
            isAllCaps = false
            background = roundedGradient(
                radius = 20,
                colors = intArrayOf(Color.parseColor("#FF2563EB"), Color.parseColor("#FF14B8A6")),
            )
            setTextColor(Color.WHITE)
            textSize = 15f
            setTypeface(typeface, Typeface.BOLD)
            setPadding(dp(18), dp(15), dp(18), dp(15))
            setOnClickListener {
                returnToFocus()
            }
        }

        val emergencyButton = TextView(context).apply {
            text = "Emergencia"
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#FFCBD5E1"))
            textSize = 12f
            setTypeface(typeface, Typeface.BOLD)
            setPadding(dp(12), dp(10), dp(12), dp(6))
            setOnClickListener {
                onCloseApp()
                dismissOverlay()
            }
        }

        card.addView(focusIcon, LinearLayout.LayoutParams(dp(52), dp(52)))
        card.addView(spaceView(dp(14)))
        card.addView(title)
        card.addView(subtitle)
        card.addView(infoText)
        card.addView(spaceView(dp(16)))
        card.addView(primaryButton, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ))
        card.addView(emergencyButton)

        root.addView(
            card,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
            ).apply {
                leftMargin = dp(16)
                rightMargin = dp(16)
                bottomMargin = dp(18) + systemNavigationBottomInset()
            },
        )
        return root
    }

    private fun attachOverlay(root: View) {
        overlayView = root
        windowManager.addView(root, layoutParams())
        root.alpha = 0f
        root.translationY = 40f
        root.animate()
            .alpha(1f)
            .translationY(0f)
            .setDuration(420)
            .setInterpolator(OvershootInterpolator(0.8f))
            .start()
    }

    private fun resolveAppIcon(packageName: String) =
        runCatching { context.packageManager.getApplicationIcon(packageName) }
            .getOrElse {
                ContextCompat.getDrawable(context, R.mipmap.ic_launcher)
                    ?: context.packageManager.getApplicationIcon(context.packageName)
            }

    private fun resolveFocusIcon() =
        ContextCompat.getDrawable(context, R.mipmap.ic_launcher)
            ?: context.packageManager.getApplicationIcon(context.packageName)

    private fun roundedGradient(
        radius: Int,
        colors: IntArray,
        strokeColor: Int? = null,
    ) = GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT, colors).apply {
        shape = GradientDrawable.RECTANGLE
        cornerRadius = dp(radius).toFloat()
        strokeColor?.let { setStroke(dp(1), it) }
    }

    private fun roundedSolid(radius: Int, color: Int, strokeColor: Int? = null) =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(radius).toFloat()
            setColor(color)
            strokeColor?.let { setStroke(dp(1), it) }
        }

    private fun ovalDrawable(color: Int, strokeColor: Int? = null) =
        GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(color)
            strokeColor?.let { setStroke(dp(1), it) }
        }

    private fun metricPill(label: String, value: String, accent: Int): LinearLayout {
        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(8), dp(9), dp(8), dp(9))
            background = roundedSolid(18, Color.parseColor("#101E293B"), Color.parseColor("#1FFFFFFF"))

            addView(TextView(context).apply {
                text = label
                setTextColor(Color.parseColor("#FF94A3B8"))
                textSize = 10f
                gravity = Gravity.CENTER
                setTypeface(typeface, Typeface.BOLD)
            })
            addView(TextView(context).apply {
                text = value.ifBlank { "—" }
                setTextColor(accent)
                textSize = 13f
                gravity = Gravity.CENTER
                maxLines = 1
                setTypeface(typeface, Typeface.BOLD)
            })
        }
    }

    private fun returnToFocus() {
        val launched = openFocusApp()
        if (launched) {
            handler.postDelayed({ clearOverlayNow() }, 90)
        } else {
            clearOverlayNow()
        }
    }

    private fun openFocusApp(): Boolean {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(Settings.ACTION_SETTINGS)
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                Intent.FLAG_ACTIVITY_NO_ANIMATION,
        )
        return runCatching {
            context.startActivity(intent)
            true
        }.getOrElse {
            errorLog("Failed to return to Focus", it)
            false
        }
    }

    private fun formatTime(seconds: Int): String {
        val safeSeconds = seconds.coerceAtLeast(0)
        val minutes = safeSeconds / 60
        val remaining = safeSeconds % 60
        return String.format("%02d:%02d", minutes, remaining)
    }

    private fun canShowOverlay(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            true
        } else {
            Settings.canDrawOverlays(context)
        }
    }

    private fun layoutParams() = WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.MATCH_PARENT,
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        },
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR,
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
    }

    private fun systemNavigationBottomInset(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return windowManager.currentWindowMetrics.windowInsets
                .getInsets(android.view.WindowInsets.Type.navigationBars())
                .bottom
        }

        val resourceId = context.resources.getIdentifier(
            "navigation_bar_height",
            "dimen",
            "android",
        )
        return if (resourceId > 0) {
            context.resources.getDimensionPixelSize(resourceId)
        } else {
            0
        }
    }

    private fun dp(value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()

    private fun spaceView(height: Int) = View(context).apply {
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            height,
        )
    }

    private fun debugLog(message: String) {
        if (BuildConfig.DEBUG) Log.d(tag, message)
    }

    private fun warnLog(message: String) {
        if (BuildConfig.DEBUG) Log.w(tag, message)
    }

    private fun errorLog(message: String, error: Throwable) {
        if (BuildConfig.DEBUG) Log.e(tag, message, error)
    }
}
