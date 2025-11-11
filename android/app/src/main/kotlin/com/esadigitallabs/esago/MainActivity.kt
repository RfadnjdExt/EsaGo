package com.esadigitallabs.esago

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.esadigitallabs.esago/widget"

    @RequiresApi(Build.VERSION_CODES.O)
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "requestPinWidget") {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val myProvider = ComponentName(context, ScheduleWidgetProvider::class.java)

                if (appWidgetManager.isRequestPinAppWidgetSupported) {
                    appWidgetManager.requestPinAppWidget(myProvider, null, null)
                    result.success(true)
                } else {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
