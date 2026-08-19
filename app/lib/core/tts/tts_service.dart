import 'package:flutter_tts/flutter_tts.dart';

import '../config.dart';

/// Service de synthèse vocale (text-to-speech).
///
/// Utilise le moteur TTS d'Android avec des voix françaises téléchargées
/// sur l'appareil : entièrement hors-ligne.
class TtsService {
  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;

  /// Initialise la langue et les réglages de la voix.
  Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage(AppConfig.locale);
    await _tts.setSpeechRate(AppConfig.speechRate);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  /// Parle immédiatement (interrompt la lecture en cours).
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Interrompt la lecture en cours.
  Future<void> stop() async {
    await _tts.stop();
  }

  /// Libère les ressources.
  Future<void> dispose() async {
    await _tts.stop();
  }
}
