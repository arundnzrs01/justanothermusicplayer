package com.torrentmusic.torrent_music

import com.torrentmusic.torrent_music.torrent.TorrentMethodHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TorrentMethodHandler(flutterEngine.dartExecutor.binaryMessenger, this)
    }
}
