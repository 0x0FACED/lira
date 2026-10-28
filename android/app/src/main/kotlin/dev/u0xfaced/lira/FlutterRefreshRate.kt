package dev.u0xfaced.lira

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.view.Surface
import android.view.SurfaceHolder
import android.view.Window
import io.flutter.embedding.android.FlutterSurfaceView

internal class FlutterRefreshRate(
    private val window: Window,
    private val view: FlutterSurfaceView,
) : SurfaceHolder.Callback, DisplayManager.DisplayListener {
    private val displayManager =
        window.context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val originalDisplayModeId = window.attributes.preferredDisplayModeId
    private var resumed = false
    private var focused = view.hasWindowFocus()
    private var requestedRate = Float.NaN

    init {
        view.holder.addCallback(this)
        displayManager.registerDisplayListener(this, null)
    }

    fun setResumed(value: Boolean) {
        resumed = value
        update()
    }

    fun setFocused(value: Boolean) {
        focused = value
        update()
    }

    fun dispose() {
        resumed = false
        clear()
        view.holder.removeCallback(this)
        displayManager.unregisterDisplayListener(this)
    }

    private fun update() {
        if (!resumed || !focused) {
            clear()
            return
        }
        val display = view.display ?: return
        if (!display.isValid) return
        val current = display.mode
        var preferred = current
        for (mode in display.supportedModes) {
            if (mode.physicalWidth == current.physicalWidth &&
                mode.physicalHeight == current.physicalHeight &&
                mode.refreshRate > preferred.refreshRate
            ) {
                preferred = mode
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val surface = view.holder.surface
            if (!surface.isValid) return
            if (requestedRate == preferred.refreshRate) return

            val compatibility = Surface.FRAME_RATE_COMPATIBILITY_DEFAULT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                surface.setFrameRate(
                    preferred.refreshRate,
                    compatibility,
                    Surface.CHANGE_FRAME_RATE_ONLY_IF_SEAMLESS,
                )
            } else {
                surface.setFrameRate(preferred.refreshRate, compatibility)
            }
            requestedRate = preferred.refreshRate
        } else {
            // Older Android needs a mode ID; keep the current resolution.
            val attributes = window.attributes
            if (attributes.preferredDisplayModeId != preferred.modeId) {
                attributes.preferredDisplayModeId = preferred.modeId
                window.attributes = attributes
            }
        }
    }

    private fun clear() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val surface = view.holder.surface
            if (!requestedRate.isNaN() && surface.isValid) {
                surface.setFrameRate(0f, Surface.FRAME_RATE_COMPATIBILITY_DEFAULT)
            }
            requestedRate = Float.NaN
        } else {
            val attributes = window.attributes
            if (attributes.preferredDisplayModeId != originalDisplayModeId) {
                attributes.preferredDisplayModeId = originalDisplayModeId
                window.attributes = attributes
            }
        }
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        requestedRate = Float.NaN
        update()
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        requestedRate = Float.NaN
        update()
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        clear()
    }

    override fun onDisplayChanged(displayId: Int) {
        if (view.display?.displayId == displayId) update()
    }

    override fun onDisplayAdded(displayId: Int) {}

    override fun onDisplayRemoved(displayId: Int) {
        if (view.display?.displayId == displayId) clear()
    }
}
