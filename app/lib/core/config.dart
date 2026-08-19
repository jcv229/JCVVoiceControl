/// Configuration générale de l'application.
///
/// Tout le traitement (voix, compréhension, synthèse) est 100 % local.
/// Les modules marqués "en ligne" (YouTube, web) sont isolés et clairement
/// signalés à l'utilisateur.
class AppConfig {
  AppConfig._();

  /// Langue de la reconnaissance et de la synthèse vocale.
  static const String locale = 'fr-FR';

  /// Vitesse d'élocution (0.0 = lent, 1.0 = normal).
  static const double speechRate = 0.5;

  /// Nombre de caractères max d'un message avant confirmation.
  static const int maxMessagePreviewLength = 200;

  /// Active ou désactive les fonctions "en ligne" (YouTube, web).
  /// Par défaut actives, mais toujours annoncées à l'utilisateur.
  static const bool allowOnlineFeatures = true;
}
