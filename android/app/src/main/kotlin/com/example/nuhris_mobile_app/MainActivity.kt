package com.example.nuhris_mobile_app

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Every NUHRIS screen shows employee HR data: block screenshots and
        // screen recording, and show a blank preview in the Recents screen.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nuhris/security")
            .setMethodCallHandler { call, result ->
                if (call.method != "inspect") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                // File and socket probes must not run on the main thread.
                Thread {
                    val report: Map<String, Any?>? = try {
                        DeviceIntegrity(applicationContext).inspect()
                    } catch (e: Exception) {
                        null
                    }
                    Handler(Looper.getMainLooper()).post {
                        if (report == null) {
                            result.error("inspect_failed", null, null)
                        } else {
                            result.success(report)
                        }
                    }
                }.start()
            }
    }
}
