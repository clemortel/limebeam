package com.limebeam.app.exoplayer

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.text.CueGroup
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

        /**
         * Wires the control + event channels. The ExoPlayer is built LAZILY on
         * first use (playback start), never at app startup — building it eagerly
         * for every launch (even phones / non-TV) added memory + main-thread
         * work at the most sensitive moment and caused startup ANRs on the
         * memory-constrained Fire TV Stick.
         */
        fun register(messenger: BinaryMessenger, context: Context) {
            val appContext = context.applicationContext
            MethodChannel(messenger, "limebeam/exoplayer")
                .setMethodCallHandler { call, result ->
                    shared(appContext).handle(call, result)
                }
            EventChannel(messenger, "limebeam/exoplayer/events")
                .setStreamHandler(object : EventChannel.StreamHandler {
                    override fun onListen(
                        arguments: Any?,
                        events: EventChannel.EventSink?,
                    ) = shared(appContext).onListen(arguments, events)

                    // Don't build a player just to cancel a subscription.
                    override fun onCancel(arguments: Any?) =
                        instance?.onCancel(arguments) ?: Unit
                })
        }

        /**
         * Fully releases the shared player and drops the singleton. Called when
         * the FlutterEngine is torn down (app quit) so a relaunch builds a fresh
         * player — reusing a released/stale ExoPlayer across engine lifecycles
         * crashes when a new SurfaceView binds to it.
         */
        fun releaseShared() {
            synchronized(this) {
                instance?.release()
                instance = null
            }
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
            "setAudioTrack" -> {
                call.argument<String>("id")?.let { selectTrack(it, C.TRACK_TYPE_AUDIO) }
                result.success(null)
            }
            "setSubtitleTrack" -> {
                call.argument<String>("id")?.let { selectTrack(it, C.TRACK_TYPE_TEXT) }
                result.success(null)
            }
            // No per-track sync offset in ExoPlayer, and subtitles are styled by
            // the Flutter overlay — accepted for contract parity, no-op here.
            "setSubtitleDelay", "setAudioDelay", "applySubtitleStyle" ->
                result.success(null)
            // Zoom-to-fill (crop) vs fit (letterbox), YouTube/Netflix style.
            "setFill" -> {
                val fill = call.argument<Boolean>("fill") ?: false
                player.videoScalingMode = if (fill) {
                    C.VIDEO_SCALING_MODE_SCALE_TO_FIT_WITH_CROPPING
                } else {
                    C.VIDEO_SCALING_MODE_SCALE_TO_FIT
                }
                result.success(null)
            }
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

    /** Fully releases native resources; the singleton must not be used after. */
    private fun release() {
        handler.removeCallbacks(positionTick)
        eventSink = null
        player.release()
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

    // MARK: Tracks

    override fun onTracksChanged(tracks: Tracks) {
        val audio = mutableListOf<Map<String, Any?>>()
        val subtitle = mutableListOf<Map<String, Any?>>()
        var selectedAudioId: String? = null
        // Text defaults to "no" (off) unless a text track is actually selected,
        // matching the Dart "no" sentinel for subtitles-off.
        var selectedSubtitleId: String? = "no"

        tracks.groups.forEachIndexed { groupIndex, group ->
            for (trackIndex in 0 until group.length) {
                val format = group.getTrackFormat(trackIndex)
                val id = "$groupIndex.$trackIndex"
                val entry = mapOf(
                    "id" to id,
                    "title" to format.label,
                    "language" to format.language,
                    "isDefault" to
                        ((format.selectionFlags and C.SELECTION_FLAG_DEFAULT) != 0),
                )
                when (group.type) {
                    C.TRACK_TYPE_AUDIO -> {
                        audio.add(entry)
                        if (group.isTrackSelected(trackIndex)) selectedAudioId = id
                    }
                    C.TRACK_TYPE_TEXT -> {
                        subtitle.add(entry)
                        if (group.isTrackSelected(trackIndex)) selectedSubtitleId = id
                    }
                }
            }
        }
        emit(mapOf("event" to "tracks", "audio" to audio, "subtitle" to subtitle))
        emit(
            mapOf(
                "event" to "selectedTracks",
                "audioId" to selectedAudioId,
                "subtitleId" to selectedSubtitleId,
            ),
        )
    }

    /** Selects a track by "group.track" id, or the "no"/"auto" sentinels. */
    private fun selectTrack(id: String, type: Int) {
        val params = player.trackSelectionParameters.buildUpon()
        when (id) {
            "no" -> params.setTrackTypeDisabled(type, true).clearOverridesOfType(type)
            "auto" -> params.setTrackTypeDisabled(type, false).clearOverridesOfType(type)
            else -> {
                val parts = id.split(".")
                val groupIndex = parts.getOrNull(0)?.toIntOrNull()
                val trackIndex = parts.getOrNull(1)?.toIntOrNull()
                val groups = player.currentTracks.groups
                if (groupIndex != null && trackIndex != null &&
                    groupIndex < groups.size
                ) {
                    params.setTrackTypeDisabled(type, false)
                        .setOverrideForType(
                            TrackSelectionOverride(
                                groups[groupIndex].mediaTrackGroup,
                                trackIndex,
                            ),
                        )
                }
            }
        }
        player.trackSelectionParameters = params.build()
    }

    // MARK: Subtitles

    override fun onCues(cueGroup: CueGroup) {
        val text = cueGroup.cues
            .mapNotNull { it.text?.toString() }
            .joinToString("\n")
            .trim()
        emit(mapOf("event" to "cues", "text" to text))
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
