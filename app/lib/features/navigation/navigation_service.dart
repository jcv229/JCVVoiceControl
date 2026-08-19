import '../../core/nlu/intent.dart';
import '../../platform/native_bridge.dart';

/// Fonction F6 — Navigation.
///
/// Utilise Google Maps (avec cartes hors-ligne préalablement téléchargées).
/// Le guidage vocal tour-par-tour est fourni par Google Maps.
class NavigationService {
  Future<String> handle(Intent intent) async {
    final destination = intent.param('destination');

    if (destination.isEmpty) {
      return 'Où voulez-vous aller ? Dites : guide-moi vers, puis la destination.';
    }

    // Ouvre Google Maps avec l'itinéraire vers la destination dictée.
    final uri = 'geo:0,0?q=${Uri.encodeComponent(destination)}';
    final ok = await NativeBridge.openUrl(uri);
    if (ok) {
      return 'J\'ouvre Google Maps pour vous guider vers $destination.';
    }
    return 'Je n\'ai pas pu ouvrir la navigation.';
  }
}
