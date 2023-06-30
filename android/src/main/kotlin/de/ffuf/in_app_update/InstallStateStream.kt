package de.ffuf.in_app_update

import io.flutter.plugin.common.EventChannel

class InstallStateStream: EventChannel.StreamHandler {
    var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun add(status: Int){
        sink?.success(status)
    }
}