package com.jcv.voicecontrol

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

/**
 * Gestionnaire des contacts définis par l'utilisateur.
 *
 * Permet d'associer un nom (ex. "maman", "le médecin") à un numéro de téléphone,
 * stocké LOCALEMENT dans les préférences de l'application (aucune connexion,
 * aucune donnée envoyée). Ces contacts sont utilisés en priorité par les
 * fonctions d'appel, de SMS et d'urgence (SOS).
 */
object ContactStore {

    private const val PREFS_NAME = "jcv_voice_control_contacts"
    private const val KEY_CONTACTS = "contacts_json"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /** Charge le dictionnaire nom -> numéro depuis le stockage local. */
    private fun load(context: Context): MutableMap<String, String> {
        val json = prefs(context).getString(KEY_CONTACTS, null) ?: return mutableMapOf()
        return try {
            val obj = JSONObject(json)
            val map = mutableMapOf<String, String>()
            obj.keys().forEach { key -> map[key] = obj.optString(key) }
            map
        } catch (e: Exception) {
            mutableMapOf()
        }
    }

    /** Sauvegarde le dictionnaire nom -> numéro dans le stockage local. */
    private fun save(context: Context, map: Map<String, String>) {
        val obj = JSONObject()
        map.forEach { (k, v) -> obj.put(k, v) }
        prefs(context).edit().putString(KEY_CONTACTS, obj.toString()).apply()
    }

    /**
     * Enregistre (ou met à jour) un contact.
     * @return le message de confirmation en français.
     */
    fun saveContact(context: Context, name: String, number: String): String {
        val normalizedName = name.trim().lowercase()
        if (normalizedName.isEmpty() || number.isBlank()) {
            return "Le nom ou le numéro est vide."
        }
        val map = load(context)
        map[normalizedName] = number.trim()
        save(context, map)
        return "Contact enregistré : $name, au numéro ${number.trim()}."
    }

    /**
     * Recherche un contact défini par son nom.
     * @return le numéro, ou null si introuvable.
     */
    fun getContact(context: Context, name: String): String? {
        val normalizedName = name.trim().lowercase()
        return load(context)[normalizedName]
    }

    /** Supprime un contact défini. */
    fun deleteContact(context: Context, name: String): String {
        val normalizedName = name.trim().lowercase()
        val map = load(context)
        if (map.remove(normalizedName) != null) {
            save(context, map)
            return "Contact supprimé : $name."
        }
        return "Aucun contact nommé $name."
    }

    /**
     * Liste tous les contacts définis.
     * @return une liste de paires (nom, numéro), triées par nom.
     */
    fun listContacts(context: Context): List<Pair<String, String>> {
        return load(context).toList().sortedBy { it.first }
    }

    /** Retourne une phrase lisible listant tous les contacts définis. */
    fun listContactsAsText(context: Context): String {
        val contacts = listContacts(context)
        if (contacts.isEmpty()) {
            return "Aucun contact défini. Dites : définis le contact, puis le nom et le numéro."
        }
        val sb = StringBuilder("Vos contacts définis : ")
        contacts.forEach { (name, number) ->
            sb.append("$name, $number. ")
        }
        return sb.toString()
    }
}
