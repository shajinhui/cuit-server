package org.dpdns.fanxiaogao05.chengxin_youyou

import android.Manifest
import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone
import java.util.concurrent.Executors

/**
 * 直接把课表写进系统日历（CalendarContract），不再生成 ics 交给分享面板。
 *
 * 写入目标是一个由本应用创建的本地日历（ACCOUNT_TYPE_LOCAL），名字取学期名。
 * 同一学期重复导入时先按 CUSTOM_APP_URI 标记删掉上一次写入的日程，
 * 因此不会出现重复条目，也不会动用户自己日历里的东西。
 */
class SystemCalendarBridge(private val activity: MainActivity) {
    private val worker = Executors.newSingleThreadExecutor()
    private var pendingAccess: MethodChannel.Result? = null

    fun attach(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestAccess" -> requestAccess(result)
            "importEvents" -> importEvents(call, result)
            "openSettings" -> {
                openSettings()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasAccess(): Boolean =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(activity, Manifest.permission.WRITE_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestAccess(result: MethodChannel.Result) {
        if (hasAccess()) {
            result.success(true)
            return
        }
        // 只保留最近一次请求，避免面板反复点击时挂住多个回调。
        pendingAccess?.success(false)
        pendingAccess = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
            PERMISSION_REQUEST,
        )
    }

    /** @return 是否消费了本次权限回调。 */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        val result = pendingAccess ?: return true
        pendingAccess = null
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        result.success(granted)
        return true
    }

    private fun importEvents(call: MethodCall, result: MethodChannel.Result) {
        if (!hasAccess()) {
            result.error("permission_denied", "没有日历权限", null)
            return
        }
        val name = call.argument<String>("calendarName")?.takeIf { it.isNotBlank() } ?: DEFAULT_CALENDAR
        val marker = call.argument<String>("marker") ?: ""
        val events = call.argument<List<Map<String, Any?>>>("events").orEmpty()
        val resolver = activity.contentResolver
        val appPackage = activity.packageName
        val timeZone = TimeZone.getDefault().id

        worker.execute {
            try {
                val calendarId = ensureCalendar(resolver, name)
                if (marker.isNotEmpty()) {
                    // 只清理本应用写过的日程；用户在别的日历里的条目一律不动。
                    resolver.delete(
                        CalendarContract.Events.CONTENT_URI,
                        "${CalendarContract.Events.CALENDAR_ID}=? AND " +
                            "${CalendarContract.Events.CUSTOM_APP_URI} LIKE ?",
                        arrayOf(calendarId.toString(), "$marker%"),
                    )
                }
                var written = 0
                for (event in events) {
                    val start = (event["start"] as? Number)?.toLong() ?: continue
                    val end = (event["end"] as? Number)?.toLong() ?: continue
                    if (end <= start) continue
                    val minutes = (event["reminderMinutes"] as? Number)?.toInt() ?: 0
                    val uid = event["uid"] as? String ?: ""
                    val values = ContentValues().apply {
                        put(CalendarContract.Events.CALENDAR_ID, calendarId)
                        put(CalendarContract.Events.TITLE, event["title"] as? String ?: "课程")
                        put(CalendarContract.Events.DESCRIPTION, event["detail"] as? String ?: "")
                        put(
                            CalendarContract.Events.EVENT_LOCATION,
                            event["location"] as? String ?: "",
                        )
                        put(CalendarContract.Events.DTSTART, start)
                        put(CalendarContract.Events.DTEND, end)
                        put(CalendarContract.Events.EVENT_TIMEZONE, timeZone)
                        put(CalendarContract.Events.EVENT_END_TIMEZONE, timeZone)
                        put(CalendarContract.Events.HAS_ALARM, if (minutes > 0) 1 else 0)
                        put(CalendarContract.Events.STATUS, CalendarContract.Events.STATUS_CONFIRMED)
                        put(
                            CalendarContract.Events.AVAILABILITY,
                            CalendarContract.Events.AVAILABILITY_BUSY,
                        )
                        if (marker.isNotEmpty()) {
                            put(CalendarContract.Events.CUSTOM_APP_URI, "$marker#$uid")
                            put(CalendarContract.Events.CUSTOM_APP_PACKAGE, appPackage)
                        }
                    }
                    val inserted = resolver.insert(CalendarContract.Events.CONTENT_URI, values)
                        ?: continue
                    if (minutes > 0) {
                        val eventId = ContentUris.parseId(inserted)
                        resolver.insert(
                            CalendarContract.Reminders.CONTENT_URI,
                            ContentValues().apply {
                                put(CalendarContract.Reminders.EVENT_ID, eventId)
                                put(CalendarContract.Reminders.MINUTES, minutes)
                                put(
                                    CalendarContract.Reminders.METHOD,
                                    CalendarContract.Reminders.METHOD_ALERT,
                                )
                            },
                        )
                    }
                    written++
                }
                post { result.success(written) }
            } catch (error: Exception) {
                post {
                    result.error("calendar_write", "写入系统日历失败：${error.message}", null)
                }
            }
        }
    }

    /** 找到本应用创建的本地日历，没有就建一个。 */
    private fun ensureCalendar(resolver: ContentResolver, displayName: String): Long {
        val projection = arrayOf(CalendarContract.Calendars._ID)
        resolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            "${CalendarContract.Calendars.ACCOUNT_NAME}=? AND " +
                "${CalendarContract.Calendars.ACCOUNT_TYPE}=? AND " +
                "${CalendarContract.Calendars.NAME}=?",
            arrayOf(ACCOUNT_NAME, CalendarContract.ACCOUNT_TYPE_LOCAL, displayName),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getLong(0)
        }
        val values = ContentValues().apply {
            put(CalendarContract.Calendars.ACCOUNT_NAME, ACCOUNT_NAME)
            put(CalendarContract.Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            put(CalendarContract.Calendars.NAME, displayName)
            put(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, displayName)
            put(CalendarContract.Calendars.CALENDAR_COLOR, CALENDAR_COLOR)
            put(
                CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
                CalendarContract.Calendars.CAL_ACCESS_OWNER,
            )
            put(CalendarContract.Calendars.OWNER_ACCOUNT, ACCOUNT_NAME)
            put(CalendarContract.Calendars.CALENDAR_TIME_ZONE, TimeZone.getDefault().id)
            put(CalendarContract.Calendars.VISIBLE, 1)
            put(CalendarContract.Calendars.SYNC_EVENTS, 1)
        }
        // 本地日历必须带上同步适配器参数，否则系统拒绝写入。
        val uri: Uri = CalendarContract.Calendars.CONTENT_URI.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, ACCOUNT_NAME)
            .appendQueryParameter(
                CalendarContract.Calendars.ACCOUNT_TYPE,
                CalendarContract.ACCOUNT_TYPE_LOCAL,
            )
            .build()
        val inserted = resolver.insert(uri, values)
            ?: throw IllegalStateException("无法在本机创建日历")
        return ContentUris.parseId(inserted)
    }

    private fun openSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", activity.packageName, null),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
    }

    private fun post(block: () -> Unit) {
        Handler(Looper.getMainLooper()).post(block)
    }

    companion object {
        private const val PERMISSION_REQUEST = 0xCA1
        private const val ACCOUNT_NAME = "成信友友"
        private const val DEFAULT_CALENDAR = "成信友友课表"
        private const val CALENDAR_COLOR = 0xFF0878E8.toInt()
    }
}
