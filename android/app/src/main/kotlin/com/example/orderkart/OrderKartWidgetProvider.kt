package com.example.orderkart

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class OrderKartWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // Get data saved from Flutter side via home_widget plugin
                val orders = widgetData.getString("widget_orders", "-")
                val due = widgetData.getString("widget_due", "-")
                val stock = widgetData.getString("widget_stock", "-")

                setTextViewText(R.id.tv_orders, orders)
                setTextViewText(R.id.tv_due, due)
                setTextViewText(R.id.tv_stock, stock)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
