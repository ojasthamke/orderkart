package com.example.orderkart

import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val win = window
                val disp = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    context.display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                }
                val modes = disp?.supportedModes
                var maxMode = modes?.firstOrNull()
                var maxRate = 0f
                modes?.forEach { mode ->
                    if (mode.refreshRate > maxRate) {
                        maxRate = mode.refreshRate
                        maxMode = mode
                    }
                }
                if (maxMode != null) {
                    val params = win.attributes
                    params.preferredDisplayModeId = maxMode.modeId
                    win.attributes = params
                }
            }
        } catch (_: Exception) {}
    }
}

