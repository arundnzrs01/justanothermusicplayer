package com.torrentmusic.torrent_music.torrent

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TorrentMethodHandler(
    messenger: BinaryMessenger,
    private val context: Context,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val engine = JampTorrentEngine.getInstance()
    private var eventSink: EventChannel.EventSink? = null
    private val listener: (List<Map<String, Any?>>) -> Unit = { items ->
        eventSink?.success(items)
    }

    init {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initialize" -> {
                    val path = call.argument<String>("savePath")
                        ?: context.getExternalFilesDir(null)?.absolutePath
                        ?: context.filesDir.absolutePath + "/JAMP"
                    engine.initialize(path)
                    result.success(path)
                }
                "addMagnet" -> {
                    val magnet = call.argument<String>("magnet")
                        ?: return result.error("ARG", "magnet required", null)
                    result.success(engine.addMagnet(magnet))
                }
                "addTorrentFile" -> {
                    val path = call.argument<String>("path")
                        ?: return result.error("ARG", "path required", null)
                    result.success(engine.addTorrentFile(path))
                }
                "pause" -> {
                    engine.pause(call.argument<String>("id") ?: "")
                    result.success(null)
                }
                "resume" -> {
                    engine.resume(call.argument<String>("id") ?: "")
                    result.success(null)
                }
                "remove" -> {
                    val id = call.argument<String>("id") ?: ""
                    val deleteFiles = call.argument<Boolean>("deleteFiles") ?: false
                    engine.remove(id, deleteFiles)
                    result.success(null)
                }
                "getSnapshot" -> result.success(engine.snapshot())
                "shutdown" -> {
                    engine.shutdown()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "${call.method} failed", e)
            result.error("TORRENT", e.message, null)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        engine.addListener(listener)
    }

    override fun onCancel(arguments: Any?) {
        engine.removeListener(listener)
        eventSink = null
    }

    companion object {
        private const val TAG = "TorrentMethodHandler"
        const val METHOD_CHANNEL = "com.torrentmusic/torrent"
        const val EVENT_CHANNEL = "com.torrentmusic/torrent_events"
    }
}
