package com.example.aura_ai

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object AuraAndroidEvents {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private val pendingEvents = ArrayDeque<Map<String, Any>>()

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        if (sink != null) {
            while (pendingEvents.isNotEmpty()) {
                val event = pendingEvents.removeFirst()
                mainHandler.post {
                    sink.success(event)
                }
            }
        }
    }

    fun emit(payload: Map<String, Any>) {
        val sink = eventSink
        if (sink == null) {
            pendingEvents.addLast(payload)
            return
        }
        mainHandler.post {
            sink.success(payload)
        }
    }
}
