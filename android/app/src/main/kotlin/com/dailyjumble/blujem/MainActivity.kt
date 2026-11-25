package com.dailyjumble.blujem

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // A real buzz for the shake: Flutter's haptics play the system touch
        // feedback, which many phones keep faint or switched off.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "blujem/haptics").setMethodCallHandler { call, result ->
            // Buzz, pause, buzz for a shuffle; three pulses, the last long, for a win.
            val (timings, amplitudes) = when (call.method) {
                "shuffle" -> longArrayOf(0, 90, 70, 140) to intArrayOf(0, 255, 0, 255)
                "win" -> longArrayOf(0, 110, 80, 110, 80, 320) to intArrayOf(0, 255, 0, 255, 0, 255)
                // A hint: short, pause, short, and softer than the shake.
                "hint" -> longArrayOf(0, 45, 70, 45) to intArrayOf(0, 170, 0, 140)
                else -> return@setMethodCallHandler result.notImplemented()
            }
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION") getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
            } else {
                @Suppress("DEPRECATION") vibrator.vibrate(timings, -1)
            }
            result.success(true)
        }
        // Hands a downloaded, checked update to Android's installer.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "blujem/updates").setMethodCallHandler { call, result ->
            when (call.method) {
                "install" -> {
                    val apk = File(call.argument<String>("path") ?: "")
                    val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
                    startActivity(
                        Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
