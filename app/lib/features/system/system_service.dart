import '../../core/nlu/intent.dart';
import '../../platform/native_bridge.dart';

/// Fonction F9 — Contrôle du téléphone.
///
/// État du téléphone (batterie), lecture d'écran, volume, torche.
class SystemService {
  Future<String> handleBattery() async {
    final level = await NativeBridge.getBatteryLevel();
    if (level < 0) {
      return 'Je n\'ai pas pu lire le niveau de batterie.';
    }
    return 'Votre batterie est à $level pour cent.';
  }

  Future<String> handleReadScreen() async {
    final enabled = await NativeBridge.isAccessibilityEnabled();
    if (!enabled) {
      return 'Le service d\'accessibilité n\'est pas activé. '
          'Activez-le dans les réglages pour que je puisse lire l\'écran.';
    }
    final text = await NativeBridge.getVisibleText();
    if (text.isEmpty) {
      return 'Je ne vois rien à l\'écran.';
    }
    return text;
  }

  Future<String> handleVolumeUp() async {
    return NativeBridge.volumeUp();
  }

  Future<String> handleVolumeDown() async {
    return NativeBridge.volumeDown();
  }

  Future<String> handleVolumeSet(Intent intent) async {
    final level = int.tryParse(intent.param('level')) ?? 50;
    return NativeBridge.volumeSet(level);
  }

  Future<String> handleTorchOn() async {
    return NativeBridge.torchOn();
  }

  Future<String> handleTorchOff() async {
    return NativeBridge.torchOff();
  }

  /// Ouvre le panneau de réglage demandé et guide l'utilisateur.
  Future<String> handleOpenSetting(Intent intent) async {
    final setting = intent.param('setting');
    switch (setting) {
      case 'wifi':
        final ok = await NativeBridge.openWifiSettings();
        if (ok) {
          return 'J\'ouvre les réglages Wi-Fi. '
              'Touchez l\'interrupteur pour activer ou désactiver le Wi-Fi.';
        }
        return 'Je n\'ai pas pu ouvrir les réglages Wi-Fi.';
      case 'bluetooth':
        final ok = await NativeBridge.openBluetoothSettings();
        if (ok) {
          return 'J\'ouvre les réglages Bluetooth. '
              'Touchez l\'interrupteur pour l\'activer ou le désactiver.';
        }
        return 'Je n\'ai pas pu ouvrir les réglages Bluetooth.';
      case 'airplane':
        final ok = await NativeBridge.openAirplaneModeSettings();
        if (ok) {
          return 'J\'ouvre les réglages du mode avion. '
              'Touchez l\'interrupteur pour l\'activer ou le désactiver.';
        }
        return 'Je n\'ai pas pu ouvrir les réglages du mode avion.';
      default:
        return 'Quel réglage voulez-vous ouvrir ? Wi-Fi, Bluetooth ou mode avion.';
    }
  }
}
