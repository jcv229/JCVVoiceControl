package com.jcv.voicecontrol

import android.content.Context
import android.provider.Telephony

/**
 * Helper pour lire les SMS reçus depuis la base locale.
 *
 * Remarque : la lecture de la base SMS exige la permission READ_SMS et,
 * selon les versions d'Android, que l'application soit définie comme
 * application SMS par défaut.
 */
object SmsHelper {

    /** Un message SMS simplifié. */
    data class Sms(val sender: String, val body: String, val date: Long)

    /**
     * Retourne les [count] derniers SMS reçus (du plus récent au plus ancien).
     */
    fun getLastMessages(context: Context, count: Int = 5): List<Sms> {
        val messages = mutableListOf<Sms>()
        val uri = Telephony.Sms.Inbox.CONTENT_URI
        context.contentResolver.query(
            uri,
            arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE),
            null,
            null,
            "${Telephony.Sms.DATE} DESC"
        )?.use { cursor ->
            val addr = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val body = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val date = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
            while (cursor.moveToNext() && messages.size < count) {
                messages.add(
                    Sms(
                        sender = cursor.getString(addr) ?: "Inconnu",
                        body = cursor.getString(body) ?: "",
                        date = cursor.getLong(date)
                    )
                )
            }
        }
        return messages
    }
}
