import '../../core/nlu/intent.dart';
import '../../platform/native_bridge.dart';

/// Fonction F7 — Permissions des applications.
///
/// L'assistant LIT et EXPLIQUE les permissions, puis GUIDE l'utilisateur vers
/// l'écran de réglages. Il ne peut PAS modifier les permissions d'une autre
/// application (limite de sécurité d'Android).
class PermissionsService {
  /// Traduit les permissions sensibles en explication simple en français.
  static const Map<String, String> _explanations = {
    'android.permission.READ_CONTACTS': 'accès à vos contacts',
    'android.permission.READ_SMS': 'lecture de vos SMS',
    'android.permission.SEND_SMS': 'envoi de SMS',
    'android.permission.RECEIVE_SMS': 'réception de vos SMS',
    'android.permission.CALL_PHONE': 'passer des appels',
    'android.permission.CAMERA': 'utilisation de la caméra',
    'android.permission.RECORD_AUDIO': 'enregistrement du microphone',
    'android.permission.ACCESS_FINE_LOCATION': 'accès à votre position exacte',
    'android.permission.ACCESS_COARSE_LOCATION': 'accès à votre position approximative',
    'android.permission.READ_EXTERNAL_STORAGE': 'accès à vos fichiers',
    'android.permission.READ_MEDIA_IMAGES': 'accès à vos photos',
    'android.permission.READ_MEDIA_VIDEO': 'accès à vos vidéos',
    'android.permission.READ_MEDIA_AUDIO': 'accès à vos fichiers audio',
    'android.permission.READ_PHONE_STATE': 'accès à l\'état du téléphone',
    'android.permission.INTERNET': 'accès à Internet',
    'android.permission.READ_CALENDAR': 'lecture de votre agenda',
    'android.permission.WRITE_CALENDAR': 'modification de votre agenda',
    'android.permission.BLUETOOTH': 'utilisation du Bluetooth',
  };

  /// Liste les permissions d'une application et les explique.
  Future<String> handleList(Intent intent) async {
    final appName = intent.param('app');
    if (appName.isEmpty) {
      return 'De quelle application voulez-vous connaître les permissions ?';
    }

    final package = await NativeBridge.resolveApp(appName);
    if (package == null) {
      return 'Je n\'ai pas trouvé l\'application $appName.';
    }

    final permissions = await NativeBridge.getInstalledPermissions(package);
    if (permissions.isEmpty) {
      return '$appName ne déclare aucune permission particulière.';
    }

    final buffer = StringBuffer();
    buffer.write('Voici les permissions de $appName. ');
    for (final entry in permissions.entries) {
      final permission = entry.key.toString();
      final explanation = _explanations[permission] ?? permission;
      buffer.write('$explanation. ');
    }
    return buffer.toString();
  }

  /// Explique une permission précise.
  Future<String> handleExplain(Intent intent) async {
    final appName = intent.param('app');
    // Cherche un mot de permission connu dans la phrase.
    final text = appName.toLowerCase();
    for (final entry in _explanations.entries) {
      final key = entry.key.toLowerCase();
      final keywords = key.split('.').last;
      if (text.contains(keywords) ||
          text.contains('caméra') && key.contains('CAMERA') ||
          text.contains('micro') && key.contains('AUDIO') ||
          text.contains('position') && key.contains('LOCATION') ||
          text.contains('contact') && key.contains('CONTACTS')) {
        return 'La permission ${keywords} signifie : ${entry.value}.';
      }
    }
    return 'Je peux expliquer chaque permission : accès aux contacts, caméra, microphone, position, fichiers. '
        'Dites par exemple : explique la permission caméra.';
  }
}
