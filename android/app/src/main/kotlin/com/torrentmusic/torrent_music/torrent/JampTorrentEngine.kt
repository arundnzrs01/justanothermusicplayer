package com.torrentmusic.torrent_music.torrent

import android.util.Log
import org.libtorrent4j.SessionManager
import org.libtorrent4j.Sha1Hash
import org.libtorrent4j.TorrentHandle
import org.libtorrent4j.TorrentInfo
import org.libtorrent4j.TorrentStatus
import org.libtorrent4j.swig.torrent_flags_t
import java.io.File
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Minimal libtorrent4j session wrapper — same engine as
 * [LibreTorrent](https://github.com/proninyaroslav/libretorrent).
 */
class JampTorrentEngine {
    private val started = AtomicBoolean(false)
    private var sessionManager: SessionManager? = null
    private var savePath: String = ""
    private val trackedIds = CopyOnWriteArrayList<String>()
    private val pausedIds = CopyOnWriteArrayList<String>()
    private val listeners = CopyOnWriteArrayList<(List<Map<String, Any?>>) -> Unit>()
    private val pollExecutor = Executors.newSingleThreadScheduledExecutor()

    fun initialize(downloadDir: String) {
        savePath = downloadDir
        File(downloadDir).mkdirs()

        if (started.getAndSet(true)) return

        val sm = SessionManager(false)
        sm.start()
        sessionManager = sm
        pollExecutor.scheduleAtFixedRate({ notifyListeners() }, 1, 1, TimeUnit.SECONDS)
        Log.i(TAG, "libtorrent4j session started at $downloadDir")
    }

    fun addMagnet(magnet: String): String {
        val sm = requireSession()
        val hash = parseInfoHashHex(magnet)
        sm.download(magnet, File(savePath), torrent_flags_t())
        if (!trackedIds.contains(hash)) trackedIds.add(hash)
        waitForHandle(hash)
        Log.i(TAG, "addMagnet id=$hash")
        return hash
    }

    fun addTorrentFile(path: String): String {
        val sm = requireSession()
        val ti = TorrentInfo(File(path))
        val hash = ti.infoHash().toHex()
        sm.download(ti, File(savePath))
        if (!trackedIds.contains(hash)) trackedIds.add(hash)
        waitForHandle(hash)
        Log.i(TAG, "addTorrentFile id=$hash")
        return hash
    }

    fun pause(id: String) {
        findHandle(id)?.pause()
        if (!pausedIds.contains(id)) pausedIds.add(id)
    }

    fun resume(id: String) {
        findHandle(id)?.resume()
        pausedIds.remove(id)
    }

    fun remove(id: String, @Suppress("UNUSED_PARAMETER") deleteFiles: Boolean) {
        val handle = findHandle(id) ?: return
        requireSession().remove(handle)
        trackedIds.remove(id)
        pausedIds.remove(id)
    }

    fun snapshot(): List<Map<String, Any?>> =
        trackedIds.mapNotNull { handleToMap(it) }

    fun shutdown() {
        if (!started.getAndSet(false)) return
        pollExecutor.shutdownNow()
        sessionManager?.stop()
        sessionManager = null
        trackedIds.clear()
    }

    fun addListener(listener: (List<Map<String, Any?>>) -> Unit) {
        listeners.add(listener)
        listener(snapshot())
    }

    fun removeListener(listener: (List<Map<String, Any?>>) -> Unit) {
        listeners.remove(listener)
    }

    private fun notifyListeners() {
        val snap = snapshot()
        listeners.forEach { it(snap) }
    }

    private fun requireSession(): SessionManager =
        sessionManager ?: throw IllegalStateException("Torrent session not initialized")

    private fun findHandle(id: String): TorrentHandle? {
        val sm = sessionManager ?: return null
        return try {
            sm.find(Sha1Hash.parseHex(id))
        } catch (_: Exception) {
            null
        }
    }

    private fun waitForHandle(hash: String) {
        repeat(30) {
            if (findHandle(hash)?.isValid == true) return
            Thread.sleep(100)
        }
    }

    private fun parseInfoHashHex(magnet: String): String {
        val match = INFOHASH_PATTERN.find(magnet)
            ?: throw IllegalArgumentException("Magnet link has no infohash")
        return match.groupValues[1].lowercase()
    }

    private fun handleToMap(id: String): Map<String, Any?>? {
        val handle = findHandle(id) ?: return null
        if (!handle.isValid) return null

        val status: TorrentStatus = handle.status()
        val name = status.name().ifBlank { id.take(8) }
        val progress = status.progress().toDouble()
        val statusStr = when {
            pausedIds.contains(id) -> "paused"
            status.isFinished || status.isSeeding -> "completed"
            else -> "downloading"
        }
        val phase = when {
            pausedIds.contains(id) -> "Paused"
            !status.hasMetadata() -> "Downloading metadata"
            status.isFinished || status.isSeeding -> "Complete"
            status.state() == TorrentStatus.State.CHECKING_FILES -> "Checking files"
            else -> "Downloading"
        }

        return mapOf(
            "id" to id,
            "displayName" to name,
            "progress" to progress,
            "downloadBps" to status.downloadRate(),
            "uploadBps" to status.uploadRate(),
            "seeders" to status.numSeeds(),
            "leechers" to status.numPeers(),
            "status" to statusStr,
            "phaseLabel" to phase,
            "errorMessage" to null,
        )
    }

    companion object {
        private const val TAG = "JampTorrentEngine"
        private val INFOHASH_PATTERN =
            Regex("(?i)urn:btih:([a-f0-9]{40}|[a-f0-9]{32})")

        @Volatile
        private var instance: JampTorrentEngine? = null

        fun getInstance(): JampTorrentEngine =
            instance ?: synchronized(this) {
                instance ?: JampTorrentEngine().also { instance = it }
            }
    }
}
