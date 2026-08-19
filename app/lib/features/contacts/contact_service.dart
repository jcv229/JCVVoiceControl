import '../../core/nlu/intent.dart';
import '../../platform/native_bridge.dart';

/// Gestion des contacts définis par l'utilisateur.
///
/// Permet d'associer un nom à un numéro, stocké LOCALEMENT. Ces contacts sont
/// utilisés en priorité par les fonctions d'appel, de SMS et d'urgence (SOS).
class ContactService {
  /// Définit (ou met à jour) un contact nom → numéro.
  Future<String> handleDefine(Intent intent) async {
    final name = intent.param('name');
    final number = intent.param('number');

    if (name.isEmpty) {
      return 'Quel nom voulez-vous donner à ce contact ? '
          'Dites : définis le contact, puis le nom et le numéro.';
    }
    if (number.isEmpty) {
      return 'Quel est le numéro de $name ? Dites : définis $name au numéro, puis le numéro.';
    }

    return NativeBridge.saveContact(name, number);
  }

  /// Liste les contacts définis.
  Future<String> handleList() async {
    return NativeBridge.listSavedContacts();
  }

  /// Supprime un contact défini.
  Future<String> handleDelete(Intent intent) async {
    final name = intent.param('name');
    if (name.isEmpty) {
      return 'Quel contact voulez-vous supprimer ?';
    }
    return NativeBridge.deleteContact(name);
  }
}
