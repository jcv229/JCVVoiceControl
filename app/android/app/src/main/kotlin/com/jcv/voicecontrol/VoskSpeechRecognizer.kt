package com.jcv.voicecontrol

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import org.vosk.android.StorageService
import java.io.IOException

/**
 * Reconnaissance vocale française, 100 % hors-ligne, basée sur Vosk.
 *
 * Le modèle acoustique français (~40 Mo) doit être placé dans les assets de
 * l'application, dans le dossier `model-fr` (fichiers du modèle Vosk dézippés).
 * Au premier lancement, [StorageService.unpack] le copie des assets vers le
 * stockage interne de l'application, puis la reconnaissance peut commencer.
 *
 * Utilisation :
 *   - [start]   : démarre l'écoute du microphone ;
 *   - [stop]    : arrête l'écoute ;
 *   - [isReady] : indique si le modèle est chargé.
 */
object VoskSpeechRecognizer {

    private var model: Model? = null
    private var recognizer: Recognizer? = null
    private var speechService: SpeechService? = null

    /** Si vrai, l'écoute reprend automatiquement après chaque phrase. */
    private var keepListening = false

    private const val MODEL_ASSET_FOLDER = "model-fr"
    private const val MODEL_STORAGE_FOLDER = "model"
    private const val SAMPLE_RATE = 16000.0f

    /** Indique si le modèle est chargé et prêt. */
    val isReady: Boolean
        get() = recognizer != null

    /**
     * Démarre l'écoute.
     *
     * @param context  contexte de l'application.
     * @param onResult appelé à chaque phrase reconnue (texte français).
     * @param onError  appelé en cas d'erreur (message en français).
     */
    fun start(
        context: Context,
        onResult: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        keepListening = true
        // Modèle déjà chargé : on redémarre simplement le service.
        if (recognizer != null) {
            startListening(onResult, onError)
            return
        }

        // Décompresse le modèle depuis les assets (une seule fois).
        StorageService.unpack(
            context,
            MODEL_ASSET_FOLDER,
            MODEL_STORAGE_FOLDER,
            { loadedModel ->
                model = loadedModel
                try {
                    recognizer = Recognizer(loadedModel, SAMPLE_RATE)
                    startListening(onResult, onError)
                } catch (e: IOException) {
                    onError("Impossible de démarrer la reconnaissance vocale : ${e.message}")
                }
            },
            { e ->
                onError(
                    "Modèle de reconnaissance vocale introuvable. " +
                        "Placez le modèle Vosk français dans les assets : ${e.message}"
                )
            }
        )
    }

    /** Lance le service de reconnaissance avec les callbacks fournis. */
    private fun startListening(
        onResult: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        val r = recognizer ?: run {
            onError("La reconnaissance vocale n'est pas prête.")
            return
        }
        speechService?.stop()
        speechService = SpeechService(r, SAMPLE_RATE)
        speechService?.startListening(object : RecognitionListener {
            override fun onPartialResult(hypothesis: String?) {
                // Résultat partiel : ignoré pour le MVP (on attend le final).
            }

            override fun onResult(hypothesis: String?) {
                val text = parseHypothesis(hypothesis)
                if (text.isNotBlank()) {
                    onResult(text)
                    restartIfNeeded(onResult, onError)
                }
            }

            override fun onFinalResult(hypothesis: String?) {
                val text = parseHypothesis(hypothesis)
                if (text.isNotBlank()) {
                    onResult(text)
                    restartIfNeeded(onResult, onError)
                }
            }

            override fun onError(e: Exception?) {
                onError(e?.message ?: "Erreur de reconnaissance vocale.")
            }

            override fun onTimeout() {
                // Fin de la parole sans résultat : on relance si nécessaire.
                restartIfNeeded(onResult, onError)
            }
        })
    }

    /** Relance l'écoute après une phrase, pour une écoute continue. */
    private fun restartIfNeeded(
        onResult: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        if (keepListening) {
            // Petit délai pour laisser Vosk terminer proprement avant de relancer.
            mainHandler.postDelayed({
                if (keepListening) startListening(onResult, onError)
            }, 300)
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    /** Arrête l'écoute. */
    fun stop() {
        keepListening = false
        speechService?.stop()
        speechService = null
    }

    /** Libère le modèle et le reconnaisseur. */
    fun shutdown() {
        stop()
        recognizer?.close()
        recognizer = null
        model?.close()
        model = null
    }

    /** Extrait le champ "text" du JSON renvoyé par Vosk. */
    private fun parseHypothesis(hypothesis: String?): String {
        if (hypothesis.isNullOrBlank()) return ""
        return try {
            JSONObject(hypothesis).optString("text", "")
        } catch (e: Exception) {
            ""
        }
    }
}
