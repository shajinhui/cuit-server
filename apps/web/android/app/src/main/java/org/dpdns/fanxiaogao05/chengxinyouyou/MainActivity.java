package org.dpdns.fanxiaogao05.chengxinyouyou;

import android.content.res.Configuration;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.view.WindowCompat;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {

    private int systemBarBackgroundColor = Color.rgb(251, 252, 249);

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        registerPlugin(SystemBarBackgroundPlugin.class);
        super.onCreate(savedInstanceState);

        WindowCompat.enableEdgeToEdge(getWindow());
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
