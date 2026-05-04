package com.example.aura_ai

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent

class AuraScreenModeAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        serviceInfo = serviceInfo.apply {
            flags = flags or
                AccessibilityServiceInfo.FLAG_REQUEST_TOUCH_EXPLORATION_MODE or
                AccessibilityServiceInfo.FLAG_REQUEST_MULTI_FINGER_GESTURES
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
    }

    override fun onInterrupt() {
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onGesture(gestureId: Int): Boolean {
        if (gestureId == GESTURE_3_FINGER_TRIPLE_TAP) {
            return AuraScreenCaptureManager.captureAndLaunch(this)
        }
        return super.onGesture(gestureId)
    }
}
