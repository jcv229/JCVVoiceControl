package com.jcv.voicecontrol

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * Lecture de documents (texte + PDF) à voix haute.
 *
 * Approche 100 % hors-ligne :
 *  - fichiers texte (.txt, .md) : lecture directe ;
 *  - PDF : rendu page par page (PdfRenderer) puis OCR via ML Kit.
 *    Cette approche fonctionne aussi bien pour les PDF « texte » que pour les
 *    PDF scannés (documents, courriers), sans nécessiter de dépendance lourde.
 *
 * Le résultat (texte complet) est renvoyé de façon asynchrone via [onDone].
 */
object DocumentReader {

    private val textRecognizer: TextRecognizer =
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    /**
     * Lit un document pointé par [uri] et transmet le texte extrait à [onDone].
     */
    fun readText(
        context: Context,
        uri: Uri,
        onDone: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        val fileName = getFileName(context, uri).lowercase()
        when {
            fileName.endsWith(".txt") || fileName.endsWith(".md") -> {
                try {
                    onDone(readPlainText(context, uri))
                } catch (e: Exception) {
                    onError("Impossible de lire le fichier : ${e.message}")
                }
            }
            fileName.endsWith(".pdf") -> readPdf(context, uri, onDone, onError)
            else -> onDone(
                "Ce type de fichier n'est pas encore pris en charge. " +
                    "Je sais lire les fichiers texte et les PDF."
            )
        }
    }

    /** Lit un fichier texte simple. */
    private fun readPlainText(context: Context, uri: Uri): String {
        val sb = StringBuilder()
        context.contentResolver.openInputStream(uri)?.use { stream ->
            BufferedReader(InputStreamReader(stream)).useLines { lines ->
                lines.forEach { sb.append(it).append('\n') }
            }
        }
        val text = sb.toString().trim()
        return if (text.isEmpty()) "Ce fichier est vide." else text
    }

    /**
     * Rend chaque page du PDF en image, puis applique l'OCR. Les pages sont
     * traitées séquentiellement (l'OCR ML Kit est asynchrone).
     */
    private fun readPdf(
        context: Context,
        uri: Uri,
        onDone: (String) -> Unit,
        onError: (String) -> Unit
    ) {
        var pfd: ParcelFileDescriptor? = null
        var renderer: PdfRenderer? = null
        try {
            pfd = context.contentResolver.openFileDescriptor(uri, "r")
            if (pfd == null) {
                onError("Impossible d'ouvrir le PDF.")
                return
            }
            renderer = PdfRenderer(pfd)
            val pageCount = renderer.pageCount
            val allText = StringBuilder()

            // Fonction locale récursive pour traiter les pages une par une.
            fun processPage(index: Int) {
                if (index >= pageCount) {
                    renderer!!.close()
                    pfd!!.close()
                    val result = allText.toString().trim()
                    onDone(
                        if (result.isEmpty()) "Aucun texte détecté dans ce document."
                        else result
                    )
                    return
                }

                val page = renderer!!.openPage(index)
                val bitmap = Bitmap.createBitmap(
                    page.width,
                    page.height,
                    Bitmap.Config.ARGB_8888
                )
                bitmap.eraseColor(Color.WHITE)
                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                page.close()

                val image = InputImage.fromBitmap(bitmap, 0)
                textRecognizer.process(image)
                    .addOnSuccessListener { visionText ->
                        allText.append(visionText.text).append('\n')
                        bitmap.recycle()
                        processPage(index + 1)
                    }
                    .addOnFailureListener { e ->
                        bitmap.recycle()
                        renderer!!.close()
                        pfd!!.close()
                        onError("Erreur lors de la lecture du PDF : ${e.message}")
                    }
            }

            processPage(0)
        } catch (e: Exception) {
            try { renderer?.close() } catch (_: Exception) {}
            try { pfd?.close() } catch (_: Exception) {}
            onError("Impossible de lire le PDF : ${e.message}")
        }
    }

    /** Récupère le nom du fichier à partir de l'URI. */
    private fun getFileName(context: Context, uri: Uri): String {
        var name = "document"
        context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && cursor.moveToFirst()) {
                cursor.getString(nameIndex)?.let { name = it }
            }
        }
        return name
    }
}
