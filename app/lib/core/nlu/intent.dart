/// Représente une intention détectée par le moteur de compréhension.
library;

/// Toutes les intentions que l'assistant sait traiter.
enum IntentType {
  call,
  defineContact,
  listContacts,
  deleteContact,
  sendSms,
  readSms,
  whatsappSend,
  whatsappRead,
  navigate,
  listPermissions,
  explainPermission,
  readScreen,
  playMusic,
  pauseMusic,
  resumeMusic,
  nextTrack,
  previousTrack,
  volumeUp,
  volumeDown,
  volumeSet,
  torchOn,
  torchOff,
  battery,
  sos,
  readDocument,
  ocr,
  takePhoto,
  describeImage,
  openYoutube,
  playVideo,
  readEmail,
  openSetting,
  help,
  unknown,
}

/// Résultat de l'analyse : une intention + des paramètres (ex. contact, message).
class Intent {
  final IntentType type;

  /// Paramètres extraits de la phrase (contact, numéro, message, destination…).
  final Map<String, String> params;

  Intent(this.type, this.params);

  /// Paramètre typé avec repli.
  String param(String key, [String fallback = '']) =>
      params[key] ?? fallback;

  bool get hasParam => params.isNotEmpty;

  @override
  String toString() => 'Intent($type, $params)';
}
