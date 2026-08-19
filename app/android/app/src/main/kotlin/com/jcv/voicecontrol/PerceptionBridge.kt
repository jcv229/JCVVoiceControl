package com.jcv.voicecontrol

import io.flutter.plugin.common.MethodChannel

/**
 * Pont de communication de la perception.
 *
 * Le résultat de la caméra (texte reconnu, objets détectés) est asynchrone :
 * l'activité caméra émet le résultat vers l'interface Flutter via ce pont,
 * sans passer par onActivityResult (plus robuste avec Flutter).
 */
object PerceptionBridge {

    /** Canal vers Flutter (défini par MainActivity). */
    var channel: MethodChannel? = null

    /** Émet le résultat de la perception vers Flutter. */
    fun emitResult(text: String) {
        channel?.invokeMethod("onPerceptionResult", text)
    }
}
