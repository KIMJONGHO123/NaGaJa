package com.example.nagaja

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.nagaja.app/background_audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> { startSilent(); result.success(null) }
                    "stopService"  -> { stopSilent(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startSilent() {
        val intent = Intent(this, SilentAudioForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
        else startService(intent)
    }

    private fun stopSilent() {
        stopService(Intent(this, SilentAudioForegroundService::class.java))
    }
}
