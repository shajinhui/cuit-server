package org.dpdns.fanxiaogao05.chengxin_youyou

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import org.json.JSONObject
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var widgetChannel: MethodChannel? = null
    private var widgetClientReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chengxin_youyou/desktop_widgets")
        widgetChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumeLaunch" -> {
                    widgetClientReady = true
                    val opened = intent?.action == ScheduleWidgetProvider.OPEN_SCHEDULE
                    if (opened) intent.action = Intent.ACTION_MAIN
                    result.success(opened)
                }
                "publish" -> {
                    val raw = call.arguments as? String
                    if (raw == null) result.error("invalid_snapshot", "课表摘要缺失", null)
                    else widgetWriter.execute {
                        try {
                            val data = JSONObject(raw)
                            require(data.optInt("version") == 1)
                            val saved = applicationContext.getSharedPreferences(ScheduleWidgetProvider.PREFERENCES, Context.MODE_PRIVATE)
                                .edit().putString(ScheduleWidgetProvider.SNAPSHOT_KEY, raw).commit()
                            check(saved)
                            ScheduleWidgetProvider.updateAll(applicationContext)
                            Handler(Looper.getMainLooper()).post { result.success(null) }
                        } catch (_: Exception) {
                            Handler(Looper.getMainLooper()).post { result.error("widget_storage", "保存桌面课表失败", null) }
                        }
                    }
                }
                "requestPin" -> {
                    val manager = AppWidgetManager.getInstance(this)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && manager.isRequestPinAppWidgetSupported) {
                        result.success(manager.requestPinAppWidget(ComponentName(this, ScheduleWidgetProvider::class.java), null, null))
                    } else result.success(false)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ScheduleWidgetProvider.OPEN_SCHEDULE && widgetClientReady) {
            intent.action = Intent.ACTION_MAIN
            widgetChannel?.invokeMethod("openSchedule", null)
        }
    }

    companion object {
        // SharedPreferences 落盘在后台执行，避免阻塞 Flutter 的平台线程。
        private val widgetWriter = Executors.newSingleThreadExecutor()
    }
}
