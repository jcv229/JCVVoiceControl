import '../../core/nlu/intent.dart';
import '../../platform/native_bridge.dart';

/// Fonction F2 — SMS.
///
/// Hors-ligne. Pour lire ET écrire les SMS de façon fiable, l'application doit
/// être définie comme application SMS par défaut (Android 4.4+).
class SmsService {
  Future<String> handleSend(Intent intent) async {
    final contact = intent.param('contact');
    final message = intent.param('message');

    if (message.isEmpty) {
      return 'Que voulez-vous écrire dans le message ?';
    }
    if (contact.isEmpty) {
      return 'À qui dois-je envoyer ce message ? Dites : envoie un SMS à, puis le nom.';
    }

    // Résolution du contact en numéro.
    final number = await NativeBridge.resolveContact(contact);
    if (number == null) {
      return 'Je n\'ai pas trouvé le contact $contact dans votre carnet d\'adresses.';
    }

    final ok = await NativeBridge.sendSms(number, message);
    if (ok) {
      return 'Message envoyé à $contact : $message';
    }
    return 'Je n\'ai pas pu envoyer le message. Vérifiez que l\'application est définie comme application SMS par défaut.';
  }

  Future<String> handleRead() async {
    final messages = await NativeBridge.getLastSms(count: 5);
    if (messages.isEmpty) {
      return 'Vous n\'avez aucun message.';
    }

    final buffer = StringBuffer();
    buffer.write('Voici vos derniers messages. ');
    for (final m in messages) {
      final sender = m['sender'] ?? 'Inconnu';
      final body = m['body'] ?? '';
      buffer.write('De $sender : $body. ');
    }
    return buffer.toString();
  }
}
