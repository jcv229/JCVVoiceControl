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
        onError: (String) -> Unit,
        onPartial: (String) -> Unit = {}
    ) {
        keepListening = true
        // Modèle déjà chargé : on redémarre simplement le service.
        if (recognizer != null) {
            startListening(onResult, onError, onPartial)
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
                    startListening(onResult, onError, onPartial)
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
        onError: (String) -> Unit,
        onPartial: (String) -> Unit = {}
    ) {
        val r = recognizer ?: run {
            onError("La reconnaissance vocale n'est pas prête.")
            return
        }
        speechService?.stop()
        try {
            speechService = SpeechService(r, SAMPLE_RATE)
        } catch (e: IOException) {
            onError("Impossible de démarrer le micro : ${e.message}")
            return
        }
        speechService?.startListening(object : RecognitionListener {
            override fun onPartialResult(hypothesis: String?) {
                // Retour en temps réel pendant que l'utilisateur parle,
                // pour confirmer que le micro capte bien la voix (affichage seul,
                // n'exécute jamais de commande).
                val partial = parseHypothesis(hypothesis, key = "partial")
                if (partial.isNotBlank()) {
                    onPartial(partial)
                }
            }

            override fun onResult(hypothesis: String?) {
                val text = parseHypothesis(hypothesis)
                if (text.isNotBlank()) {
                    onResult(text)
                    restartIfNeeded(onResult, onError, onPartial)
                }
            }

            override fun onFinalResult(hypothesis: String?) {
                val text = parseHypothesis(hypothesis)
                if (text.isNotBlank()) {
                    onResult(text)
                    restartIfNeeded(onResult, onError, onPartial)
                }
            }

            override fun onError(e: Exception?) {
                onError(e?.message ?: "Erreur de reconnaissance vocale.")
            }

            override fun onTimeout() {
                // Fin de la parole sans résultat : on relance si nécessaire.
                restartIfNeeded(onResult, onError, onPartial)
            }
        })
    }

    /** Relance l'écoute après une phrase, pour une écoute continue. */
    private fun restartIfNeeded(
        onResult: (String) -> Unit,
        onError: (String) -> Unit,
        onPartial: (String) -> Unit = {}
    ) {
        if (keepListening) {
            // Petit délai pour laisser Vosk terminer proprement avant de relancer.
            mainHandler.postDelayed({
                if (keepListening) startListening(onResult, onError, onPartial)
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

    /** Extrait un champ texte du JSON renvoyé par Vosk ("text" ou "partial"). */
    private fun parseHypothesis(hypothesis: String?, key: String = "text"): String {
        if (hypothesis.isNullOrBlank()) return ""
        return try {
            JSONObject(hypothesis).optString(key, "")
        } catch (e: Exception) {
            ""
        }
    }
}
