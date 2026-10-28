package com.scriptbrowser.script_browser

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        internal var castChannel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "script_browser/cast_background")
        castChannel = channel
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        // Notification permission is optional for starting an FGS, but enables its Stop action in the drawer.
                        val prefs = getPreferences(MODE_PRIVATE)
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED &&
                            !prefs.getBoolean("askedCastNotification", false)) {
                            prefs.edit().putBoolean("askedCastNotification", true).apply()
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4101)
                        }
                        val intent = Intent(this, CastForegroundService::class.java)
                            .putExtra("deviceName", call.argument<String>("deviceName") ?: "TV")
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, CastForegroundService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("CAST_BACKGROUND", "Could not enable background casting: ${error.javaClass.simpleName}", null)
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        castChannel?.setMethodCallHandler(null)
        castChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
