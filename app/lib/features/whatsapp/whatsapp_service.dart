import '../../core/nlu/intent.dart';
import '../../platform/native_bridge.dart';

/// Fonction F3 — WhatsApp.
///
/// Hors-ligne (le traitement est local). WhatsApp n'offrant aucune API publique,
/// l'automatisation repose sur le service d'accessibilité : ouvrir l'app, lire
/// l'écran, cliquer, saisir, envoyer.
///
/// Limite connue : la structure de l'écran dépend des versions de WhatsApp,
/// ce qui impose une maintenance régulière.
class WhatsAppService {
  static const String packageName = 'com.whatsapp';

  Future<String> handleSend(Intent intent) async {
    final contact = intent.param('contact');
    final message = intent.param('message');

    if (message.isEmpty) {
      return 'Que voulez-vous envoyer sur WhatsApp ?';
    }
    if (contact.isEmpty) {
      return 'À qui voulez-vous envoyer ce message WhatsApp ?';
    }

    final enabled = await NativeBridge.isAccessibilityEnabled();
    if (!enabled) {
      return 'Le service d\'accessibilité n\'est pas activé. '
          'Activez-le dans les réglages pour que je puisse piloter WhatsApp.';
    }

    // Ouvre WhatsApp (local).
    final opened = await NativeBridge.openPackage(packageName);
    if (!opened) {
      return 'WhatsApp ne semble pas installé sur cet appareil.';
    }

    // Séquence d'automatisation d'écran (avec petites pauses pour laisser
    // l'interface se charger). Les libellés dépendent de la version de
    // WhatsApp ; ils sont centralisés ici pour faciliter la maintenance.
    await _pause(const Duration(milliseconds: 1200));

    // 1. Ouvrir un nouveau chat (bouton "nouvelle discussion").
    final clickedNewChat = await NativeBridge.clickByText('Nouvelle discussion');
    if (!clickedNewChat) {
      await NativeBridge.clickByText('New chat');
    }
    await _pause(const Duration(milliseconds: 800));

    // 2. Rechercher le contact.
    await NativeBridge.clickByText('Rechercher');
    await _pause(const Duration(milliseconds: 400));
    await NativeBridge.typeText(contact);
    await _pause(const Duration(milliseconds: 800));

    // 3. Cliquer sur le contact.
    await NativeBridge.clickByText(contact);
    await _pause(const Duration(milliseconds: 800));

    // 4. Saisir le message.
    await NativeBridge.typeText(message);
    await _pause(const Duration(milliseconds: 400));

    // 5. Envoyer.
    final sent = await NativeBridge.clickByText('Envoyer');
    if (!sent) {
      await NativeBridge.clickByText('Send');
    }

    return 'Message WhatsApp envoyé à $contact : $message';
  }

  Future<String> handleRead() async {
    final enabled = await NativeBridge.isAccessibilityEnabled();
    if (!enabled) {
      return 'Le service d\'accessibilité n\'est pas activé. '
          'Activez-le dans les réglages pour lire vos messages WhatsApp.';
    }
    final text = await NativeBridge.getVisibleText();
    if (text.isEmpty) {
      return 'Je ne vois rien à l\'écran. Ouvrez WhatsApp, puis dites : lis mes messages.';
    }
    return 'Voici ce qui est affiché : $text';
  }

  Future<void> _pause(Duration d) => Future.delayed(d);
}
