package com.jcv.voicecontrol

import android.content.Context
import android.provider.ContactsContract

/**
 * Helper pour résoudre un nom de contact en numéro de téléphone.
 * Utilise le carnet d'adresses local (aucune connexion requise).
 */
object ContactHelper {

    /**
     * Cherche un contact dont le nom contient [name] et retourne son
     * numéro de téléphone, ou null si aucun contact ne correspond.
     */
    fun resolveNameToNumber(context: Context, name: String): String? {
        val contentResolver = context.contentResolver
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.NUMBER,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME
        )
        val selection = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?"
        val selectionArgs = arrayOf("%$name%")

        contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getString(0)
            }
        }
        return null
    }
}
