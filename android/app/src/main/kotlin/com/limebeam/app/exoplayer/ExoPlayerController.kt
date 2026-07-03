package com.limebeam.app.exoplayer

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native ExoPlayer (androidx.media3) bridged to the Dart `ExoPlayerEngine`.
 *
 * Mirrors the iOS `AVPlayerEngineController`: one shared [ExoPlayer] is driven
 * by a MethodChannel and observed for state, which is pushed over an
 * EventChannel using the same event payload shape the Dart side parses
 * (`{"event": ..., "value"/"message": ...}`). The platform view
 * ([ExoPlayerPlatformView]) binds its SurfaceView to this same player, so video
 * is composited by SurfaceFlinger as a hardware overlay (not the app GPU).
 *
 * Only used for LIVE playback on Android TV (chosen in Dart). VOD and phones
 * keep media_kit, so this player stays idle otherwise.
 */
class ExoPlayerController private constructor(context: Context) :
    EventChannel.StreamHandler, Player.Listener {

    companion object {
        @Volatile
        private var instance: ExoPlayerController? = null

        fun shared(context: Context): ExoPlayerController =
            instance ?: synchronized(this) {
                instance ?: ExoPlayerController(context.applicationContext)
                    .also { instance = it }
            }

        /** Wires the control + event channels, mirroring the iOS register(). */
        fun register(messenger: BinaryMessenger, context: Context) {
            val controller = shared(context)
            MethodChannel(messenger, "limebeam/exoplayer")
                .setMethodCallHandler { call, result -> controller.handle(call, result) }
            EventChannel(messenger, "limebeam/exoplayer/events")
                .setStreamHandler(controller)
        }
    }

    val player: ExoPlayer =
        ExoPlayer.Builder(context).build().also { it.addListener(this) }

    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())

    // ExoPlayer does not push playhead updates; poll ~4Hz while open, matching
    // the Dart-side position throttle so the seek bar/labels stay current.
    private val positionTick = object : Runnable {
        override fun run() {
            emitPosition()
            handler.postDelayed(this, 250)
        }
    }

    // MARK: Method channel

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> {
                val url = call.argument<String>("url")
                if (url == null) {
                    result.error("bad_args", "url required", null)
                    return
                }
                open(url)
                result.success(null)
            }
            "play" -> { player.play(); result.success(null) }
            "pause" -> { player.pause(); result.success(null) }
            "playOrPause" -> {
                if (player.isPlaying) player.pause() else player.play()
                result.success(null)
            }
            "seek" -> {
                val ms = call.argument<Int>("ms")
                if (ms != null) player.seekTo(ms.toLong())
                result.success(null)
            }
            "setVolume" -> {
                val volume = call.argument<Double>("volume")
                if (volume != null) player.volume = volume.toFloat()
                result.success(null)
            }
            // v1: no track selection / sync offsets (the Dart side hides the UI
            // via supportsSyncOffsets=false + empty track streams). Accepted for
            // contract parity so a defensive call never crashes.
            "setAudioTrack", "setSubtitleTrack",
            "setSubtitleDelay", "setAudioDelay", "applySubtitleStyle" ->
                result.success(null)
            "dispose" -> { teardown(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    // MARK: Playback

    private fun open(url: String) {
        player.setMediaItem(MediaItem.fromUri(Uri.parse(url)))
        player.playWhenReady = true
        player.prepare()
        handler.removeCallbacks(positionTick)
        handler.post(positionTick)
    }

    /** Stops playback but keeps the shared player for reuse (mirrors iOS). */
    private fun teardown() {
        handler.removeCallbacks(positionTick)
        player.stop()
        player.clearMediaItems()
    }

    // MARK: Player.Listener

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        emit(mapOf("event" to "playing", "value" to isPlaying))
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        when (playbackState) {
            Player.STATE_BUFFERING ->
                emit(mapOf("event" to "buffering", "value" to true))
            Player.STATE_READY -> {
                emit(mapOf("event" to "buffering", "value" to false))
                val duration = player.duration
                if (duration != C.TIME_UNSET) {
                    emit(mapOf("event" to "duration", "value" to duration))
                }
            }
            Player.STATE_ENDED -> emit(mapOf("event" to "completed"))
        }
    }

    override fun onPlayerError(error: PlaybackException) {
        emit(mapOf("event" to "error", "message" to (error.message ?: "Playback error")))
    }

    // MARK: Events

    private fun emitPosition() {
        emit(mapOf("event" to "position", "value" to player.currentPosition))
        emit(mapOf("event" to "buffer", "value" to player.bufferedPosition))
    }

    private fun emit(payload: Map<String, Any?>) {
        handler.post { eventSink?.success(payload) }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
