package com.cybernie.final_project

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Screen sharing: Android only lets an app capture the screen while
        // it runs a "screen capture" foreground service (with a notification).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cybernie/screen_capture")
            .setMethodCallHandler { call, result ->
                val intent = Intent(this, ScreenCaptureService::class.java)
                when (call.method) {
                    "start" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
