package com.jcv.voicecontrol

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.Executors

/**
 * Activité caméra de la perception assistée.
 *
 * Affiche un aperçu plein écran, analyse les images en continu :
 *  - mode "ocr"   : reconnaissance de texte (ML Kit), lu ensuite à voix haute ;
 *  - mode "label" : détection d'objets (ML Kit), description à voix haute.
 *
 * Le résultat est renvoyé à l'interface Flutter via [PerceptionBridge], puis
 * l'activité se ferme. Deux façons de terminer :
 *  1. le texte/les objets sont stables (3 lectures identiques) → retour auto ;
 *  2. l'utilisateur appuie sur le gros bouton « LIRE À VOIX HAUTE ».
 */
class CameraActivity : ComponentActivity() {

    companion object {
        const val EXTRA_MODE = "mode"
        const val MODE_OCR = "ocr"
        const val MODE_LABEL = "label"
        private const val REQUEST_CAMERA = 200
        private const val STABLE_THRESHOLD = 3
    }

    private lateinit var previewView: PreviewView
    private lateinit var statusText: TextView
    private val analysisExecutor = Executors.newSingleThreadExecutor()

    private var mode: String = MODE_OCR
    private var lastResult = ""
    private var stableCount = 0
    private var finished = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        mode = intent.getStringExtra(EXTRA_MODE) ?: MODE_OCR

        buildLayout()

        if (hasCameraPermission()) {
            startCamera()
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.CAMERA),
                REQUEST_CAMERA
            )
        }
    }

    /** Construit l'interface (programmatiquement, sans fichier XML). */
    private fun buildLayout() {
        previewView = PreviewView(this)
        statusText = TextView(this).apply {
            text = if (mode == MODE_LABEL) {
                "Pointez la caméra vers l'objet à identifier."
            } else {
                "Pointez la caméra vers le texte à lire."
            }
            textSize = 22f
            gravity = Gravity.CENTER
            setPadding(24, 16, 24, 16)
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#1D4ED8"))
        }
        val readButton = Button(this).apply {
            text = "LIRE À VOIX HAUTE"
            textSize = 22f
            setOnClickListener { finishWithResult(statusText.text.toString()) }
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.BLACK)
        }
        layout.addView(
            previewView,
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
        )
        layout.addView(
            statusText,
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        )
        layout.addView(
            readButton,
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        )
        setContentView(layout)
    }

    private fun hasCameraPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CAMERA) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startCamera()
            } else {
                finishWithResult("Permission caméra refusée. Je ne peux pas lire le texte sans elle.")
            }
        }
    }

    /** Démarre la caméra : aperçu + analyse d'images en continu. */
    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()

            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also { it.setAnalyzer(analysisExecutor, ::analyze) }

            try {
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(
                    this,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    imageAnalysis
                )
            } catch (e: Exception) {
                finishWithResult("Impossible d'ouvrir la caméra.")
            }
        }, ContextCompat.getMainExecutor(this))
    }

    /** Analyse chaque image : OCR ou détection d'objets selon le mode. */
    private fun analyze(imageProxy: ImageProxy) {
        if (finished) {
            imageProxy.close()
            return
        }
        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close()
            return
        }
        val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)

        when (mode) {
            MODE_LABEL -> PerceptionEngine.labelImage(
                image,
                onResult = { onNewResult(it, imageProxy) },
                onError = { imageProxy.close() }
            )
            else -> PerceptionEngine.recognizeText(
                image,
                onResult = { onNewResult(it, imageProxy) },
                onError = { imageProxy.close() }
            )
        }
    }

    /** Traite un nouveau résultat : affichage + détection de stabilité. */
    private fun onNewResult(text: String, imageProxy: ImageProxy) {
        imageProxy.close()
        val t = text.trim()
        if (t.isBlank()) return
        runOnUiThread {
            statusText.text = t
            if (t == lastResult) {
                stableCount++
                if (stableCount >= STABLE_THRESHOLD) {
                    finishWithResult(t)
                }
            } else {
                lastResult = t
                stableCount = 0
            }
        }
    }

    /** Envoie le résultat à Flutter et ferme l'activité. */
    private fun finishWithResult(text: String) {
        if (finished) return
        finished = true
        val resultText = if (text.isBlank()) "Je n'ai rien pu lire." else text
        PerceptionBridge.emitResult(resultText)
        setResult(RESULT_OK, Intent().putExtra("text", resultText))
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        analysisExecutor.shutdown()
        PerceptionEngine.close()
    }
}
