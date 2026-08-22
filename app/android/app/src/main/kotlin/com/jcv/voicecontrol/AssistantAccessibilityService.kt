package com.jcv.voicecontrol

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.MethodChannel

/**
 * Cœur du projet : le service d'accessibilité.
 *
 * C'est la SEULE voie autorisée par Android pour qu'une application puisse :
 *  - lire le contenu de n'importe quel écran (textes, boutons, listes) ;
 *  - effectuer des actions : clic, défilement, saisie de texte, retour ;
 *  - détecter les changements de fenêtre et les notifications ;
 *  - intercepter les boutons matériels (Volume+) pour un contrôle sans
 *    dépendre de la vue de l'utilisateur.
 *
 * Gestes Volume+ :
 *   - Appui simple : démarre/arrête l'écoute vocale (transmis à Flutter).
 *   - Double appui  : décroche un appel entrant / raccroche un appel en cours.
 *   - Appui long    : refuse un appel entrant.
 *
 * Il expose une instance statique (`instance`) afin que le pont natif
 * (MainActivity / MethodChannel) puisse lui demander d'agir.
 */
class AssistantAccessibilityService : AccessibilityService() {

    companion object {
        /** Instance courante du service, utilisée par le pont natif. */
        var instance: AssistantAccessibilityService? = null
            private set

        /** Indique si le service est actif (utilisé pour les vérifications côté Flutter). */
        val isRunning: Boolean
            get() = instance != null

        /** Canal Flutter utilisé pour notifier l'appui sur Volume+ (activation vocale). */
        var keyEventChannel: MethodChannel? = null

        private const val DOUBLE_PRESS_DELAY_MS = 350L
        private const val LONG_PRESS_DELAY_MS = 600L

        // Mots-clés utilisés pour repérer les boutons d'appel via leur texte ou
        // leur description d'accessibilité (contentDescription). MIUI et Android
        // stock ne nomment pas toujours ces boutons pareil ; si un cas ne matche
        // pas sur le terrain, ajouter le mot-clé manquant observé ici.
        private val ANSWER_KEYWORDS = listOf("répondre", "answer", "accept", "décrocher")
        private val HANGUP_KEYWORDS = listOf("raccrocher", "hang up", "end call", "fin d'appel")
        private val REJECT_KEYWORDS = listOf("refuser", "decline", "reject", "ignorer")
        private val INCALL_PACKAGES = listOf("com.android.incallui", "com.android.dialer", "com.miui.contacts")
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingSingleClick: Runnable? = null
    private var lastVolumeUpTime = 0L
    private var volumeUpDownTime = 0L
    private var isLongPressHandled = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_SPOKEN
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS or
                    AccessibilityServiceInfo.DEFAULT
            notificationTimeout = 100
        }
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return
        // Ici : détection des changements d'écran et des notifications.
        // Pour le MVP, on peut journaliser et, à terme, annoncer vocalement.
        // Exemple (à activer) :
        // when (event.eventType) {
        //     AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> announceCurrentScreen()
        //     AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> announceNotification(event)
        // }
    }

    override fun onInterrupt() {
        // Appelé lorsque le système interrompt le retour du service.
    }

    override fun onDestroy() {
        instance = null
        keyEventChannel = null
        mainHandler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    // ------------------------------------------------------------------
    // Interception du bouton Volume+
    // ------------------------------------------------------------------

    /**
     * Intercepte les événements de touche matérielle.
     * Retourne `true` pour consommer l'événement (empêcher le changement de
     * volume système), `false` pour laisser passer normalement.
     */
    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode != KeyEvent.KEYCODE_VOLUME_UP) {
            return super.onKeyEvent(event)
        }

        when (event.action) {
            KeyEvent.ACTION_DOWN -> {
                if (event.repeatCount == 0) {
                    volumeUpDownTime = System.currentTimeMillis()
                    isLongPressHandled = false
                    // Programme la détection d'appui long.
                    mainHandler.postDelayed({
                        if (!isLongPressHandled) {
                            isLongPressHandled = true
                            onVolumeUpLongPress()
                        }
                    }, LONG_PRESS_DELAY_MS)
                }
                return true
            }
            KeyEvent.ACTION_UP -> {
                val pressDuration = System.currentTimeMillis() - volumeUpDownTime
                if (isLongPressHandled) {
                    // Déjà traité comme appui long, on ignore le relâchement.
                    return true
                }
                if (pressDuration < LONG_PRESS_DELAY_MS) {
                    handleShortOrDoublePress()
                }
                return true
            }
        }
        return true
    }

    /** Distingue un appui simple d'un double appui. */
    private fun handleShortOrDoublePress() {
        val now = System.currentTimeMillis()
        if (now - lastVolumeUpTime < DOUBLE_PRESS_DELAY_MS) {
            // Double appui détecté : on annule l'action "simple" en attente.
            pendingSingleClick?.let { mainHandler.removeCallbacks(it) }
            pendingSingleClick = null
            lastVolumeUpTime = 0L
            onVolumeUpDoublePress()
        } else {
            lastVolumeUpTime = now
            // On attend de voir si un second appui arrive avant d'agir.
            pendingSingleClick = Runnable { onVolumeUpSinglePress() }
            mainHandler.postDelayed(pendingSingleClick!!, DOUBLE_PRESS_DELAY_MS)
        }
    }

    /** Appui simple : bascule l'écoute vocale (démarrer/arrêter), transmis à Flutter. */
    private fun onVolumeUpSinglePress() {
        keyEventChannel?.let { channel ->
            mainHandler.post { channel.invokeMethod("onVolumeUpSingle", null) }
        }
    }

    /** Double appui : décroche un appel entrant, ou raccroche un appel en cours. */
    private fun onVolumeUpDoublePress() {
        val handledCall = answerOrHangupCall()
        if (!handledCall) {
            // Pas d'appel en cours : on transmet à Flutter pour un usage éventuel
            // (ex. relire la dernière phrase, ou action personnalisée).
            keyEventChannel?.let { channel ->
                mainHandler.post { channel.invokeMethod("onVolumeUpDouble", null) }
            }
        }
    }

    /** Appui long : refuse un appel entrant si présent, sinon notifie Flutter. */
    private fun onVolumeUpLongPress() {
        val handledCall = rejectCall()
        if (!handledCall) {
            keyEventChannel?.let { channel ->
                mainHandler.post { channel.invokeMethod("onVolumeUpLong", null) }
            }
        }
    }

    // ------------------------------------------------------------------
    // Gestion d'appel (décrocher / raccrocher / refuser)
    // ------------------------------------------------------------------

    /**
     * Décroche un appel entrant si l'écran d'appel est affiché et qu'un bouton
     * "répondre" est trouvé ; sinon, si un appel est en cours, raccroche.
     * Retourne `true` si une action a été effectuée.
     */
    fun answerOrHangupCall(): Boolean {
        if (!isCallScreenVisible()) return false
        return clickByKeywords(ANSWER_KEYWORDS) || clickByKeywords(HANGUP_KEYWORDS)
    }

    /** Refuse un appel entrant si l'écran d'appel est affiché. Retourne `true` si effectué. */
    fun rejectCall(): Boolean {
        if (!isCallScreenVisible()) return false
        return clickByKeywords(REJECT_KEYWORDS) || clickByKeywords(HANGUP_KEYWORDS)
    }

    /** Vérifie si l'application au premier plan est un écran d'appel connu. */
    private fun isCallScreenVisible(): Boolean {
        val root = rootInActiveWindow ?: return false
        val pkg = root.packageName?.toString() ?: return false
        return INCALL_PACKAGES.any { pkg.contains(it, ignoreCase = true) }
    }

    /** Cherche un nœud dont le texte ou la description contient un des mots-clés, puis clique. */
    private fun clickByKeywords(keywords: List<String>): Boolean {
        val root = rootInActiveWindow ?: return false
        val node = searchNode(root) { n ->
            val text = n.text?.toString() ?: ""
            val desc = n.contentDescription?.toString() ?: ""
            keywords.any { text.contains(it, ignoreCase = true) || desc.contains(it, ignoreCase = true) }
        }
        val result = node?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false
        node?.recycle()
        return result
    }

    // ------------------------------------------------------------------
    // Lecture de l'écran
    // ------------------------------------------------------------------

    /** Retourne tout le texte visible à l'écran, concaténé ligne par ligne. */
    fun getVisibleText(): String {
        val root = rootInActiveWindow ?: return ""
        val sb = StringBuilder()
        collectText(root, sb)
        return sb.toString().trim()
    }

    private fun collectText(node: AccessibilityNodeInfo, sb: StringBuilder) {
        val text = node.text?.toString()
        if (!text.isNullOrBlank()) {
            sb.append(text).append('\n')
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            collectText(child, sb)
            // CORRECTIF mémoire : recycle chaque nœud enfant après usage,
            // indispensable sur un appareil à faible RAM (Redmi A5, 4 Go).
            child.recycle()
        }
    }

    // ------------------------------------------------------------------
    // Actions : clic, saisie, navigation
    // ------------------------------------------------------------------

    /** Recherche un nœud par son texte (partiel) et clique dessus. */
    fun clickByText(target: String): Boolean {
        val node = findNodeByText(target) ?: return false
        val result = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        node.recycle()
        return result
    }

    /** Recherche un champ de saisie et y écrit le texte donné. */
    fun typeText(text: String): Boolean {
        val node = findEditableNode() ?: return false
        val args = android.os.Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        }
        val result = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        node.recycle()
        return result
    }

    /** Effectue une action globale : retour, accueil, notifications, etc. */
    fun triggerGlobalAction(action: Int): Boolean {
        return performGlobalActionCompat(action)
    }

    /** Fait défiler l'écran vers le bas ou vers le haut. */
    fun scroll(down: Boolean): Boolean {
        val node = findScrollableNode() ?: return false
        val action = if (down) {
            AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
        } else {
            AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
        }
        val result = node.performAction(action)
        node.recycle()
        return result
    }

    // ------------------------------------------------------------------
    // Recherche de nœuds
    // ------------------------------------------------------------------

    private fun findNodeByText(target: String): AccessibilityNodeInfo? {
        val root = rootInActiveWindow ?: return null
        return searchNode(root) { node ->
            val t = node.text?.toString()
            t != null && t.contains(target, ignoreCase = true)
        }
    }

    private fun findEditableNode(): AccessibilityNodeInfo? {
        val root = rootInActiveWindow ?: return null
        return searchNode(root) { node -> node.isEditable }
    }

    private fun findScrollableNode(): AccessibilityNodeInfo? {
        val root = rootInActiveWindow ?: return null
        return searchNode(root) { node -> node.isScrollable }
    }

    /**
     * Recherche en profondeur. Les nœuds non retenus sont recyclés au fur et
     * à mesure pour limiter la pression mémoire (important sur 4 Go de RAM).
     */
    private fun searchNode(
        node: AccessibilityNodeInfo,
        predicate: (AccessibilityNodeInfo) -> Boolean
    ): AccessibilityNodeInfo? {
        if (predicate(node)) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = searchNode(child, predicate)
            if (found != null) return found
            child.recycle()
        }
        return null
    }

    /** Compat : performGlobalAction selon la version d'Android. */
    private fun performGlobalActionCompat(action: Int): Boolean {
        return try {
            performGlobalAction(action)
        } catch (e: Exception) {
            false
        }
    }
}
