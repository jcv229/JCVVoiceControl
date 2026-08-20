package com.jcv.voicecontrol

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.telephony.SmsManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activité principale de l'application.
 * Elle héberge le moteur Flutter (interface utilisateur) et expose un pont
 * de communication (MethodChannel) entre le code Dart et le code natif Android.
 *
 * Les actions sensibles (appels, SMS, ouverture de réglages) sont implémentées
 * ici en Kotlin natif, car elles nécessitent des API Android non accessibles
 * depuis Flutter.
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "jcv_voice_control/native"
        private const val REQUEST_OPEN_DOCUMENT = 1001
        private const val REQUEST_OPEN_VIDEO = 1002
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        // Expose le canal au pont de perception (résultats asynchrones de la caméra).
        PerceptionBridge.channel = channel
        channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "callNumber" -> {
                        val number = call.argument<String>("number")
                        callNumber(number, result)
                    }
                    "sendSms" -> {
                        val number = call.argument<String>("number")
                        val message = call.argument<String>("message")
                        sendSms(number, message, result)
                    }
                    "openAccessibilitySettings" -> {
                        openAccessibilitySettings(result)
                    }
                    "isAccessibilityEnabled" -> {
                        result.success(AssistantAccessibilityService.isRunning)
                    }
                    "openAppDetails" -> {
                        val packageName = call.argument<String>("packageName")
                        openAppDetails(packageName, result)
                    }
                    "getInstalledPermissions" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            result.success(PermissionHelper.getPermissions(this, packageName))
                        } else {
                            result.success(emptyMap<String, Boolean>())
                        }
                    }
                    "getBatteryLevel" -> {
                        result.success(getBatteryLevel())
                    }
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        openUrl(url, result)
                    }
                    // --- Actions du service d'accessibilité ---
                    "getVisibleText" -> {
                        result.success(AssistantAccessibilityService.instance?.getVisibleText() ?: "")
                    }
                    "clickByText" -> {
                        val text = call.argument<String>("text")
                        result.success(AssistantAccessibilityService.instance?.clickByText(text ?: "") ?: false)
                    }
                    "typeText" -> {
                        val text = call.argument<String>("text")
                        result.success(AssistantAccessibilityService.instance?.typeText(text ?: "") ?: false)
                    }
                    "pressBack" -> {
                        result.success(
                            AssistantAccessibilityService.instance
                                ?.triggerGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_BACK) ?: false
                        )
                    }
                    "pressHome" -> {
                        result.success(
                            AssistantAccessibilityService.instance
                                ?.triggerGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_HOME) ?: false
                        )
                    }
                    "scrollDown" -> {
                        result.success(AssistantAccessibilityService.instance?.scroll(true) ?: false)
                    }
                    "scrollUp" -> {
                        result.success(AssistantAccessibilityService.instance?.scroll(false) ?: false)
                    }
                    // --- Perception assistée ---
                    "startPerception" -> {
                        val mode = call.argument<String>("mode") ?: "ocr"
                        startPerception(mode, result)
                    }
                    // --- Contacts ---
                    "resolveContact" -> {
                        val name = call.argument<String>("name")
                        result.success(
                            if (name.isNullOrBlank()) null
                            else resolveContactNumber(name)
                        )
                    }
                    "saveContact" -> {
                        val name = call.argument<String>("name")
                        val number = call.argument<String>("number")
                        result.success(ContactStore.saveContact(this, name ?: "", number ?: ""))
                    }
                    "listSavedContacts" -> {
                        result.success(ContactStore.listContactsAsText(this))
                    }
                    "deleteContact" -> {
                        val name = call.argument<String>("name")
                        result.success(ContactStore.deleteContact(this, name ?: ""))
                    }
                    "getSavedContactNumbers" -> {
                        result.success(ContactStore.listContacts(this).map { it.second })
                    }
                    // --- SMS (lecture) ---
                    "getLastSms" -> {
                        val count = call.argument<Int>("count") ?: 5
                        result.success(
                            SmsHelper.getLastMessages(this, count).map {
                                mapOf("sender" to it.sender, "body" to it.body, "date" to it.date)
                            }
                        )
                    }
                    // --- Musique ---
                    "playMusic" -> {
                        result.success(MediaHelper.play(this))
                    }
                    "pauseMusic" -> {
                        result.success(MediaHelper.pause())
                    }
                    "resumeMusic" -> {
                        result.success(MediaHelper.resume())
                    }
                    "nextTrack" -> {
                        result.success(MediaHelper.next())
                    }
                    "previousTrack" -> {
                        result.success(MediaHelper.previous())
                    }
                    // --- Volume ---
                    "volumeUp" -> {
                        result.success(MediaHelper.volumeUp(this))
                    }
                    "volumeDown" -> {
                        result.success(MediaHelper.volumeDown(this))
                    }
                    "volumeSet" -> {
                        val level = call.argument<Int>("level") ?: 50
                        result.success(MediaHelper.volumeSet(this, level))
                    }
                    // --- Localisation (SOS) ---
                    "getLocation" -> {
                        result.success(LocationHelper.getLastLocation(this))
                    }
                    // --- Torche ---
                    "torchOn" -> {
                        setTorch(true, result)
                    }
                    "torchOff" -> {
                        setTorch(false, result)
                    }
                    // --- Lancement d'application ---
                    "openPackage" -> {
                        val packageName = call.argument<String>("packageName")
                        openPackage(packageName, result)
                    }
                    // --- Résolution d'application (nom -> package) ---
                    "resolveApp" -> {
                        val name = call.argument<String>("name")
                        result.success(
                            if (name.isNullOrBlank()) null
                            else PermissionHelper.resolveAppNameToPackage(this, name)
                        )
                    }
                    // --- Reconnaissance vocale (Vosk) ---
                    "startListening" -> {
                        VoskSpeechRecognizer.start(
                            this,
                            onResult = { text ->
                                channel.invokeMethod("onSpeechResult", text)
                            },
                            onError = { message ->
                                channel.invokeMethod("onSpeechError", message)
                            },
                            onPartial = { text ->
                                channel.invokeMethod("onSpeechPartial", text)
                            }
                        )
                        result.success(true)
                    }
                    "stopListening" -> {
                        VoskSpeechRecognizer.stop()
                        result.success(true)
                    }
                    // --- Lecture de documents ---
                    "openDocumentPicker" -> {
                        openDocumentPicker(result)
                    }
                    // --- Lecture vidéo ---
                    "openVideoPicker" -> {
                        openVideoPicker(result)
                    }
                    // --- Réglages rapides ---
                    "openWifiSettings" -> {
                        openSettingsPanel(Settings.ACTION_WIFI_SETTINGS, result)
                    }
                    "openBluetoothSettings" -> {
                        openSettingsPanel(Settings.ACTION_BLUETOOTH_SETTINGS, result)
                    }
                    "openAirplaneModeSettings" -> {
                        openSettingsPanel(Settings.ACTION_AIRPLANE_MODE_SETTINGS, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Passe un appel téléphonique. Nécessite la permission CALL_PHONE. */
    private fun callNumber(number: String?, result: MethodChannel.Result) {
        if (number.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "Numéro vide", null)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$number"))
            startActivity(intent)
            result.success(true)
        } catch (e: SecurityException) {
            result.error("NO_PERMISSION", "Permission CALL_PHONE manquante", e.message)
        }
    }

    /**
     * Résout un nom en numéro : cherche d'abord dans les contacts définis,
     * puis dans le carnet d'adresses système.
     */
    private fun resolveContactNumber(name: String): String? {
        return ContactStore.getContact(this, name)
            ?: ContactHelper.resolveNameToNumber(this, name)
    }

    /** Envoie un SMS. Nécessite la permission SEND_SMS. */
    private fun sendSms(number: String?, message: String?, result: MethodChannel.Result) {
        if (number.isNullOrBlank() || message.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "Numéro ou message vide", null)
            return
        }
        try {
            val smsManager = SmsManager.getDefault()
            smsManager.sendTextMessage(number, null, message, null, null)
            result.success(true)
        } catch (e: SecurityException) {
            result.error("NO_PERMISSION", "Permission SEND_SMS manquante", e.message)
        }
    }

    /** Ouvre les réglages d'accessibilité pour permettre à l'utilisateur d'activer le service. */
    private fun openAccessibilitySettings(result: MethodChannel.Result) {
        try {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Impossible d'ouvrir les réglages", e.message)
        }
    }

    /** Ouvre l'écran de détails d'une application (permissions, réglages). */
    private fun openAppDetails(packageName: String?, result: MethodChannel.Result) {
        if (packageName.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "Package vide", null)
            return
        }
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Impossible d'ouvrir les détails", e.message)
        }
    }

    /** Récupère le niveau de batterie (0-100). */
    private fun getBatteryLevel(): Int {
        val bm = getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
        return bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }

    /** Ouvre une URL dans le navigateur (modules en ligne : YouTube, web). */
    private fun openUrl(url: String?, result: MethodChannel.Result) {
        if (url.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "URL vide", null)
            return
        }
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Impossible d'ouvrir l'URL", e.message)
        }
    }

    /**
     * Lance l'activité caméra de la perception assistée.
     * @param mode "ocr" (lire un texte) ou "label" (identifier des objets).
     */
    private fun startPerception(mode: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(this, CameraActivity::class.java)
            intent.putExtra(CameraActivity.EXTRA_MODE, mode)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Impossible d'ouvrir la caméra", e.message)
        }
    }

    /** Allume ou éteint la lampe torche (via CameraManager). */
    private fun setTorch(on: Boolean, result: MethodChannel.Result) {
        try {
            val cm = getSystemService(Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
            val cameraId = cm.cameraIdList.firstOrNull()
            if (cameraId == null) {
                result.success("La lampe torche n'est pas disponible sur cet appareil.")
                return
            }
            cm.setTorchMode(cameraId, on)
            result.success(if (on) "Lampe torche allumée." else "Lampe torche éteinte.")
        } catch (e: Exception) {
            result.error("ERROR", "Impossible de contrôler la lampe torche", e.message)
        }
    }

    /** Lance une application par son nom de package (ex. WhatsApp). */
    private fun openPackage(packageName: String?, result: MethodChannel.Result) {
        if (packageName.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "Package vide", null)
            return
        }
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent == null) {
                result.error("NOT_FOUND", "Application non trouvée : $packageName", null)
                return
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Impossible de lancer l'application", e.message)
        }
    }

    /** Ouvre le sélecteur de fichier pour choisir un document (texte ou PDF). */
    private fun openDocumentPicker(result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("text/plain", "application/pdf"))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivityForResult(intent, REQUEST_OPEN_DOCUMENT)
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Impossible d'ouvrir le sélecteur de fichier", e.message)
        }
    }

    /** Ouvre un panneau de réglage système (Wi-Fi, Bluetooth, mode avion…). */
    private fun openSettingsPanel(action: String, result: MethodChannel.Result) {
        try {
            startActivity(Intent(action))
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Impossible d'ouvrir les réglages", e.message)
        }
    }

    /** Ouvre le sélecteur de fichier pour choisir une vidéo locale. */
    private fun openVideoPicker(result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "video/*"
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivityForResult(intent, REQUEST_OPEN_VIDEO)
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Impossible d'ouvrir le sélecteur de vidéo", e.message)
        }
    }

    /** Reçoit le document choisi puis extrait son texte (OCR pour les PDF). */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK || data?.data == null) {
            return
        }
        val uri = data.data!!
        when (requestCode) {
            REQUEST_OPEN_DOCUMENT -> {
                DocumentReader.readText(
                    this,
                    uri,
                    onDone = { text ->
                        PerceptionBridge.channel?.invokeMethod("onDocumentText", text)
                    },
                    onError = { message ->
                        PerceptionBridge.channel?.invokeMethod("onDocumentText", message)
                    }
                )
            }
            REQUEST_OPEN_VIDEO -> {
                playVideo(uri)
            }
        }
    }

    /** Lance la lecture d'une vidéo locale via le lecteur système. */
    private fun playVideo(uri: Uri) {
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "video/*")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
        } catch (e: Exception) {
            PerceptionBridge.channel?.invokeMethod(
                "onDocumentText",
                "Je n'ai pas pu lire cette vidéo."
            )
        }
    }
}
