package com.rix19.betacloud.bc_transporter

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val tvChannel = "bc_transporter/tv";

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, tvChannel).setMethodCallHandler { call, result ->
            if (call.method == "isTv") {
                result.success(isTelevisionDevice());
            } else {
                result.notImplemented();
            }
        };
    }

    private fun isTelevisionDevice(): Boolean {
        try {
            val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager;
            if (uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) {
                return true;
            }
        } catch (e: Exception) { /* ignore */ }
        try {
            val pm = packageManager;
            if (pm.hasSystemFeature("android.hardware.type.television")) return true;
            if (pm.hasSystemFeature("amazon.hardware.fire_tv")) return true;
        } catch (e: Exception) { /* ignore */ }
        try {
            val model = Build.MODEL ?: "";
            if (model.startsWith("AFT")) return true; // Amazon Fire TV
        } catch (e: Exception) { /* ignore */ }
        return false;
    }
}
