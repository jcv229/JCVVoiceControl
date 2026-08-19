import '../../core/nlu/intent.dart';
import '../../platform/native_bridge.dart';

/// Fonction F4 — Perception assistée (caméra + OCR + détection d'objets).
///
/// Fonction cœur du projet : transforme le téléphone en « œil artificiel »
/// pour une personne aveugle, entièrement hors-ligne (ML Kit sur-appareil).
///
/// Le flux est asynchrone :
///  1. la commande déclenche l'ouverture de la caméra (ici) ;
///  2. l'utilisateur pointe la caméra vers le texte / l'objet ;
///  3. le résultat reconnu revient via [NativeBridge.setPerceptionListener]
///     et est lu à voix haute (branchement effectué dans main.dart).
class PerceptionService {
  /// OCR : ouvrir la caméra et lire le texte pointé.
  Future<String> handleOcr() async {
    final ok = await NativeBridge.startPerception('ocr');
    if (!ok) {
      return 'Je n\'ai pas pu ouvrir la caméra. Vérifiez la permission caméra.';
    }
    return 'J\'ouvre la caméra. Pointez-la vers le texte à lire. '
        'Je vous lirai ce que je vois.';
  }

  /// Prendre une photo puis lire le texte présent dessus (réutilise le mode OCR).
  Future<String> handleTakePhoto() async {
    final ok = await NativeBridge.startPerception('ocr');
    if (!ok) {
      return 'Je n\'ai pas pu ouvrir la caméra.';
    }
    return 'J\'ouvre la caméra. Pointez-la vers le texte, puis appuyez sur lire à voix haute.';
  }

  /// Décrire une image / identifier les objets pointés.
  Future<String> handleDescribeImage() async {
    final ok = await NativeBridge.startPerception('label');
    if (!ok) {
      return 'Je n\'ai pas pu ouvrir la caméra. Vérifiez la permission caméra.';
    }
    return 'J\'ouvre la caméra. Pointez-la vers l\'objet à identifier.';
  }
}

/// Fonction F5 (partie documents) — lecture de PDF / documents.
class DocumentService {
  /// Ouvre le sélecteur de fichier pour choisir un document à lire.
  Future<String> handleReadDocument() async {
    final ok = await NativeBridge.openDocumentPicker();
    if (!ok) {
      return 'Je n\'ai pas pu ouvrir le sélecteur de fichier.';
    }
    return 'Sélectionnez le document à lire. '
        'Dès que vous l\'aurez choisi, je vous lirai son contenu.';
  }
}
