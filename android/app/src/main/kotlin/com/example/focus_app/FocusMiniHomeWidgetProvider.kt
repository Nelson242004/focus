package com.example.focus_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context

class FocusMiniHomeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        FocusHomeWidgetProvider.updateWidgets(
            context,
            appWidgetManager,
            appWidgetIds,
            R.layout.focus_home_widget_mini,
        )
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        val manager = AppWidgetManager.getInstance(context)
        val component = ComponentName(context, FocusMiniHomeWidgetProvider::class.java)
        FocusHomeWidgetProvider.updateWidgets(
            context,
            manager,
            manager.getAppWidgetIds(component),
            R.layout.focus_home_widget_mini,
        )
    }
}
