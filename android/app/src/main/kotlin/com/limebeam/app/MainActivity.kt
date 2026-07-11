package com.limebeam.app

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.util.Rational
import android.view.KeyEvent
import android.view.WindowInsets
import android.view.inputmethod.InputMethodManager
import com.limebeam.app.exoplayer.ExoPlayerController
import com.limebeam.app.exoplayer.ExoPlayerViewFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val pipChannel = "limebeam/pip"
    private val playerChannel = "limebeam/player"

    private lateinit var playerMethodChannel: MethodChannel
    private var mediaSession: MediaSession? = null

    /**
     * Fire TV shows the system keyboard as a modal overlay that Flutter's
     * TextField fails to dismiss on Back (flutter/flutter#52170) — the field
     * traps focus. When the IME is visible, consume Back to hide it instead of
     * popping the route. Guarded to API 30+ (where IME visibility is
     * queryable); older Fire OS and phones fall through to normal Back.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_BACK &&
            event.action == KeyEvent.ACTION_UP &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
        ) {
            val insets = window.decorView.rootWindowInsets
            if (insets != null && insets.isVisible(WindowInsets.Type.ime())) {
                val imm = getSystemService(InputMethodManager::class.java)
                imm?.hideSoftInputFromWindow(window.decorView.windowToken, 0)
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── PiP channel (unchanged) ──────────────────────────────────────────
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

        // ── Player / MediaSession channel ────────────────────────────────────
        playerMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            playerChannel,
        )
        playerMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Flutter pushes the current playing state so the OS always
                // sees the *intended* state (prevents Fire TV auto-resume).
                "setPlaying" -> {
                    val playing = call.arguments as? Boolean ?: false
                    updateMediaSessionState(playing)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        setupMediaSession()

        // ── ExoPlayer (SurfaceView) engine for LIVE on Android TV ────────────
        // Registers the control/event channels + the SurfaceView platform view
        // consumed by the Dart ExoPlayerEngine. Idle unless live plays on TV.
        ExoPlayerController.register(
            flutterEngine.dartExecutor.binaryMessenger,
            applicationContext,
        )
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "limebeam/exoplayer_view",
            ExoPlayerViewFactory(),
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        // Engine is being torn down (app quit): fully release the shared
        // ExoPlayer and drop the singleton so a relaunch builds a fresh one.
        // Reusing a released player across engine lifecycles crashes.
        ExoPlayerController.releaseShared()
    }

    // ── MediaSession ─────────────────────────────────────────────────────────

    private fun setupMediaSession() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return
        val session = MediaSession(this, "LimeBeam")
        session.setCallback(object : MediaSession.Callback() {
            override fun onPlay() {
                playerMethodChannel.invokeMethod("onPlay", null)
            }
            override fun onPause() {
                playerMethodChannel.invokeMethod("onPause", null)
            }
            override fun onStop() {
                playerMethodChannel.invokeMethod("onPause", null)
            }
        })
        // Start with STATE_PAUSED so Fire OS doesn't auto-resume before the
        // first track is loaded.
        applyPlaybackState(session, false)
        session.isActive = true
        mediaSession = session
    }

    private fun updateMediaSessionState(playing: Boolean) {
        mediaSession?.let { applyPlaybackState(it, playing) }
    }

    private fun applyPlaybackState(session: MediaSession, playing: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return
        val stateInt = if (playing) {
            PlaybackState.STATE_PLAYING
        } else {
            PlaybackState.STATE_PAUSED
        }
        session.setPlaybackState(
            PlaybackState.Builder()
                .setState(stateInt, PlaybackState.PLAYBACK_POSITION_UNKNOWN, 1f)
                .setActions(
                    PlaybackState.ACTION_PLAY or
                        PlaybackState.ACTION_PAUSE or
                        PlaybackState.ACTION_PLAY_PAUSE,
                )
                .build(),
        )
    }

    override fun onDestroy() {
        mediaSession?.release()
        mediaSession = null
        super.onDestroy()
    }

    // ── PiP ─────────────────────────────────────────────────────────────────

    private fun supportsPip(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun enterPip() {
        if (!supportsPip()) return
        val params = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .build()
        enterPictureInPictureMode(params)
    }

    /**
     * When Android transitions to PiP it calls [onPause], which normally tells
     * Flutter to stop rendering — producing a black window. By skipping the
     * super call while in PiP we keep Flutter's render loop alive and the video
     * texture stays visible inside the PiP window.
     */
    override fun onPause() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInPictureInPictureMode) {
            // Do NOT call super — Flutter must not pause its renderer.
            return
        }
        super.onPause()
    }

    override fun onPictureInPictureModeChanged(
        isInPipMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPipMode, newConfig)
        if (!isInPipMode) {
            // Exiting PiP — Flutter's lifecycle may be stale; trigger a resume
            // so the full-screen surface refreshes immediately.
            flutterEngine?.lifecycleChannel?.appIsResumed()
        }
    }
}
