package com.jcv.voicecontrol

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage

/**
 * Récepteur des SMS entrants.
 *
 * Remarque : pour recevoir les SMS de manière fiable, l'application doit être
 * définie comme application SMS par défaut (Android 4.4+). Sinon, la réception
 * peut être limitée par le système.
 *
 * Pour le MVP, ce récepteur journalise le SMS reçu. L'étape suivante consiste
 * à transmettre l'expéditeur et le contenu à l'interface Flutter pour
 * annonce vocale (via un EventChannel ou un état partagé).
 */
class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        val sender = messages.firstOrNull()?.originatingAddress ?: "Inconnu"
        val body = messages.joinToString(separator = "") { it.messageBody ?: "" }

        // TODO : transmettre (sender, body) à Flutter pour annonce vocale.
        android.util.Log.d("AssistantVocal", "SMS reçu de $sender : $body")
    }
}
