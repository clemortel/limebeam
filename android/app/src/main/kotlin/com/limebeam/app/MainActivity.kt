package com.limebeam.app

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Hosts a tiny method channel for OS Picture-in-Picture (Android only).
/// Implemented natively to avoid third-party PiP plugins that still reference
/// the removed v1-embedding `Registrar`.
class MainActivity : FlutterActivity() {
    private val pipChannel = "limebeam/pip"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(supportsPip())
                    "enter" -> {
                        enterPip()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun supportsPip(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(
                PackageManager.FEATURE_PICTURE_IN_PICTURE,
            )

    private fun enterPip() {
        if (!supportsPip()) return
        val params = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .build()
        enterPictureInPictureMode(params)
    }
}
