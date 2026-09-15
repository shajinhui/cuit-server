package org.dpdns.fanxiaogao05.chengxinyouyou;

import android.content.res.Configuration;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.View;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.view.WindowCompat;
import androidx.core.splashscreen.SplashScreen;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {

    private static final int SCHEDULE_BACKGROUND_COLOR = Color.rgb(201, 213, 231);
    private static final long MAX_SPLASH_SCREEN_DURATION_MS = 4_000L;

    private int systemBarBackgroundColor = SCHEDULE_BACKGROUND_COLOR;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        SplashScreen splashScreen = SplashScreen.installSplashScreen(this);
        long splashScreenDeadline = SystemClock.uptimeMillis() + MAX_SPLASH_SCREEN_DURATION_MS;

        registerPlugin(SystemBarBackgroundPlugin.class);
        super.onCreate(savedInstanceState);

        // 系统启动页结束后 WebView 还没有首帧时，默认背景会短暂露出白色。
        // 保持启动页到本地页面完成加载，并设置相同的课表底色作为兜底；超时后主动放行，
        // 避免资源异常时把用户永久留在启动页。
        if (bridge != null && bridge.getWebView() != null) {
            bridge.getWebView().setBackgroundColor(SCHEDULE_BACKGROUND_COLOR);
        }
        splashScreen.setKeepOnScreenCondition(() ->
            SystemClock.uptimeMillis() < splashScreenDeadline
                && (bridge == null
                    || bridge.getWebView() == null
                    || bridge.getWebView().getProgress() < 100)
        );

        // Android 15+ 会强制 edge-to-edge，交给 Capacitor SystemBars 根据真实窗口
        // inset 注入安全区。旧系统继续使用系统默认的非全屏布局，避免旧版 WebView
        // 取不到 CSS safe-area 时把页面顶到状态栏下面。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            WindowCompat.enableEdgeToEdge(getWindow());
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            getWindow().setStatusBarContrastEnforced(false);
            getWindow().setNavigationBarContrastEnforced(false);
        }
        normalizeWebViewTypography();
        applySystemBarBackgroundColor();
    }

    public void setSystemBarBackgroundColor(int color) {
        systemBarBackgroundColor = color;
        applySystemBarBackgroundColor();
    }

    private void applySystemBarBackgroundColor() {
        getWindow().getDecorView().setBackgroundColor(systemBarBackgroundColor);

        // WebView 140 以前 Capacitor 会给父容器添加安全区 padding；同步父容器颜色可避免露出白边。
        if (bridge != null && bridge.getWebView() != null) {
            View parent = (View) bridge.getWebView().getParent();
            parent.setBackgroundColor(systemBarBackgroundColor);
        }
    }

    private void normalizeWebViewTypography() {
        if (bridge == null || bridge.getWebView() == null) {
            return;
        }

        // 保持网页按 CSS 中声明的字号渲染，避免系统字体缩放把整套界面纵向撑大。
        bridge.getWebView().getSettings().setTextZoom(100);
    }

    @Override
    public void onConfigurationChanged(@NonNull Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        normalizeWebViewTypography();
        applySystemBarBackgroundColor();
    }
}
