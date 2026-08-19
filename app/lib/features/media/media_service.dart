import '../../core/nlu/intent.dart';
import '../../platform/native_bridge.dart';

/// Fonction F5 (partie médias) — musique locale.
///
/// Hors-ligne : lecture de la bibliothèque musicale locale (MediaPlayer) et
/// contrôle de la lecture (pause, suivant, précédent, volume).
class MediaService {
  Future<String> handlePlay() async {
    return NativeBridge.playMusic();
  }

  Future<String> handlePause() async {
    return NativeBridge.pauseMusic();
  }

  Future<String> handleResume() async {
    return NativeBridge.resumeMusic();
  }

  Future<String> handleNext() async {
    return NativeBridge.nextTrack();
  }

  Future<String> handlePrevious() async {
    return NativeBridge.previousTrack();
  }
}

/// Lecture vidéo locale.
///
/// Hors-ligne : ouvre le sélecteur de vidéo puis lance le lecteur système.
/// Le contrôle de la lecture (pause, avance) est géré par le lecteur système,
/// lui-même pilotable via le service d'accessibilité si besoin.
class VideoService {
  Future<String> handlePlay() async {
    final ok = await NativeBridge.openVideoPicker();
    if (!ok) {
      return 'Je n\'ai pas pu ouvrir le sélecteur de vidéo.';
    }
    return 'Sélectionnez la vidéo à regarder. '
        'Je la lancerai dans le lecteur vidéo.';
  }
}
