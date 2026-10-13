package org.dpdns.fanxiaogao05.chengxin_youyou

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** 桌面只读取 Dart 已算好的本学期摘要，不访问教务接口或登录信息。
 *  对小、大两个入口保持可继承：三者只有默认格数与调整范围不同，渲染逻辑共用这一份。 */
open class ScheduleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        updateAll(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, id: Int, options: Bundle
    ) {
        updateAll(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in listOf(
                ACTION_REFRESH, Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_MY_PACKAGE_REPLACED
            )) updateAll(context)
    }

    override fun onDisabled(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        // 只是某一个尺寸被移除时不能停掉闹钟，其余尺寸可能还挂在桌面上。
        if (providerClasses.any { manager.getAppWidgetIds(ComponentName(context, it)).isNotEmpty() }) return
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarm.cancel(refreshIntent(context))
    }

    companion object {
        const val OPEN_SCHEDULE = "org.dpdns.fanxiaogao05.chengxin.flutter.OPEN_WIDGET_SCHEDULE"
        private const val ACTION_REFRESH = "org.dpdns.fanxiaogao05.chengxin.flutter.WIDGET_REFRESH"
        const val PREFERENCES = "desktop_schedule"
        const val SNAPSHOT_KEY = "snapshot"
        private val schoolZone = TimeZone.getTimeZone("Asia/Shanghai")

        /** 小、中、大在系统里是三个独立组件，刷新与统计都必须逐个枚举。 */
        val providerClasses = listOf(
            ScheduleWidgetSmallProvider::class.java,
            ScheduleWidgetProvider::class.java,
            ScheduleWidgetLargeProvider::class.java,
        )

        fun widgetIds(context: Context, manager: AppWidgetManager): IntArray = providerClasses
            .flatMap { manager.getAppWidgetIds(ComponentName(context, it)).toList() }
            .toIntArray()

        fun updateAll(context: Context, now: Long = System.currentTimeMillis()) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = widgetIds(context, manager)
            if (ids.isEmpty()) return
            val raw = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .getString(SNAPSHOT_KEY, null)
            val snapshot = try {
                JSONObject(raw ?: "{}").takeIf { it.optInt("version") == 1 } ?: JSONObject()
            } catch (_: Exception) { JSONObject() }
            val date = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).apply { timeZone = schoolZone }.format(Date(now))
            val days = snapshot.optJSONArray("days")
            var today: JSONObject? = null
            if (days != null) for (index in 0 until days.length()) {
                val day = days.optJSONObject(index) ?: continue
                if (day.optString("date") == date) { today = day; break }
            }
            val allCourses = mutableListOf<JSONObject>()
            val courses = today?.optJSONArray("courses")
            if (courses != null) for (index in 0 until courses.length()) {
                courses.optJSONObject(index)?.let { allCourses.add(it) }
            }
            val remaining = allCourses.filter { it.optLong("endMillis") == 0L || it.optLong("endMillis") > now }
            for (id in ids) {
                val options = manager.getAppWidgetOptions(id)
                val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 280)
                val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 160)
                val compact = width < 220
                // 先为边距、标题、周次和页脚留出空间，再计算可完整显示的行数。
                val limit = if (compact) 1 else ((height - 96) / 60).coerceIn(1, 5)
                val views = RemoteViews(context.packageName, R.layout.schedule_widget)
                views.setTextViewText(R.id.widget_title, if (compact) "下一节课" else "今日课程")
                val displayDate = SimpleDateFormat("M月d日", Locale.CHINA).apply { timeZone = schoolZone }.format(Date(now))
                views.setTextViewText(R.id.widget_date, displayDate)
                val weekday = SimpleDateFormat("EEEE", Locale.CHINA).apply { timeZone = schoolZone }.format(Date(now))
                val week = today?.optInt("week", 0) ?: 0
                views.setTextViewText(R.id.widget_week, "$weekday${if (week > 0) " · 第 $week 周" else ""}")
                val message = when {
                    snapshot.optString("status") != "ready" -> snapshot.optString("message", "登录后查看今日课程")
                    today == null -> "当前不在已同步的教学周内"
                    allCourses.isEmpty() -> "今天没有课程，好好休息"
                    remaining.isEmpty() -> "今日课程已结束"
                    else -> ""
                }
                views.setTextViewText(R.id.widget_empty, message)
                views.setViewVisibility(R.id.widget_empty, if (message.isEmpty()) View.GONE else View.VISIBLE)
                views.removeAllViews(R.id.widget_courses)
                if (message.isEmpty()) for (course in remaining.take(limit)) {
                    val row = RemoteViews(context.packageName, R.layout.schedule_widget_course)
                    row.setTextViewText(R.id.widget_course_name, course.optString("name"))
                    val ongoing = course.optLong("startMillis") > 0 && course.optLong("startMillis") <= now && course.optLong("endMillis") > now
                    row.setTextViewText(R.id.widget_course_time, course.optString("time") + if (ongoing) " · 进行中" else "")
                    row.setTextViewText(R.id.widget_course_room, course.optString("room", "地点待定"))
                    views.addView(R.id.widget_courses, row)
                }
                views.setTextViewText(R.id.widget_footer, if (remaining.size > limit && message.isEmpty())
                    "还有 ${remaining.size - limit} 节 · 点击查看课表" else "成信友友 · 点击查看课表")
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = OPEN_SCHEDULE
                    flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val click = PendingIntent.getActivity(context, 0, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.widget_root, click)
                manager.updateAppWidget(id, views)
            }
            // 使用非精确闹钟，不申请精确闹钟权限；系统省电可能延后刷新。
            val midnight = Calendar.getInstance(schoolZone).apply {
                timeInMillis = now
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val boundaries = allCourses.flatMap { listOf(it.optLong("startMillis"), it.optLong("endMillis")) }
            val next = (boundaries.filter { it > now } + midnight).minOrNull() ?: midnight
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
                .set(AlarmManager.RTC, next, refreshIntent(context))
        }

        private fun refreshIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
            context, 1, Intent(context, ScheduleWidgetProvider::class.java).setAction(ACTION_REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}

/** 小尺寸入口（默认 2×2），与中、大并列显示在系统小组件列表。 */
class ScheduleWidgetSmallProvider : ScheduleWidgetProvider()

/** 大尺寸入口（默认 4×4）。 */
class ScheduleWidgetLargeProvider : ScheduleWidgetProvider()
