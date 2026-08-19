package com.jcv.voicecontrol

import android.content.Context
import android.media.AudioManager
import android.media.MediaPlayer
import android.provider.MediaStore

/**
 * Helper pour la lecture de musique locale et le contrôle du volume.
 *
 * Entièrement hors-ligne : indexation de la bibliothèque musicale (MediaStore)
 * et lecture via MediaPlayer. Le volume est contrôlé via AudioManager.
 */
object MediaHelper {

    private var player: MediaPlayer? = null
    private var playlist: List<String> = emptyList()
    private var currentIndex = -1
    private var appContext: Context? = null

    /** Indexe la bibliothèque musicale locale (chemins des fichiers audio). */
    private fun loadPlaylist(context: Context): List<String> {
        val uris = mutableListOf<String>()
        val projection = arrayOf(MediaStore.Audio.Media.DATA)
        context.contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            null,
            null,
            "${MediaStore.Audio.Media.TITLE} ASC"
        )?.use { cursor ->
            val column = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            while (cursor.moveToNext()) {
                val path = cursor.getString(column)
                if (path != null) uris.add(path)
            }
        }
        return uris
    }

    /** Lance la lecture (indexe la bibliothèque au premier appel). */
    fun play(context: Context): String {
        appContext = context.applicationContext
        if (playlist.isEmpty()) {
            playlist = loadPlaylist(context)
            currentIndex = 0
        }
        if (playlist.isEmpty()) {
            return "Aucune musique n'a été trouvée sur cet appareil."
        }
        playCurrent()
        return "Je joue de la musique."
    }

    private fun playCurrent() {
        val ctx = appContext ?: return
        player?.release()
        val path = playlist[currentIndex]
        player = MediaPlayer().apply {
            setAudioStreamType(AudioManager.STREAM_MUSIC)
            setDataSource(path)
            prepare()
            start()
        }
    }

    /** Met la lecture en pause. */
    fun pause(): String {
        return if (player?.isPlaying == true) {
            player?.pause()
            "Musique en pause."
        } else {
            "Aucune musique n'est en cours de lecture."
        }
    }

    /** Reprend la lecture. */
    fun resume(): String {
        return if (player != null && player?.isPlaying == false) {
            player?.start()
            "Je reprends la lecture."
        } else {
            play(appContext ?: return "Aucune musique disponible.")
        }
    }

    /** Passe au morceau suivant. */
    fun next(): String {
        if (playlist.isEmpty()) return "Aucune musique en cours."
        currentIndex = (currentIndex + 1) % playlist.size
        playCurrent()
        return "Chanson suivante."
    }

    /** Reviens au morceau précédent. */
    fun previous(): String {
        if (playlist.isEmpty()) return "Aucune musique en cours."
        currentIndex = if (currentIndex <= 0) playlist.size - 1 else currentIndex - 1
        playCurrent()
        return "Chanson précédente."
    }

    /** Arrête la lecture (libère le lecteur). */
    fun stop(): String {
        player?.release()
        player = null
        return "Lecture arrêtée."
    }

    // ------------------------------------------------------------------
    // Contrôle du volume
    // ------------------------------------------------------------------

    private fun audioManager(context: Context): AudioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    /** Augmente le volume d'un cran. */
    fun volumeUp(context: Context): String {
        audioManager(context).adjustStreamVolume(
            AudioManager.STREAM_MUSIC,
            AudioManager.ADJUST_RAISE,
            0
        )
        return "Volume augmenté."
    }

    /** Baisse le volume d'un cran. */
    fun volumeDown(context: Context): String {
        audioManager(context).adjustStreamVolume(
            AudioManager.STREAM_MUSIC,
            AudioManager.ADJUST_LOWER,
            0
        )
        return "Volume baissé."
    }

    /** Règle le volume en pourcentage (0-100). */
    fun volumeSet(context: Context, level: Int): String {
        val am = audioManager(context)
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val target = (max * level / 100.0).toInt().coerceIn(0, max)
        am.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
        return "Volume réglé à $level pour cent."
    }
}
