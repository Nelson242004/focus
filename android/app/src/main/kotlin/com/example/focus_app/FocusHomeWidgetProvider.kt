package com.example.focus_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

class FocusHomeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        val manager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, FocusHomeWidgetProvider::class.java)
        updateWidgets(context, manager, manager.getAppWidgetIds(component))
    }

    companion object {
        const val PREFS_NAME = "focus_widget_prefs"
        const val KEY_WIDGET_MODE = "widget_mode"
        const val KEY_CLASS_TITLE = "class_title"
        const val KEY_CLASS_DETAIL = "class_detail"
        const val KEY_EXAM_TITLE = "exam_title"
        const val KEY_EXAM_DETAIL = "exam_detail"
        const val KEY_EXAM_NOTE = "exam_note"
        const val KEY_EXAM_AT_MILLIS = "exam_at_millis"
        const val KEY_META = "meta"

        fun updateWidgets(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray,
            layoutId: Int = R.layout.focus_home_widget,
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val examAtMillis = prefs.getLong(KEY_EXAM_AT_MILLIS, 0L)
            val now = System.currentTimeMillis()
            val nearExam = examAtMillis > 0L &&
                examAtMillis >= now &&
                examAtMillis - now <= 86_400_000L
            val requestedMode = prefs.getString(KEY_WIDGET_MODE, "class") ?: "class"
            val mode = when {
                requestedMode == "pomodoro" -> "pomodoro"
                requestedMode == "break" -> "break"
                requestedMode == "almost_done" -> "almost_done"
                requestedMode == "streak_risk" -> "streak_risk"
                nearExam -> "exam"
                else -> "class"
            }

            val headline = when (mode) {
                "exam" -> "Próximo examen"
                "pomodoro" -> "En enfoque"
                "break" -> "Descanso"
                "almost_done" -> "Casi terminas"
                "streak_risk" -> "Cuida tu racha"
                else -> "Próxima clase"
            }
            val title = when (mode) {
                "exam" -> prefs.getString(KEY_EXAM_TITLE, "")?.takeIf { it.isNotBlank() }
                    ?: "Examen cercano"
                else -> prefs.getString(KEY_CLASS_TITLE, "Día libre por ahora")
                    ?: "Día libre por ahora"
            }
            val detail = when (mode) {
                "exam" -> prefs.getString(KEY_EXAM_DETAIL, "Aula por confirmar")
                    ?: "Aula por confirmar"
                else -> prefs.getString(KEY_CLASS_DETAIL, "Abre Focus y organiza tu semana.")
                    ?: "Abre Focus y organiza tu semana."
            }
            val note = when (mode) {
                "exam" -> prefs.getString(KEY_EXAM_NOTE, "") ?: ""
                "pomodoro", "break", "almost_done" -> prefs.getString(KEY_EXAM_NOTE, "") ?: ""
                "streak_risk" -> "Haz un bloque hoy"
                else -> ""
            }
            val streak = prefs.getString(KEY_META, "0 días") ?: "0 días"

            val launchIntent =
                context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                } ?: Intent(context, MainActivity::class.java)

            val pendingIntent =
                PendingIntent.getActivity(
                    context,
                    4001,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )

            appWidgetIds.forEach { widgetId ->
                val views = RemoteViews(context.packageName, layoutId)

                views.setTextViewText(R.id.widgetHeadline, headline)
                views.setTextViewText(R.id.widgetTitle, title)
                views.setTextViewText(R.id.widgetDetail, detail)
                views.setTextViewText(R.id.widgetNote, note)
                views.setTextViewText(R.id.widgetUrgency, "")
                views.setTextViewText(R.id.widgetMeta, streak)
                views.setImageViewResource(R.id.widgetMascotImage, mascotForMode(mode))
                views.setOnClickPendingIntent(R.id.widgetRoot, pendingIntent)

                views.setViewVisibility(
                    R.id.widgetNote,
                    if (note.isBlank()) View.GONE else View.VISIBLE,
                )
                views.setViewVisibility(R.id.widgetUrgencyPill, View.GONE)

                views.setInt(R.id.widgetRoot, "setBackgroundResource", backgroundForMode(mode))
                views.setInt(
                    R.id.widgetHeadline,
                    "setTextColor",
                    if (mode == "exam" || mode == "almost_done") {
                        0xFFFFF7ED.toInt()
                    } else {
                        0xFFE0F2FE.toInt()
                    },
                )
                views.setInt(
                    R.id.widgetStreakPill,
                    "setBackgroundResource",
                    if (mode == "exam" || mode == "almost_done") {
                        R.drawable.focus_widget_exam_streak_background
                    } else {
                        R.drawable.focus_widget_streak_background
                    },
                )

                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }

        private fun mascotForMode(mode: String): Int {
            return when (mode) {
                "exam" -> R.drawable.focus_mascot_exam
                "pomodoro" -> R.drawable.focus_mascot_pomodoro
                "break" -> R.drawable.focus_mascot_break
                "almost_done" -> R.drawable.focus_mascot_almost_done
                "streak_risk" -> R.drawable.focus_mascot_streak_risk
                else -> R.drawable.focus_mascot_class
            }
        }

        private fun backgroundForMode(mode: String): Int {
            return when (mode) {
                "exam", "almost_done" -> R.drawable.focus_widget_exam_background
                "break" -> R.drawable.focus_widget_break_background
                "streak_risk" -> R.drawable.focus_widget_streak_risk_background
                else -> R.drawable.focus_widget_background
            }
        }
    }
}
