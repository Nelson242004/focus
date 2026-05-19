package com.example.focus_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

object FocusHomeWidgetUpdater {
    const val PREFS_NAME = "focus_widget_prefs"
    const val KEY_WIDGET_MODE = "widget_mode"
    const val KEY_CLASS_TITLE = "class_title"
    const val KEY_CLASS_DETAIL = "class_detail"
    const val KEY_EXAM_TITLE = "exam_title"
    const val KEY_EXAM_DETAIL = "exam_detail"
    const val KEY_EXAM_NOTE = "exam_note"
    const val KEY_EXAM_AT_MILLIS = "exam_at_millis"
    const val KEY_META = "meta"
    const val KEY_PROFILE_ICON_ASSET = "profile_icon_asset"

    fun updateWidgets(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
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

        val profileIconAsset = prefs.getString(KEY_PROFILE_ICON_ASSET, "") ?: ""

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
            val views = RemoteViews(context.packageName, R.layout.focus_home_widget_mini)

            views.setTextViewText(R.id.widgetHeadline, headline)
            views.setTextViewText(R.id.widgetTitle, title)
            views.setTextViewText(R.id.widgetDetail, detail)
            views.setTextViewText(R.id.widgetNote, note)
            views.setTextViewText(R.id.widgetUrgency, "")
            views.setTextViewText(R.id.widgetMeta, streak)
            views.setImageViewResource(R.id.widgetMascotImage, mascotForProfile(profileIconAsset))
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

    private fun mascotForProfile(asset: String): Int {
        return when (asset) {
            "assets/profile_icons/focus_scholar.png" -> R.drawable.focus_profile_scholar
            "assets/profile_icons/focus_flame.png" -> R.drawable.focus_profile_flame
            "assets/profile_icons/focus_calm.png" -> R.drawable.focus_profile_calm
            "assets/profile_icons/focus_champion.png" -> R.drawable.focus_profile_champion
            "assets/profile_icons/focus_scholar_female.png" -> R.drawable.focus_profile_scholar_female
            "assets/profile_icons/focus_flame_female.png" -> R.drawable.focus_profile_flame_female
            "assets/profile_icons/focus_calm_female.png" -> R.drawable.focus_profile_calm_female
            "assets/profile_icons/focus_champion_female.png" -> R.drawable.focus_profile_champion_female
            "assets/profile_icons/focus_dark.png" -> R.drawable.focus_profile_dark
            "assets/profile_icons/focus_dark_female.png" -> R.drawable.focus_profile_dark_female
            "assets/profile_icons/focus_programmer.png" -> R.drawable.focus_profile_programmer
            "assets/profile_icons/focus_doctor.png" -> R.drawable.focus_profile_doctor
            "assets/profile_icons/focus_teacher.png" -> R.drawable.focus_profile_teacher
            "assets/profile_icons/focus_engineer.png" -> R.drawable.focus_profile_engineer
            "assets/profile_icons/focus_architect.png" -> R.drawable.focus_profile_architect
            "assets/profile_icons/focus_lawyer.png" -> R.drawable.focus_profile_lawyer
            "assets/profile_icons/focus_programmer_female.png" -> R.drawable.focus_profile_programmer_female
            "assets/profile_icons/focus_doctor_female.png" -> R.drawable.focus_profile_doctor_female
            "assets/profile_icons/focus_teacher_female.png" -> R.drawable.focus_profile_teacher_female
            "assets/profile_icons/focus_engineer_female.png" -> R.drawable.focus_profile_engineer_female
            "assets/profile_icons/focus_architect_female.png" -> R.drawable.focus_profile_architect_female
            "assets/profile_icons/focus_lawyer_female.png" -> R.drawable.focus_profile_lawyer_female
            "assets/profile_icons/focus_pink_cool.png" -> R.drawable.focus_profile_pink_cool
            "assets/profile_icons/focus_pink_cool_female.png" -> R.drawable.focus_profile_pink_cool_female
            "assets/profile_icons/focus_pink_skater.png" -> R.drawable.focus_profile_pink_skater
            "assets/profile_icons/focus_pink_skater_female.png" -> R.drawable.focus_profile_pink_skater_female
            "assets/profile_icons/focus_pink_music.png" -> R.drawable.focus_profile_pink_music
            "assets/profile_icons/focus_pink_music_female.png" -> R.drawable.focus_profile_pink_music_female
            "assets/profile_icons/focus_pink_artist.png" -> R.drawable.focus_profile_pink_artist
            "assets/profile_icons/focus_pink_artist_female.png" -> R.drawable.focus_profile_pink_artist_female
            "assets/profile_icons/focus_red_basket.png" -> R.drawable.focus_profile_red_basket
            "assets/profile_icons/focus_purple_camera.png" -> R.drawable.focus_profile_purple_camera
            "assets/profile_icons/focus_green_tech.png" -> R.drawable.focus_profile_green_tech
            "assets/profile_icons/focus_black_gamer.png" -> R.drawable.focus_profile_black_gamer
            "assets/profile_icons/focus_orange_travel.png" -> R.drawable.focus_profile_orange_travel
            "assets/profile_icons/focus_yellow_gym.png" -> R.drawable.focus_profile_yellow_gym
            else -> R.drawable.focus_profile_scholar
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
