package com.esadigitallabs.esago

import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale

class ScheduleWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ScheduleRemoteViewsFactory(applicationContext)
    }
}

class ScheduleRemoteViewsFactory(
    private val context: Context
) : RemoteViewsService.RemoteViewsFactory {

    private var scheduleItemsForDate = listOf<JSONObject>()

    override fun onCreate() {
        // Tidak ada yang perlu dilakukan di sini
    }

    override fun onDataSetChanged() {
        val widgetData = HomeWidgetPlugin.getData(context)
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
        
        // Urutkan berdasarkan waktu mulai
        filteredItems.sortBy { it.getString("time").substring(0, 5) }
        scheduleItemsForDate = filteredItems
    }

    override fun onDestroy() {
        scheduleItemsForDate = emptyList()
    }

    override fun getCount(): Int = scheduleItemsForDate.size

    override fun getViewAt(position: Int): RemoteViews {
        val item = scheduleItemsForDate[position]
        val views = RemoteViews(context.packageName, R.layout.widget_list_item)

        views.setTextViewText(R.id.widget_item_course, item.getString("course"))
        views.setTextViewText(R.id.widget_item_time, item.getString("time"))
        
        val room = item.getString("room")
        views.setTextViewText(R.id.widget_item_room, room)

        if (room.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_item_room_icon, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_item_room_icon, View.VISIBLE)
        }

        views.setTextViewText(R.id.widget_item_type, item.getString("type"))

        val lecturerName = item.optString("lecturer", "")
        if (lecturerName.isNotEmpty()) {
            val fillInIntent = Intent().apply {
                action = "com.esadigitallabs.esago.ACTION_SHOW_COPY_DIALOG"
                putExtra("lecturer_name", lecturerName)
            }
            views.setOnClickFillInIntent(R.id.widget_list_item, fillInIntent)
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
