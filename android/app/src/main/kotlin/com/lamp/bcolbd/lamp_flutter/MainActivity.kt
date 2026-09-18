package com.lamp.bcolbd.lamp_flutter

import android.app.UiModeManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Keeps the platform's own launch screen in step with the app's theme toggle.
 *
 * The launch screen is drawn by the system before any app code runs — it is
 * composed from the manifest theme and the system's night-mode configuration,
 * so nothing stored inside the app can be consulted in time. With the phone in
 * light mode and the app set to dark, the result was a white launch screen
 * handing over to a dark app.
 *
 * [UiModeManager.setApplicationNightMode] is the API for exactly this: it tells
 * the system which night mode *this app* runs in, so the next cold start
 * resolves `values-night` accordingly and the launch screen matches. It is
 * API 31 and above; below that the launch screen follows the system, which is
 * the pre-existing behaviour and still correct for anyone who has not
 * overridden the theme.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "lamp/uimode"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "setNightMode") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                    // Nothing to do, and not an error: the launch screen on
                    // these devices follows the system, which is a reasonable
                    // answer rather than a broken one.
                    result.success(false)
                    return@setMethodCallHandler
                }

                val mode = when (call.argument<String>("mode")) {
                    "light" -> UiModeManager.MODE_NIGHT_NO
                    "dark" -> UiModeManager.MODE_NIGHT_YES
                    else -> UiModeManager.MODE_NIGHT_AUTO
                }

                val manager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                manager.setApplicationNightMode(mode)
                result.success(true)
            }
    }
}
