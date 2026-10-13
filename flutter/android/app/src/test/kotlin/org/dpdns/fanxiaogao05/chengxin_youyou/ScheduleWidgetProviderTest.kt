package org.dpdns.fanxiaogao05.chengxin_youyou

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import java.io.File
import java.time.Instant
import org.json.JSONObject

/** 不下载安卓模拟器；在 Android 资源环境中真正应用 RemoteViews。 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ScheduleWidgetProviderTest {
    private val context = RuntimeEnvironment.getApplication()

    private fun create(
        raw: String,
        provider: Class<out AppWidgetProvider> = ScheduleWidgetProvider::class.java,
    ): Pair<Int, AppWidgetManager> {
        context.getSharedPreferences(ScheduleWidgetProvider.PREFERENCES, Context.MODE_PRIVATE)
            .edit().putString(ScheduleWidgetProvider.SNAPSHOT_KEY, raw).commit()
        val manager = AppWidgetManager.getInstance(context)
        val id = Shadows.shadowOf(manager).createWidget(provider, R.layout.schedule_widget)
        return Pair(id, manager)
    }

    private fun fixture(): String = File(System.getProperty("widget.fixture")).readText()

    @Test fun coursesResizeAndClickOpenTheSchedule() {
        val now = Instant.parse("2026-10-08T00:19:00Z").toEpochMilli()
        val (id, manager) = create(fixture())
        manager.updateAppWidgetOptions(id, Bundle().apply {
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 300)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 340)
        })
        ScheduleWidgetProvider.updateAll(context, now)
        var view = Shadows.shadowOf(manager).getViewFor(id)
        assertEquals(4, view.findViewById<LinearLayout>(R.id.widget_courses).childCount)
        assertEquals("今日课程", view.findViewById<TextView>(R.id.widget_title).text.toString())
        manager.updateAppWidgetOptions(id, Bundle().apply {
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 160)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
        })
        ScheduleWidgetProvider.updateAll(context, now)
        view = Shadows.shadowOf(manager).getViewFor(id)
        assertEquals(1, view.findViewById<LinearLayout>(R.id.widget_courses).childCount)
        assertEquals("下一节课", view.findViewById<TextView>(R.id.widget_title).text.toString())
        view.findViewById<LinearLayout>(R.id.widget_root).performClick()
        val opened = Shadows.shadowOf(context).nextStartedActivity
        assertEquals(ScheduleWidgetProvider.OPEN_SCHEDULE, opened.action)
    }

    /** 小、中、大是三个独立组件，内容都出自同一套渲染逻辑，且一次刷新覆盖全部尺寸。 */
    @Test fun sizeVariantsRenderFromTheSameProvider() {
        val now = Instant.parse("2026-10-08T00:19:00Z").toEpochMilli()
        val (smallId, manager) = create(fixture(), ScheduleWidgetSmallProvider::class.java)
        val (mediumId, _) = create(fixture())
        val (largeId, _) = create(fixture(), ScheduleWidgetLargeProvider::class.java)
        fun options(id: Int, width: Int, height: Int) = manager.updateAppWidgetOptions(id, Bundle().apply {
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, width)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, height)
        })
        options(smallId, 160, 130)
        options(mediumId, 300, 340)
        options(largeId, 320, 420)
        ScheduleWidgetProvider.updateAll(context, now)
        val small = Shadows.shadowOf(manager).getViewFor(smallId)
        assertEquals("下一节课", small.findViewById<TextView>(R.id.widget_title).text.toString())
        assertEquals(1, small.findViewById<LinearLayout>(R.id.widget_courses).childCount)
        val medium = Shadows.shadowOf(manager).getViewFor(mediumId)
        assertEquals("今日课程", medium.findViewById<TextView>(R.id.widget_title).text.toString())
        assertEquals(4, medium.findViewById<LinearLayout>(R.id.widget_courses).childCount)
        // 大卡片上限能容纳 5 节，样本当天只有 4 节。
        val large = Shadows.shadowOf(manager).getViewFor(largeId)
        assertEquals(4, large.findViewById<LinearLayout>(R.id.widget_courses).childCount)
        assertEquals("三种尺寸必须被同一次刷新覆盖", 3, ScheduleWidgetProvider.widgetIds(context, manager).size)
    }

    @Test fun endingClassesAndMidnightSelectTheCorrectDay() {
        val now = Instant.parse("2026-10-08T02:00:00Z").toEpochMilli()
        val (id, manager) = create(fixture())
        manager.updateAppWidgetOptions(id, Bundle().apply {
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 300)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 340)
        })
        ScheduleWidgetProvider.updateAll(context, now)
        assertEquals(2, Shadows.shadowOf(manager).getViewFor(id).findViewById<LinearLayout>(R.id.widget_courses).childCount)
        ScheduleWidgetProvider.updateAll(context, Instant.parse("2026-10-08T16:00:00Z").toEpochMilli())
        assertTrue(Shadows.shadowOf(manager).getViewFor(id).findViewById<TextView>(R.id.widget_empty).text.contains("没有课程"))
    }

    @Test fun logoutAndBrokenStorageDoNotShowPreviousCourses() {
        val (id, manager) = create("{\"version\":1,\"status\":\"loggedOut\",\"message\":\"登录后查看今日课程\",\"days\":[]}")
        var view = Shadows.shadowOf(manager).getViewFor(id)
        assertEquals(0, view.findViewById<LinearLayout>(R.id.widget_courses).childCount)
        assertEquals("登录后查看今日课程", view.findViewById<TextView>(R.id.widget_empty).text.toString())
        context.getSharedPreferences(ScheduleWidgetProvider.PREFERENCES, Context.MODE_PRIVATE).edit()
            .putString(ScheduleWidgetProvider.SNAPSHOT_KEY, "broken").commit()
        ScheduleWidgetProvider.updateAll(context)
        view = Shadows.shadowOf(manager).getViewFor(id)
        assertEquals(0, view.findViewById<LinearLayout>(R.id.widget_courses).childCount)
        assertEquals("登录后查看今日课程", view.findViewById<TextView>(R.id.widget_empty).text.toString())
    }

    @Test fun minimumHeightFitsACourseAndUnknownVersionsAreCleared() {
        val (id, manager) = create(fixture())
        manager.updateAppWidgetOptions(id, Bundle().apply {
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 160)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 160)
        })
        ScheduleWidgetProvider.updateAll(context, Instant.parse("2026-10-08T00:19:00Z").toEpochMilli())
        val view = Shadows.shadowOf(manager).getViewFor(id)
        val density = context.resources.displayMetrics.density
        val size = (160 * density).toInt()
        view.measure(View.MeasureSpec.makeMeasureSpec(size, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(size, View.MeasureSpec.EXACTLY))
        view.layout(0, 0, size, size)
        val courses = view.findViewById<LinearLayout>(R.id.widget_courses)
        assertTrue("最小卡片应显示完整的时间与地点", courses.getChildAt(0).bottom <= courses.height)
        val incompatible = JSONObject(fixture()).put("version", 999).toString()
        context.getSharedPreferences(ScheduleWidgetProvider.PREFERENCES, Context.MODE_PRIVATE).edit()
            .putString(ScheduleWidgetProvider.SNAPSHOT_KEY, incompatible).commit()
        ScheduleWidgetProvider.updateAll(context)
        assertEquals(0, Shadows.shadowOf(manager).getViewFor(id).findViewById<LinearLayout>(R.id.widget_courses).childCount)
    }
}
