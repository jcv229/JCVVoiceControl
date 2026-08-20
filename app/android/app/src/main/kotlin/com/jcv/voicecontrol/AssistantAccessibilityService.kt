package com.jcv.voicecontrol

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Cœur du projet : le service d'accessibilité.
 *
 * C'est la SEULE voie autorisée par Android pour qu'une application puisse :
 *  - lire le contenu de n'importe quel écran (textes, boutons, listes) ;
 *  - effectuer des actions : clic, défilement, saisie de texte, retour ;
 *  - détecter les changements de fenêtre et les notifications.
 *
 * Ce service est indispensable pour piloter WhatsApp, la navigation ou
 * n'importe quelle application tierce. Sans lui, rien n'est possible.
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
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_SPOKEN
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
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
        super.onDestroy()
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
        }
    }

    // ------------------------------------------------------------------
    // Actions : clic, saisie, navigation
    // ------------------------------------------------------------------

    /** Recherche un nœud par son texte (partiel) et clique dessus. */
    fun clickByText(target: String): Boolean {
        val node = findNodeByText(target) ?: return false
        val result = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        return result
    }

    /** Recherche un champ de saisie et y écrit le texte donné. */
    fun typeText(text: String): Boolean {
        val node = findEditableNode() ?: return false
        val args = android.os.Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        }
        return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    /** Effectue une action globale : retour, accueil, notifications, etc. */
    override fun performGlobalAction(action: Int): Boolean {
        return super.performGlobalAction(action)
    }

    /** Fait défiler l'écran vers le bas ou vers le haut. */
    fun scroll(down: Boolean): Boolean {
        val node = findScrollableNode() ?: return false
        val action = if (down) {
            AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
        } else {
            AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
        }
        return node.performAction(action)
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

    private fun searchNode(
        node: AccessibilityNodeInfo,
        predicate: (AccessibilityNodeInfo) -> Boolean
    ): AccessibilityNodeInfo? {
        if (predicate(node)) return node
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = searchNode(child, predicate)
            if (found != null) return found
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
