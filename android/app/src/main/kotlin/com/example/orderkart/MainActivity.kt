package com.example.orderkart

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val PLAYSTORE_CHANNEL = "com.orderkart.app/playstore"

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
                val maxMode = disp?.supportedModes?.maxByOrNull { it.refreshRate }
                if (maxMode != null) {
                    val params = win.attributes
                    params.preferredDisplayModeId = maxMode.modeId
                    win.attributes = params
                }
            }
        } catch (_: Exception) {}

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAYSTORE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openPlayStoreDirectly") {
                val pkg = call.argument<String>("packageName") ?: packageName
                try {
                    // Force the intent directly into Google Play Store without showing app chooser or other apps
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg")).apply {
                        setPackage("com.android.vending")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    // Fallback to standard market intent if Google Play Store app is absent or disabled
                    try {
                        val fallbackIntent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg")).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(fallbackIntent)
                        result.success(true)
                    } catch (e2: Exception) {
                        result.success(false)
                    }
                } catch (e: Exception) {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

