import '../../core/nlu/intent.dart';
import '../../platform/native_bridge.dart';

/// Fonction F10 — Sécurité et urgence (SOS).
///
/// Hors-ligne : la commande SOS envoie un SMS d'alerte (avec la position GPS)
/// à tous les contacts définis dans l'application.
class EmergencyService {
  Future<String> handleSos() async {
    // Récupère la position GPS locale.
    final location = await NativeBridge.getLocation();
    final locationText = location != null
        ? 'Ma position est : $location.'
        : 'Position indisponible.';

    final message = 'Alerte SOS. $locationText';

    // Envoie l'alerte à tous les contacts définis.
    final numbers = await NativeBridge.getSavedContactNumbers();
    if (numbers.isEmpty) {
      return 'Aucun contact d\'urgence n\'est défini. '
          'Dites : définis le contact, puis le nom et le numéro, pour enregistrer un contact.';
    }

    var sentCount = 0;
    for (final number in numbers) {
      final ok = await NativeBridge.sendSms(number, message);
      if (ok) sentCount++;
    }

    if (sentCount > 0) {
      return 'Alerte : j\'ai envoyé un message d\'urgence à $sentCount contact'
          '${sentCount > 1 ? 's' : ''}. $locationText';
    }
    return 'Je n\'ai pas pu envoyer l\'alerte. Vérifiez vos contacts définis.';
  }
}
