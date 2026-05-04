package com.example.aura_ai

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class AuraNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val extras = sbn.notification.extras ?: return
        val title = extras.getCharSequence("android.title")?.toString()?.trim().orEmpty()
        if (title.isBlank()) return

        val packageName = sbn.packageName.orEmpty()
        val appName = normalizePlatformLabel(packageName)

        AuraAndroidEvents.emit(
            mapOf(
                "type" to "message",
                "platform" to appName,
                "sender" to title,
                "packageName" to packageName,
            ),
        )
    }

    private fun normalizePlatformLabel(packageName: String): String {
        return when {
            packageName.contains("whatsapp", ignoreCase = true) -> "WhatsApp"
            packageName.contains("telegram", ignoreCase = true) -> "Telegram"
            packageName.contains("messenger", ignoreCase = true) -> "Messenger"
            packageName.contains("signal", ignoreCase = true) -> "Signal"
            packageName.contains("instagram", ignoreCase = true) -> "Instagram"
            packageName.contains("facebook", ignoreCase = true) -> "Facebook"
            packageName.contains("gmail", ignoreCase = true) -> "Gmail"
            packageName.contains("outlook", ignoreCase = true) -> "Outlook"
            packageName.contains("mms", ignoreCase = true) ||
                packageName.contains("sms", ignoreCase = true) ||
                packageName.contains("messages", ignoreCase = true) -> "SMS"
            else -> {
                try {
                    val appInfo = packageManager.getApplicationInfo(packageName, 0)
                    packageManager.getApplicationLabel(appInfo).toString()
                } catch (_: Exception) {
                    packageName.substringAfterLast('.').replaceFirstChar { it.uppercase() }
                }
            }
        }
    }
}
