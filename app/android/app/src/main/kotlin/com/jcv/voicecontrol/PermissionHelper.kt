package com.jcv.voicecontrol

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build

/**
 * Helper pour lister les permissions des applications installées.
 *
 * Rappel de sécurité : Android interdit à une application de MODIFIER les
 * permissions d'une autre application. Cet helper permet uniquement de LIRE
 * et d'EXPLIQUER les permissions, puis de guider l'utilisateur vers l'écran
 * de réglages (via openAppDetails dans MainActivity).
 */
object PermissionHelper {

    /**
     * Résout un nom d'application (libellé affiché) en nom de package.
     * Retourne null si aucune application installée ne correspond.
     */
    fun resolveAppNameToPackage(context: Context, name: String): String? {
        val pm = context.packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        for (app in apps) {
            val label = pm.getApplicationLabel(app).toString()
            if (label.contains(name, ignoreCase = true)) {
                return app.packageName
            }
        }
        return null
    }

    /**
     * Retourne la liste des permissions déclarées par une application,
     * sous forme de Map<String, Boolean> (nom -> accordée ou non).
     */
    fun getPermissions(context: Context, packageName: String): Map<String, Boolean> {
        val result = mutableMapOf<String, Boolean>()
        try {
            val pm = context.packageManager
            val info = pm.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
            val requested = info.requestedPermissions ?: return result
            for (permission in requested) {
                val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
                } else {
                    true // avant Android 6, les permissions sont accordées à l'installation
                }
                result[permission] = granted
            }
        } catch (e: PackageManager.NameNotFoundException) {
            android.util.Log.e("AssistantVocal", "Application introuvable : $packageName", e)
        }
        return result
    }
}
