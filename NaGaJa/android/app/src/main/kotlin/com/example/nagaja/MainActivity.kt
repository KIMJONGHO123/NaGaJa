package com.example.nagaja

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.nagaja.app/background_audio"
    private var alarmRingtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService"      -> { startSilent(); result.success(null) }
                    "stopService"       -> { stopSilent(); result.success(null) }
                    "playAlarmSound"    -> { playAlarmSound(); result.success(null) }
                    "stopAlarmSound"    -> { stopAlarmSound(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        requestNotificationPermission()
    }

    // Android 13(API 33)부터 알림 표시에 런타임 권한 요청 필요
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    0
                )
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

    // RingtoneManager로 기기 기본 알람음 재생 (content:// URI 지원)
    private fun playAlarmSound() {
        stopAlarmSound()
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
        alarmRingtone = RingtoneManager.getRingtone(applicationContext, uri)
        alarmRingtone?.play()
    }

    private fun stopAlarmSound() {
        alarmRingtone?.stop()
        alarmRingtone = null
    }
}
