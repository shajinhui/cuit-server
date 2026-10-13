package com.oscillator.native_collator

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.text.Collator
import java.util.*

class NativeCollatorPlugin: FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var channel : MethodChannel

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "native_collator")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
    if (call.method == "sortIndices") {
      val input = call.argument<List<String>>("input") ?: emptyList()
      val localeStr = call.argument<String>("locale") ?: "en"
      val collator = Collator.getInstance(Locale.forLanguageTag(localeStr))
      // 与 JS 稳定排序一致；通道仅返回索引，原字符串保留在 Dart。
      val sorted = input.indices.sortedWith { left, right ->
        val compared = collator.compare(input[left], input[right])
        if (compared == 0) left.compareTo(right) else compared
      }
      result.success(sorted)
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}