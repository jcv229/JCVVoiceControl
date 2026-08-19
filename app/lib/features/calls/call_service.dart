import '../../core/nlu/intent.dart';
import '../../platform/native_bridge.dart';

/// Fonction F1 — Appels téléphoniques.
///
/// Hors-ligne. Résout le nom du contact en numéro (carnet d'adresses local)
/// puis passe l'appel via l'API native.
class CallService {
  /// Traite une intention d'appel et retourne le texte à prononcer.
  Future<String> handle(Intent intent) async {
    final number = intent.param('number');
    final contact = intent.param('contact');

    // Numéro dicté directement.
    if (number.isNotEmpty) {
      final ok = await NativeBridge.callNumber(number);
      if (ok) {
        return 'J\'appelle le numéro $number.';
      }
      return 'Je n\'ai pas pu appeler ce numéro. Vérifiez la permission téléphone.';
    }

    // Nom de contact : résolution vers un numéro.
    if (contact.isNotEmpty) {
      final resolved = await NativeBridge.resolveContact(contact);
      if (resolved == null) {
        return 'Je n\'ai pas trouvé le contact $contact dans votre carnet d\'adresses.';
      }
      final ok = await NativeBridge.callNumber(resolved);
      if (ok) {
        return 'J\'appelle $contact.';
      }
      return 'Je n\'ai pas pu appeler $contact.';
    }

    return 'Qui voulez-vous appeler ? Dites par exemple : appelle maman, ou appelle le numéro.';
  }
}
