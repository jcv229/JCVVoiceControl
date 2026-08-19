package com.jcv.voicecontrol

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Criteria
import android.location.LocationManager
import androidx.core.content.ContextCompat

/**
 * Helper pour obtenir la position GPS (utilisée par la fonction SOS).
 * Entièrement local : utilise le GPS de l'appareil, aucune connexion requise.
 */
object LocationHelper {

    /**
     * Retourne la dernière position connue sous la forme "latitude,longitude",
     * ou null si la localisation n'est pas disponible (permission refusée,
     * GPS désactivé, etc.).
     */
    fun getLastLocation(context: Context): String? {
        if (ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return null
        }
        val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val provider = lm.getBestProvider(Criteria(), true) ?: return null
        val location = lm.getLastKnownLocation(provider) ?: return null
        return "${location.latitude},${location.longitude}"
    }
}
