import 'dart:async';

import '../../platform/native_bridge.dart';

/// Service de reconnaissance vocale (speech-to-text).
///
/// Interface abstraite : l'implémentation de production ([VoskAsrService])
/// utilise Vosk (modèle français ~40 Mo, 100 % hors-ligne) côté natif Kotlin.
/// Une implémentation de démonstration ([MockAsrService]) permet de tester la
/// chaîne sans microphone.
abstract class AsrService {
  /// Prépare le moteur (chargement du modèle).
  Future<void> init();

  /// Démarre l'écoute continue.
  Future<void> start();

  /// Arrête l'écoute.
  Future<void> stop();

  /// Flux des phrases reconnues.
  Stream<String> get onResult;

  /// Injecte manuellement une phrase (mode démonstration / tests).
  void inject(String phrase);
}

/// Implémentation de production : reconnaissance vocale Vosk, hors-ligne.
///
/// Le moteur natif ([VoskSpeechRecognizer]) écoute le microphone et renvoie
/// chaque phrase reconnue via le canal "onSpeechResult". Les erreurs (modèle
/// manquant, permission micro refusée) sont remontées via "onSpeechError".
class VoskAsrService implements AsrService {
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  bool _listening = false;

  @override
  Future<void> init() async {
    // Enregistre les écouteurs du canal natif.
    NativeBridge.setSpeechListener(
      onResult: (text) {
        if (!_controller.isClosed) _controller.add(text);
      },
      onError: (message) {
        if (!_controller.isClosed) {
          _controller.addError(message);
        }
      },
    );
  }

  @override
  Future<void> start() async {
    _listening = true;
    await NativeBridge.startListening();
  }

  @override
  Future<void> stop() async {
    _listening = false;
    await NativeBridge.stopListening();
  }

  @override
  Stream<String> get onResult => _controller.stream;

  @override
  void inject(String phrase) {
    if (!_controller.isClosed && phrase.trim().isNotEmpty) {
      _controller.add(phrase);
    }
  }

  bool get isListening => _listening;

  void dispose() {
    _controller.close();
  }
}

/// Implémentation de démonstration (sans microphone).
class MockAsrService implements AsrService {
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Stream<String> get onResult => _controller.stream;

  @override
  void inject(String phrase) {
    if (phrase.trim().isNotEmpty) {
      _controller.add(phrase);
    }
  }

  void dispose() {
    _controller.close();
  }
}
