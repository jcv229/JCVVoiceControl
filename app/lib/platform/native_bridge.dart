import 'package:flutter/services.dart';

/// Pont de communication entre le code Dart (Flutter) et le code natif (Kotlin).
///
/// Chaque méthode appelle une fonction native exposée dans [MainActivity].
/// Les actions sensibles (appels, SMS, réglages, lecture d'écran) sont ainsi
/// exécutées par le système Android.
class NativeBridge {
  static const MethodChannel _channel = MethodChannel('jcv_voice_control/native');

  // --- Appels ---

  /// Passe un appel téléphonique (permission CALL_PHONE).
  static Future<bool> callNumber(String number) async {
    return await _channel.invokeMethod<bool>('callNumber', {'number': number}) ??
        false;
  }

  // --- SMS ---

  /// Envoie un SMS (permission SEND_SMS).
  static Future<bool> sendSms(String number, String message) async {
    return await _channel.invokeMethod<bool>(
          'sendSms',
          {'number': number, 'message': message},
        ) ??
        false;
  }

  // --- Accessibilité ---

  /// Indique si le service d'accessibilité est actif.
  static Future<bool> isAccessibilityEnabled() async {
    return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
  }

  /// Ouvre les réglages d'accessibilité (pour activer le service).
  static Future<bool> openAccessibilitySettings() async {
    return await _channel.invokeMethod<bool>('openAccessibilitySettings') ??
        false;
  }

  /// Lit tout le texte visible à l'écran courant.
  static Future<String> getVisibleText() async {
    return await _channel.invokeMethod<String>('getVisibleText') ?? '';
  }

  /// Clique sur un élément dont le texte correspond (partiellement).
  static Future<bool> clickByText(String text) async {
    return await _channel.invokeMethod<bool>('clickByText', {'text': text}) ??
        false;
  }

  /// Écrit du texte dans le champ de saisie actif.
  static Future<bool> typeText(String text) async {
    return await _channel.invokeMethod<bool>('typeText', {'text': text}) ??
        false;
  }

  /// Simule l'appui sur Retour.
  static Future<bool> pressBack() async {
    return await _channel.invokeMethod<bool>('pressBack') ?? false;
  }

  /// Simule l'appui sur Accueil.
  static Future<bool> pressHome() async {
    return await _channel.invokeMethod<bool>('pressHome') ?? false;
  }

  /// Fait défiler l'écran vers le bas / le haut.
  static Future<bool> scrollDown() async {
    return await _channel.invokeMethod<bool>('scrollDown') ?? false;
  }

  static Future<bool> scrollUp() async {
    return await _channel.invokeMethod<bool>('scrollUp') ?? false;
  }

  // --- Permissions & réglages ---

  /// Ouvre l'écran de détails d'une application (permissions).
  static Future<bool> openAppDetails(String packageName) async {
    return await _channel.invokeMethod<bool>(
          'openAppDetails',
          {'packageName': packageName},
        ) ??
        false;
  }

