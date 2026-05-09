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
import kotlin.random.Random

class FocusOverlayManager(private val context: Context) {
    data class Quote(val text: String, val author: String)

    private val handler = Handler(Looper.getMainLooper())
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var overlayView: View? = null

    fun showBlockedOverlay(
        packageName: String,
        appLabel: String,
        subject: String,
        onCloseApp: () -> Unit,
    ) {
        if (!Settings.canDrawOverlays(context)) return
        if (overlayView != null) return

        handler.post {
            runCatching {
                val root = buildOverlayView(packageName, appLabel, subject, onCloseApp)
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
        }
    }

    fun dismissOverlay() {
        handler.post {
            val current = overlayView ?: return@post
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

    private fun buildOverlayView(
        packageName: String,
        appLabel: String,
        subject: String,
        onCloseApp: () -> Unit,
    ): FrameLayout {
        val root = FrameLayout(context).apply {
            setBackgroundColor(Color.parseColor("#E6111318"))
            isClickable = true
            isFocusable = false
            systemUiVisibility =
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        }

        val featuredQuote = randomQuote()

        val quoteText = TextView(context).apply {
            text = "\"${featuredQuote.text}\""
            setTextColor(Color.parseColor("#E5E7EB"))
            textSize = 22f
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.2f)
            setPadding(dp(28), dp(24), dp(28), dp(24))
            setTypeface(typeface, Typeface.BOLD_ITALIC)
        }

        val quoteAuthorText = TextView(context).apply {
            text = "— ${featuredQuote.author}"
            setTextColor(Color.parseColor("#FFA5B4FC"))
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(dp(28), 0, dp(28), dp(24))
            setTypeface(typeface, Typeface.BOLD)
        }

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(18), dp(18), dp(18))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(26).toFloat()
                setColor(Color.parseColor("#FF1E1E24"))
            }
        }

        val topRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val appIcon = ImageView(context).apply {
            layoutParams = LinearLayout.LayoutParams(dp(44), dp(44))
            setImageDrawable(resolveAppIcon(packageName))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#FF2A2A34"))
            }
            clipToOutline = true
        }

        val textColumn = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = dp(14)
            }
        }

        val appNameText = TextView(context).apply {
            text = appLabel
            setTextColor(Color.WHITE)
            textSize = 18f
            setTypeface(typeface, Typeface.BOLD)
        }

        val modeText = TextView(context).apply {
            text = "Modo de concentración"
            setTextColor(Color.parseColor("#FFA5B4FC"))
            textSize = 13f
        }

        val emergencyButton = Button(context).apply {
            text = "Emergencia"
            isAllCaps = false
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(18).toFloat()
                setColor(Color.parseColor("#FF5B6070"))
            }
            setTextColor(Color.WHITE)
            setPadding(dp(14), dp(8), dp(14), dp(8))
            setOnClickListener {
                onCloseApp()
                dismissOverlay()
            }
        }

        val divider = View(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(1),
            ).apply { topMargin = dp(14); bottomMargin = dp(14) }
            setBackgroundColor(Color.parseColor("#33FFFFFF"))
        }

        val infoText = TextView(context).apply {
            text = "${entryPhrase(subject)} Esta aplicación está pausada para ayudarte a mantenerte en el camino."
            setTextColor(Color.parseColor("#FFE5E7EB"))
            textSize = 14f
            setLineSpacing(0f, 1.2f)
        }

        val closeButton = Button(context).apply {
            text = "Cerrar $appLabel"
            isAllCaps = false
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(18).toFloat()
                setColor(Color.parseColor("#FFC4B5FD"))
            }
            setTextColor(Color.parseColor("#FF111827"))
            textSize = 15f
            setTypeface(typeface, Typeface.BOLD)
            setPadding(dp(18), dp(14), dp(18), dp(14))
            setOnClickListener {
                onCloseApp()
                dismissOverlay()
            }
        }

        val footerText = TextView(context).apply {
            text = "Focus · Mantén tu sesión"
            setTextColor(Color.parseColor("#FF9CA3AF"))
            textSize = 12f
            gravity = Gravity.CENTER
        }

        textColumn.addView(appNameText)
        textColumn.addView(modeText)
        topRow.addView(appIcon)
        topRow.addView(textColumn)
        topRow.addView(emergencyButton)

        card.addView(topRow)
        card.addView(divider)
        card.addView(infoText)
        card.addView(spaceView(dp(18)))
        card.addView(closeButton)
        card.addView(spaceView(dp(12)))
        card.addView(footerText)

        root.addView(
            quoteText,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ).apply {
                bottomMargin = dp(120)
            },
        )
        root.addView(
            quoteAuthorText,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ).apply {
                topMargin = dp(76)
            },
        )
        root.addView(
            card,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL,
            ).apply {
                leftMargin = dp(16)
                rightMargin = dp(16)
                bottomMargin = dp(22)
            },
        )

        root.setOnClickListener { }
        return root
    }

    private fun resolveAppIcon(packageName: String) =
        runCatching { context.packageManager.getApplicationIcon(packageName) }
            .getOrElse {
                ContextCompat.getDrawable(context, R.mipmap.ic_launcher)
                    ?: context.packageManager.getApplicationIcon(context.packageName)
            }

    private fun randomQuote(): Quote {
        val quotes = listOf(
            Quote("La concentración es la raíz de todas las capacidades superiores del ser humano.", "Bruce Lee"),
            Quote("Lo que importa es poner atención en lo que estás haciendo.", "John Dewey"),
            Quote("La gente exitosa mantiene el enfoque positivo en la vida.", "Joyce Meyer"),
            Quote("Concentrar la mente es el secreto de la fuerza.", "Ralph Waldo Emerson"),
            Quote("Haz cada acto de tu vida como si fuera el último.", "Marco Aurelio"),
        )
        return quotes[Random.nextInt(quotes.size)]
    }

    private fun entryPhrase(subject: String): String {
        val cleanedSubject = subject.trim().ifBlank { "tu sesión" }
        val phrases = listOf(
            "Respira. Vuelve a $cleanedSubject.",
            "Tu enfoque va primero. Sigue con $cleanedSubject.",
            "No rompas el ritmo ahora. Regresa a $cleanedSubject.",
            "Este momento cuenta. Vuelve a $cleanedSubject.",
        )
        return phrases[Random.nextInt(phrases.size)]
    }

    private fun layoutParams() = WindowManager.LayoutParams(
        WindowManager.LayoutParams.MATCH_PARENT,
        WindowManager.LayoutParams.MATCH_PARENT,
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        },
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR,
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
    }

    private fun dp(value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()

    private fun spaceView(height: Int) = View(context).apply {
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            height,
        )
    }
}
