package dev.u0xfaced.lira

import android.graphics.Rect
import android.os.Build
import android.view.View
import android.view.ViewTreeObserver
import android.view.WindowInsets
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var readerChromeChannel: MethodChannel? = null
    private var updatesChannel: MethodChannel? = null
    private var flutterRefreshRate: FlutterRefreshRate? = null
    private var readerChromeVisible: Boolean? = null
    private var originalSystemUiVisibility = 0
    private var originalBarsBehavior = 0
    private var keyboardVisible = false
    private val visibleFrame = Rect()
    private val reapplyAfterKeyboard = Runnable { applyReaderSystemBars() }
    private val keyboardListener = ViewTreeObserver.OnGlobalLayoutListener {
        val visible = isKeyboardVisible()
        if (readerChromeVisible != null && visible != keyboardVisible) {
            keyboardVisible = visible
            applyReaderSystemBars()
            window.decorView.removeCallbacks(reapplyAfterKeyboard)
            if (!visible) {
                // Older Android releases reject fullscreen changes for one
                // second after the IME closes. The callback reads current state.
                window.decorView.postDelayed(reapplyAfterKeyboard, 1100)
            }
        }
    }

    override fun onFlutterSurfaceViewCreated(flutterSurfaceView: FlutterSurfaceView) {
        super.onFlutterSurfaceViewCreated(flutterSurfaceView)
        flutterRefreshRate?.dispose()
        flutterRefreshRate = FlutterRefreshRate(window, flutterSurfaceView)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AppUpdateInstaller.start(applicationContext)
        updatesChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.u0xfaced.lira/updates",
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getUpdateDirectory" -> AppUpdateInstaller.getUpdateDirectory(applicationContext, result)
                    "cleanupUpdates" -> AppUpdateInstaller.cleanupUpdates(applicationContext, result)
                    "installUpdate" -> AppUpdateInstaller.installUpdate(this@MainActivity, call, result)
                    else -> result.notImplemented()
                }
            }
        }
        readerChromeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.u0xfaced.lira/reader_chrome",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setReaderChromeVisible" -> {
                        val visible = call.arguments as? Boolean
                        if (visible == null) {
                            result.error("invalid_visibility", "Expected a boolean", null)
                        } else {
                            setReaderChromeVisible(visible)
                            result.success(null)
                        }
                    }
                    "restoreSystemBars" -> {
                        restoreSystemBars()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun setReaderChromeVisible(visible: Boolean) {
        if (readerChromeVisible == null) {
            originalSystemUiVisibility = window.decorView.systemUiVisibility
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                originalBarsBehavior = window.insetsController?.systemBarsBehavior ?: 0
            }
            keyboardVisible = isKeyboardVisible()
            window.decorView.viewTreeObserver.addOnGlobalLayoutListener(keyboardListener)
        }
        readerChromeVisible = visible
        applyReaderSystemBars()
    }

    @Suppress("DEPRECATION")
    private fun applyReaderSystemBars() {
        val chromeVisible = readerChromeVisible ?: return
        val showBars = chromeVisible || isKeyboardVisible()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Flutter's SystemUiMode immersive variants are ignored at target
            // SDK 36. Insets visibility still works with enforced edge-to-edge.
            window.insetsController?.let { controller ->
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                if (showBars) {
                    controller.show(WindowInsets.Type.systemBars())
                } else {
                    controller.hide(WindowInsets.Type.systemBars())
                }
            }
        } else {
            val immersiveFlags = View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            val current = window.decorView.systemUiVisibility
            window.decorView.systemUiVisibility = if (showBars) {
                current and immersiveFlags.inv()
            } else {
                current or immersiveFlags
            }
        }
    }

    private fun isKeyboardVisible(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return window.decorView.rootWindowInsets?.isVisible(WindowInsets.Type.ime()) == true
        }
        window.decorView.getWindowVisibleDisplayFrame(visibleFrame)
        return window.decorView.height - visibleFrame.bottom > 100 * resources.displayMetrics.density
    }

    @Suppress("DEPRECATION")
    private fun restoreSystemBars() {
        if (readerChromeVisible == null) return
        readerChromeVisible = null
        window.decorView.removeCallbacks(reapplyAfterKeyboard)
        window.decorView.viewTreeObserver.removeOnGlobalLayoutListener(keyboardListener)
        window.decorView.systemUiVisibility = originalSystemUiVisibility
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.systemBarsBehavior = originalBarsBehavior
                controller.show(WindowInsets.Type.systemBars())
            }
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        flutterRefreshRate?.setResumed(true)
        applyReaderSystemBars()
    }

    override fun onPause() {
        flutterRefreshRate?.setResumed(false)
        super.onPause()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        flutterRefreshRate?.setFocused(hasFocus)
        if (hasFocus) applyReaderSystemBars()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        flutterRefreshRate?.dispose()
        flutterRefreshRate = null
        restoreSystemBars()
        readerChromeChannel?.setMethodCallHandler(null)
        readerChromeChannel = null
        updatesChannel?.setMethodCallHandler(null)
        updatesChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
