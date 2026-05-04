package com.example.aura_ai

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.media.projection.MediaProjectionManager
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val eventChannelName = "aura_ai/foreground_announcements"
    private val methodChannelName = "aura_ai/announcement_controls"
    private var pendingScreenModeResult: MethodChannel.Result? = null
    private val screenCaptureLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val accepted = result.resultCode == Activity.RESULT_OK && result.data != null
            if (accepted) {
                AuraScreenCaptureManager.saveProjectionConsent(result.resultCode, result.data)
            }
            pendingScreenModeResult?.success(accepted)
            pendingScreenModeResult = null
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleScreenCaptureIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        AuraAndroidEvents.setEventSink(events)
                    }

                    override fun onCancel(arguments: Any?) {
                        AuraAndroidEvents.setEventSink(null)
                    }
                },
            )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAnnouncementAccessStatus" -> {
                        result.success(
                            mapOf(
                                "notificationAccessEnabled" to isNotificationAccessEnabled(),
                                "phonePermissionGranted" to false,
                                "screenModeAccessibilityEnabled" to
                                    isAccessibilityServiceEnabled(),
                                "screenModeProjectionReady" to
                                    AuraScreenCaptureManager.isReady(),
                            ),
                        )
                    }

                    "openNotificationAccessSettings" -> {
                        result.success(false)
                    }

                    "requestPhoneAnnouncementPermissions" -> {
                        requestPhoneAnnouncementPermissions(result)
                    }

                    "startScreenModeSession" -> {
                        startScreenModeSession(result)
                    }

                    "openAccessibilitySettings" -> {
                        result.success(false)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleScreenCaptureIntent(intent)
    }

    private fun handleScreenCaptureIntent(intent: Intent?) {
        val capturePath = intent?.getStringExtra("aura_screen_capture_path") ?: return
        AuraAndroidEvents.emit(
            mapOf(
                "type" to "screen_capture",
                "path" to capturePath,
                "autoAnalyze" to intent.getBooleanExtra(
                    "aura_screen_capture_auto_analyze",
                    true,
                ),
            ),
        )
        intent.removeExtra("aura_screen_capture_path")
        intent.removeExtra("aura_screen_capture_auto_analyze")
    }

    override fun onStart() {
        super.onStart()
    }

    override fun onStop() {
        super.onStop()
    }

    override fun onDestroy() {
        AuraAndroidEvents.setEventSink(null)
        super.onDestroy()
    }

    private fun requestPhoneAnnouncementPermissions(result: MethodChannel.Result) {
        result.success(false)
    }

    private fun startScreenModeSession(result: MethodChannel.Result) {
        pendingScreenModeResult = result
        val projectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        screenCaptureLauncher.launch(projectionManager.createScreenCaptureIntent())
    }

    private fun isNotificationAccessEnabled(): Boolean {
        return false
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        return false
    }
}
