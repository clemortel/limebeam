package com.limebeam.app.exoplayer

import android.content.Context
import android.view.SurfaceView
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Registers the `limebeam/exoplayer_view` platform view: a [SurfaceView] bound
 * to the shared [ExoPlayerController]'s player. Used via hybrid composition on
 * the Dart side so the SurfaceView is a real view in the hierarchy, composited
 * by SurfaceFlinger as a hardware overlay.
 */
class ExoPlayerViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return ExoPlayerPlatformView(context)
    }
}

/** Hosts the SurfaceView and attaches/detaches it from the shared player. */
class ExoPlayerPlatformView(context: Context) : PlatformView {
    private val surfaceView = SurfaceView(context)

    init {
        // A SurfaceView owns a separate SurfaceFlinger layer that, by default,
        // sits BEHIND the app window — so Flutter's opaque background occludes
        // it (black screen). Media-overlay z-order lifts it above the window's
        // base surface so the video is visible; Flutter's overlay layer (the
        // controls) still composites on top.
        surfaceView.setZOrderMediaOverlay(true)
        ExoPlayerController.shared(context).player.setVideoSurfaceView(surfaceView)
    }

    override fun getView(): View = surfaceView

    override fun dispose() {
        ExoPlayerController.shared(surfaceView.context)
            .player.clearVideoSurfaceView(surfaceView)
    }
}