  /// Liste les permissions (nom -> accordée) d'une application.
  static Future<Map<dynamic, dynamic>> getInstalledPermissions(
    String packageName,
  ) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getInstalledPermissions',
      {'packageName': packageName},
    );
    return result ?? {};
  }

  // --- Système ---

  /// Niveau de batterie (0-100).
  static Future<int> getBatteryLevel() async {
    return await _channel.invokeMethod<int>('getBatteryLevel') ?? -1;
  }

  /// Ouvre une URL (modules en ligne : YouTube, web).
  static Future<bool> openUrl(String url) async {
    return await _channel.invokeMethod<bool>('openUrl', {'url': url}) ?? false;
  }

  // --- Perception assistée ---

  /// Lance la caméra en mode perception.
  /// [mode] : "ocr" (lire un texte) ou "label" (identifier des objets).
  static Future<bool> startPerception(String mode) async {
    return await _channel.invokeMethod<bool>(
          'startPerception',
          {'mode': mode},
        ) ??
        false;
  }

  /// Enregistre un écouteur pour les résultats asynchrones de la perception.
  static void setPerceptionListener(void Function(String) onResult) {
    _perceptionCallback = onResult;
    _ensureHandler();
  }

  // --- Contacts ---

  /// Résout un nom de contact en numéro de téléphone (null si introuvable).
  /// Priorité aux contacts définis, puis au carnet d'adresses.
  static Future<String?> resolveContact(String name) async {
    return await _channel.invokeMethod<String>('resolveContact', {'name': name});
  }

  /// Enregistre (ou met à jour) un contact nom → numéro (stockage local).
  static Future<String> saveContact(String name, String number) async {
    return await _channel.invokeMethod<String>(
          'saveContact',
          {'name': name, 'number': number},
        ) ??
        '';
  }

  /// Liste les contacts définis (texte lisible en français).
  static Future<String> listSavedContacts() async {
    return await _channel.invokeMethod<String>('listSavedContacts') ?? '';
  }

  /// Supprime un contact défini.
  static Future<String> deleteContact(String name) async {
    return await _channel.invokeMethod<String>('deleteContact', {'name': name}) ??
        '';
  }

  /// Retourne les numéros de tous les contacts définis (pour la fonction SOS).
  static Future<List<String>> getSavedContactNumbers() async {
    final result = await _channel.invokeMethod<List<dynamic>>(
      'getSavedContactNumbers',
    );
    return result?.map((e) => e.toString()).toList() ?? [];
  }

  // --- SMS (lecture) ---

  /// Retourne les derniers SMS reçus sous forme de liste de maps.
  static Future<List<Map<dynamic, dynamic>>> getLastSms({int count = 5}) async {
    final result = await _channel.invokeMethod<List<dynamic>>(
      'getLastSms',
      {'count': count},
    );
    return result?.cast<Map<dynamic, dynamic>>() ?? [];
  }

  // --- Musique ---

  static Future<String> playMusic() async =>
      await _channel.invokeMethod<String>('playMusic') ?? '';

  static Future<String> pauseMusic() async =>
      await _channel.invokeMethod<String>('pauseMusic') ?? '';

  static Future<String> resumeMusic() async =>
      await _channel.invokeMethod<String>('resumeMusic') ?? '';

  static Future<String> nextTrack() async =>
      await _channel.invokeMethod<String>('nextTrack') ?? '';

  static Future<String> previousTrack() async =>
      await _channel.invokeMethod<String>('previousTrack') ?? '';

  // --- Volume ---

  static Future<String> volumeUp() async =>
      await _channel.invokeMethod<String>('volumeUp') ?? '';

  static Future<String> volumeDown() async =>
      await _channel.invokeMethod<String>('volumeDown') ?? '';

  static Future<String> volumeSet(int level) async =>
      await _channel.invokeMethod<String>('volumeSet', {'level': level}) ?? '';

  // --- Localisation (SOS) ---

  /// Dernière position connue "lat,long" ou null.
  static Future<String?> getLocation() async {
    return await _channel.invokeMethod<String>('getLocation');
  }

  // --- Torche ---

  static Future<String> torchOn() async =>
      await _channel.invokeMethod<String>('torchOn') ?? '';

  static Future<String> torchOff() async =>
      await _channel.invokeMethod<String>('torchOff') ?? '';

  // --- Lancement / résolution d'application ---

  /// Lance une application par son nom de package.
  static Future<bool> openPackage(String packageName) async {
    return await _channel.invokeMethod<bool>(
          'openPackage',
          {'packageName': packageName},
        ) ??
        false;
  }

  /// Résout un nom d'application en nom de package (null si introuvable).
  static Future<String?> resolveApp(String name) async {
    return await _channel.invokeMethod<String>('resolveApp', {'name': name});
  }

  // --- Reconnaissance vocale (Vosk) ---

  /// Démarre l'écoute du microphone (reconnaissance vocale hors-ligne).
  static Future<bool> startListening() async {
    return await _channel.invokeMethod<bool>('startListening') ?? false;
  }

  /// Arrête l'écoute du microphone.
  static Future<bool> stopListening() async {
    return await _channel.invokeMethod<bool>('stopListening') ?? false;
  }

  /// Enregistre les écouteurs des résultats de la reconnaissance vocale.
  static void setSpeechListener({
    required void Function(String) onResult,
    required void Function(String) onError,
  }) {
    _speechResultCallback = onResult;
    _speechErrorCallback = onError;
    _ensureHandler();
  }

  // --- Lecture de documents ---

  /// Ouvre le sélecteur de fichier pour choisir un document à lire.
  static Future<bool> openDocumentPicker() async {
    return await _channel.invokeMethod<bool>('openDocumentPicker') ?? false;
  }

  /// Enregistre l'écouteur du texte extrait d'un document.
  static void setDocumentListener(void Function(String) onText) {
    _documentCallback = onText;
    _ensureHandler();
  }

  // --- Lecture vidéo ---

  /// Ouvre le sélecteur de vidéo pour choisir une vidéo locale à lire.
  static Future<bool> openVideoPicker() async {
    return await _channel.invokeMethod<bool>('openVideoPicker') ?? false;
  }

  // --- Réglages rapides ---

  /// Ouvre le panneau de réglage Wi-Fi.
  static Future<bool> openWifiSettings() async =>
      await _channel.invokeMethod<bool>('openWifiSettings') ?? false;

  /// Ouvre le panneau de réglage Bluetooth.
  static Future<bool> openBluetoothSettings() async =>
      await _channel.invokeMethod<bool>('openBluetoothSettings') ?? false;

  /// Ouvre le panneau de réglage du mode avion.
  static Future<bool> openAirplaneModeSettings() async =>
      await _channel.invokeMethod<bool>('openAirplaneModeSettings') ?? false;

  // ------------------------------------------------------------------
  // Gestion interne d'un UNIQUE gestionnaire de canal.
  // Un MethodChannel n'accepte qu'un seul setMethodCallHandler ; on
  // centralise donc ici la répartition entre perception et reconnaissance.
  // ------------------------------------------------------------------

  static void Function(String)? _perceptionCallback;
  static void Function(String)? _speechResultCallback;
  static void Function(String)? _speechErrorCallback;
  static void Function(String)? _documentCallback;
  static bool _handlerInstalled = false;

  static void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) {
      switch (call.method) {
        case 'onPerceptionResult':
          _perceptionCallback?.call(call.arguments as String? ?? '');
        case 'onSpeechResult':
          _speechResultCallback?.call(call.arguments as String? ?? '');
        case 'onSpeechError':
          _speechErrorCallback?.call(call.arguments as String? ?? '');
        case 'onDocumentText':
          _documentCallback?.call(call.arguments as String? ?? '');
      }
    });
  }
}
