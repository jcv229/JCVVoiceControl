package com.jcv.voicecontrol

import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeler
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions

/**
 * Moteur de perception : OCR (reconnaissance de texte) et reconnaissance
 * d'objets, entièrement sur l'appareil via ML Kit (aucune connexion requise).
 *
 * Les clients ML Kit sont créés de façon paresseuse et peuvent être refermés
 * puis recréés (utile pour libérer la mémoire après une session caméra).
 */
object PerceptionEngine {

    private var textRecognizer: TextRecognizer? = null
    private var labeler: ImageLabeler? = null

    private fun getTextRecognizer(): TextRecognizer =
        textRecognizer ?: TextRecognition
            .getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            .also { textRecognizer = it }

    private fun getLabeler(): ImageLabeler =
        labeler ?: ImageLabeling
            .getClient(ImageLabelerOptions.DEFAULT_OPTIONS)
            .also { labeler = it }

    /** Reconnaît le texte d'une image et transmet le résultat à [onResult]. */
    fun recognizeText(
        image: InputImage,
        onResult: (String) -> Unit,
        onError: (Exception) -> Unit
    ) {
        getTextRecognizer().process(image)
            .addOnSuccessListener { visionText -> onResult(visionText.text) }
            .addOnFailureListener { onError(it) }
    }

    /**
     * Détecte les objets d'une image et transmet une description textuelle
     * à [onResult] (les 3 objets les plus probables, avec leur confiance).
     */
    fun labelImage(
        image: InputImage,
        onResult: (String) -> Unit,
        onError: (Exception) -> Unit
    ) {
        getLabeler().process(image)
            .addOnSuccessListener { labels ->
                val description = labels
                    .take(3)
                    .joinToString(", ") { "${describeLabel(it.text)} (${(it.confidence * 100).toInt()} pour cent)" }
                onResult(if (description.isBlank()) "Aucun objet reconnu." else description)
            }
            .addOnFailureListener { onError(it) }
    }

    /** Traduit en français les libellés d'objets les plus courants. */
    private fun describeLabel(label: String): String {
        val map = mapOf(
            "Person" to "personne",
            "Mobile phone" to "téléphone portable",
            "Book" to "livre",
            "Bottle" to "bouteille",
            "Car" to "voiture",
            "Cat" to "chat",
            "Dog" to "chien",
            "Food" to "nourriture",
            "Chair" to "chaise",
            "Table" to "table",
            "Computer keyboard" to "clavier",
            "Laptop" to "ordinateur portable",
            "Bag" to "sac",
            "Glasses" to "lunettes",
            "Door" to "porte",
            "Window" to "fenêtre",
            "Tree" to "arbre",
            "Plant" to "plante",
            "Money" to "argent",
        )
        return map[label] ?: label.lowercase()
    }

    /** Referme les clients (libération mémoire). Ils seront recréés au besoin. */
    fun close() {
        textRecognizer?.close()
        textRecognizer = null
        labeler?.close()
        labeler = null
    }
}
