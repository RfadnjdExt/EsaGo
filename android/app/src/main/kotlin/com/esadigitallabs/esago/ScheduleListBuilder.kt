package com.esadigitallabs.esago

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

object ScheduleListBuilder {

    fun buildScheduleList(context: Context, widgetData: SharedPreferences): List<RemoteViews> {
        val allSchedulesJson = widgetData.getString("all_schedules_json", "[]")
        val currentDateStr = widgetData.getString(ScheduleWidgetProvider.PREF_DATE_KEY, "")
        val allSchedules = JSONArray(allSchedulesJson)
        val filteredItems = mutableListOf<JSONObject>()

        for (i in 0 until allSchedules.length()) {
            val item = allSchedules.getJSONObject(i)
            if (item.getString("date") == currentDateStr) {
                filteredItems.add(item)
            }
        }
        filteredItems.sortBy { it.getString("time").substring(0, 5) }

        val itemViews = mutableListOf<RemoteViews>()
        for (item in filteredItems) {
            val itemView = RemoteViews(context.packageName, R.layout.widget_list_item)
            itemView.setTextViewText(R.id.widget_item_course, item.getString("course"))
            itemView.setTextViewText(R.id.widget_item_time, item.getString("time"))
            val room = item.getString("room")
            itemView.setTextViewText(R.id.widget_item_room, room)
            if (room.isNullOrEmpty()) {
                itemView.setViewVisibility(R.id.widget_item_room_icon, View.GONE)
            } else {
                itemView.setViewVisibility(R.id.widget_item_room_icon, View.VISIBLE)
            }
            itemView.setTextViewText(R.id.widget_item_type, item.getString("type"))

            // Set onClick intent for each item if needed
            val lecturerName = item.optString("lecturer", "")
            if (lecturerName.isNotEmpty()) {
                val fillInIntent = Intent().apply {
                    action = "com.esadigitallabs.esago.ACTION_SHOW_COPY_DIALOG"
                    putExtra("lecturer_name", lecturerName)
                }
                itemView.setOnClickFillInIntent(R.id.widget_list_item, fillInIntent)
            }
            itemViews.add(itemView)
        }
        return itemViews
    }
}
