package org.dpdns.fanxiaogao05.chengxinyouyou;

import android.graphics.Color;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "SystemBarBackground")
public class SystemBarBackgroundPlugin extends Plugin {

    @PluginMethod
    public void setBackgroundColor(PluginCall call) {
        String color = call.getString("color");
        if (color == null) {
            call.reject("color is required");
            return;
        }

        final int parsedColor;
        try {
            parsedColor = Color.parseColor(color);
        } catch (IllegalArgumentException exception) {
            call.reject("invalid color");
            return;
        }

        getActivity().runOnUiThread(() -> {
            // 旧版 WebView 的安全区由原生容器承载，背景必须跟随当前 Web 页面主题。
            ((MainActivity) getActivity()).setSystemBarBackgroundColor(parsedColor);
            call.resolve();
        });
    }
}
