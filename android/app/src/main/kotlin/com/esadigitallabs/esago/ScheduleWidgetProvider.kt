package com.esadigitallabs.esago

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

class ScheduleWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val PREF_DATE_KEY = "widget_current_date"
        const val ACTION_CHANGE_DATE = "com.esadigitallabs.esago.ACTION_CHANGE_DATE"
        const val EXTRA_DATE_OFFSET = "com.esadigitallabs.esago.EXTRA_DATE_OFFSET"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_CHANGE_DATE) {
            val offset = intent.getIntExtra(EXTRA_DATE_OFFSET, 0)
            if (offset != 0) {
                val widgetData = HomeWidgetPlugin.getData(context)
                val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                val currentDateStr = widgetData.getString(PREF_DATE_KEY, sdf.format(Calendar.getInstance().time))
                val calendar = Calendar.getInstance()
                try {
                    calendar.time = sdf.parse(currentDateStr)!!
                } catch (e: Exception) { /* Use today */ }
                
                calendar.add(Calendar.DATE, offset)
                val newDateStr = sdf.format(calendar.time)
                
                widgetData.edit().putString(PREF_DATE_KEY, newDateStr).apply()

                val appWidgetManager = AppWidgetManager.getInstance(context)
                val componentName = android.content.ComponentName(context, ScheduleWidgetProvider::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_schedule_list)
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
        } else {
            super.onReceive(context, intent)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            updateWidgetView(context, appWidgetManager, widgetId, widgetData)
        }
    }

    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val widgetData = HomeWidgetPlugin.getData(context)
        updateWidgetView(context, appWidgetManager, appWidgetId, widgetData)
    }

    private fun updateWidgetView(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, widgetData: SharedPreferences) {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val heightInDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
        val widthInDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val density = context.resources.displayMetrics.density

        val targetWidth = (widthInDp * density).toInt()
        val targetHeight = (heightInDp * density).toInt()

        val isLargeLayout = heightInDp > 150
        val layoutId = if (isLargeLayout) R.layout.widget_layout_large else R.layout.widget_layout
        val views = RemoteViews(context.packageName, layoutId)

        if (targetWidth > 0 && targetHeight > 0) {
            val backgroundResId = if (widthInDp > heightInDp) {
                R.drawable.background_horizontal
            } else {
                R.drawable.background_vertical
            }
            val bitmap = BitmapFactory.decodeResource(context.resources, backgroundResId)
            val cornerRadiusInPx = 16 * density
            val finalBitmap = getRoundedBitmapCrop(bitmap, targetWidth, targetHeight, cornerRadiusInPx)
            views.setImageViewBitmap(R.id.widget_image, finalBitmap)
        }

        if (isLargeLayout) {
            val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val displaySdf = SimpleDateFormat("EEE, d MMM", Locale.forLanguageTag("in-ID"))
            val currentDateStr = widgetData.getString(PREF_DATE_KEY, sdf.format(Calendar.getInstance().time))
            var date = Calendar.getInstance().time
            try {
                date = sdf.parse(currentDateStr)!!
            } catch (e: Exception) {}
            views.setTextViewText(R.id.widget_header_date, displaySdf.format(date))

            val prevIntent = Intent(context, ScheduleWidgetProvider::class.java).apply {
                action = ACTION_CHANGE_DATE
                putExtra(EXTRA_DATE_OFFSET, -1)
            }
            val prevPendingIntent = PendingIntent.getBroadcast(context, System.currentTimeMillis().toInt() + 1, prevIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_button_prev, prevPendingIntent)

            val nextIntent = Intent(context, ScheduleWidgetProvider::class.java).apply {
                action = ACTION_CHANGE_DATE
                putExtra(EXTRA_DATE_OFFSET, 1)
            }
            val nextPendingIntent = PendingIntent.getBroadcast(context, System.currentTimeMillis().toInt() + 2, nextIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_button_next, nextPendingIntent)

            val intent = Intent(context, ScheduleWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_schedule_list, intent)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_schedule_list)

            val appIntent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(context, 0, appIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setPendingIntentTemplate(R.id.widget_schedule_list, pendingIntent)

        } else {
            val course = widgetData.getString("next_schedule_course", "Masuk untuk melihat jadwal")
            val time = widgetData.getString("next_schedule_time", "--:--")
            val room = widgetData.getString("next_schedule_room", "")
            views.setTextViewText(R.id.widget_next_schedule_course, course)
            val details = if (room?.isNotEmpty() == true) "$room • $time" else time
            views.setTextViewText(R.id.widget_details, details)
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun getRoundedBitmapCrop(
        original: Bitmap, 
        targetWidth: Int, 
        targetHeight: Int, 
        cornerRadius: Float
    ): Bitmap {
        if (targetWidth <= 0 || targetHeight <= 0) {
            return original
        }
        
        val scaleX = targetWidth.toFloat() / original.width
        val scaleY = targetHeight.toFloat() / original.height
        val scale = max(scaleX, scaleY)
        
        val scaledWidth = (original.width * scale).toInt()
        val scaledHeight = (original.height * scale).toInt()
        
        val scaledBitmap = Bitmap.createScaledBitmap(original, scaledWidth, scaledHeight, true)
        
        var xOffset = (scaledWidth - targetWidth) / 2
        var yOffset = (scaledHeight - targetHeight) / 2
        
        xOffset = max(0, xOffset)
        yOffset = max(0, yOffset)
        
        val cropWidth = min(targetWidth, scaledWidth - xOffset)
        val cropHeight = min(targetHeight, scaledHeight - yOffset)
        
        val croppedBitmap = Bitmap.createBitmap(
            scaledBitmap, 
            xOffset, 
            yOffset, 
            cropWidth, 
            cropHeight
        )
        
        val output = Bitmap.createBitmap(cropWidth, cropHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint()
        val rectF = RectF(0f, 0f, cropWidth.toFloat(), cropHeight.toFloat())
        
        paint.isAntiAlias = true
        canvas.drawRoundRect(rectF, cornerRadius, cornerRadius, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(croppedBitmap, 0f, 0f, paint)

        if (scaledBitmap != original) scaledBitmap.recycle()
        if (croppedBitmap != output) croppedBitmap.recycle()
        
        return output
    }
}
