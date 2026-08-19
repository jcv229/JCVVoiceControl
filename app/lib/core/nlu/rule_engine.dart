import 'intent.dart';

/// Moteur de compréhension déterministe (sans IA, 100 % local et fiable).
///
/// Il transforme une phrase en français en une [Intent] structurée, grâce à
/// des règles (expressions régulières + mots-clés). Il est volontairement
/// déterministe : aucune erreur d'interprétation sur les commandes critiques.
///
/// Une IA locale (Gemini Nano, etc.) pourra être branchée en SECOURS plus tard,
/// pour les cas que ce moteur ne comprend pas.
class RuleEngine {
  RuleEngine._();

  /// Analyse une phrase brute et retourne l'intention détectée.
  static Intent parse(String raw) {
    final t = normalize(raw);

    if (t.isEmpty) return Intent(IntentType.unknown, {});

    // --- Urgence (doit être détectée AVANT "appelle" et "aide") ---
    if (_match(t, r'\b(sos|urgence|appelle.a.l.aide|au.secours|aidez.moi)\b')) {
      return Intent(IntentType.sos, {});
    }

    // --- Aide / commandes ---
    if (_match(t, r'\b(aide|help|commandes?|qu.est.ce.que.tu.peux|que.sais.tu)\b')) {
      return Intent(IntentType.help, {});
    }

    // --- Définition / gestion des contacts (AVANT les appels) ---
    if (_match(t, r'\b(definis|definit|enregistre|enregistrer|ajoute)\b.{0,20}\b(contact|numéro|numero)\b') ||
        _match(t, r'\b(contact|numero)\b.{0,10}\b(de|pour)\b.{0,20}\b(avec|au|est)\b')) {
      final number = _extractNumber(t);
      final name = _extractContactName(t);
      return Intent(IntentType.defineContact, {
        'name': name,
        'number': number ?? '',
      });
    }
    if (_match(t, r'\b(supprime|supprimer|efface|effacer)\b.{0,20}\b(contact|numéro|numero)\b') ||
        _match(t, r'\b(oublie)\b.{0,20}\b(contact|numero)\b')) {
      final name = _extractContactName(t);
      return Intent(IntentType.deleteContact, {'name': name});
    }
    if (_match(t, r'\b(liste|listes|quels.sont|affiche)\b.{0,20}\b(contacts?|numeros?)\b') ||
        _match(t, r'\b(mes.contacts|contacts.definis|mes.numeros)\b')) {
      return Intent(IntentType.listContacts, {});
    }

    // --- Appels ---
    if (_match(t, r'\b(appelle|telephone.a|appel)\b')) {
      final num = _extractNumber(t);
      if (num != null) {
        return Intent(IntentType.call, {'number': num});
      }
      final contact = _extractAfter(t, r'\b(appelle|telephone.a)\b');
      return Intent(IntentType.call, {'contact': contact});
    }

    // --- WhatsApp (détecté AVANT les SMS : la commande contient "whatsapp") ---
    if (_match(t, r'\bwhatsapp\b')) {
      if (_match(t, r'\b(lis|lit|lecture|ouvre)\b') ||
          _match(t, r'\b(messages?|conversations?|non.lus?)\b')) {
        return Intent(IntentType.whatsappRead, {});
      }
      final contact = _extractContact(t);
      final message = _extractMessage(t);
      return Intent(IntentType.whatsappSend, {
        'contact': contact,
        'message': message,
      });
    }

    // --- SMS ---
    if (_match(t, r'\b(lis|lit|lecture).{0,20}\b(sms|messages?|textos?)\b') ||
        _match(t, r'\b(mes|derniers?)\s+(sms|messages?)\b')) {
      return Intent(IntentType.readSms, {});
    }
    if (_match(t, r'\b(envoie|ecris|envoyer|ecrire)\b.{0,30}\b(sms|message|texto)\b') ||
        _match(t, r'\b(sms|message|texto)\b.{0,10}\b(a|pour|vers)\b')) {
      final contact = _extractContact(t);
      final message = _extractMessage(t);
      return Intent(IntentType.sendSms, {
        'contact': contact,
        'message': message,
      });
    }

    // --- Navigation ---
    if (_match(t, r'\b(guide|guides|emmene|conduis|itineraire|navigue|va.a)\b') ||
        _match(t, r'\b(comment.aller|ou.se.trouve|direction)\b')) {
      final dest = _extractAfter(
        t,
        r'\b(guide.moi|guides?|emmene.moi|conduis.moi|itineraire.vers|va.a|direction|vers)\b',
      );
      return Intent(IntentType.navigate, {'destination': dest});
    }

    // --- Permissions ---
    if (_match(t, r'\b(permissions?|autorisations?)\b')) {
      if (_match(t, r'\b(explique|explique.moi|que.signifie|a.quoi.sert)\b')) {
        return Intent(IntentType.explainPermission, {'app': t});
      }
      final app = _extractAppName(t);
      return Intent(IntentType.listPermissions, {'app': app});
    }

    // --- Lecture d'écran ---
    if (_match(t, r'\b(lis.moi.l.ecran|lis.l.ecran|decris.l.ecran|que.vois.tu|qu.est.ce.qui.est.affich)\b')) {
      return Intent(IntentType.readScreen, {});
    }

    // --- Musique ---
    if (_match(t, r'\b(joue|lance|mets)\b.{0,10}\b(musique|chanson|morceau|playlist)\b') ||
        _match(t, r'\b(play)\b')) {
      return Intent(IntentType.playMusic, {});
    }
    if (_match(t, r'\b(pause|mets.en.pause|arrete)\b') && _match(t, r'\b(musique|chanson|lecture)\b')) {
      return Intent(IntentType.pauseMusic, {});
    }
    if (_match(t, r'\b(reprends|reprend|continue)\b.{0,10}\b(musique|chanson|lecture)\b')) {
      return Intent(IntentType.resumeMusic, {});
    }
    if (_match(t, r'\b(suivante?|suivant|passe|next)\b')) {
      return Intent(IntentType.nextTrack, {});
    }
    if (_match(t, r'\b(precedente?|precedent|previous|reviens)\b')) {
      return Intent(IntentType.previousTrack, {});
    }

    // --- Volume ---
    final volSet = _extractVolume(t);
    if (volSet != null) {
      return Intent(IntentType.volumeSet, {'level': volSet.toString()});
    }
    if (_match(t, r'\b(monte|augmente|plus.fort)\b.{0,10}\b(volume|son)\b')) {
      return Intent(IntentType.volumeUp, {});
    }
    if (_match(t, r'\b(baisse|diminue|moins.fort)\b.{0,10}\b(volume|son)\b')) {
      return Intent(IntentType.volumeDown, {});
    }

    // --- Torche ---
    if (_match(t, r'\b(allume|active)\b.{0,10}\b(lampe|torche|flash|lumiere)\b')) {
      return Intent(IntentType.torchOn, {});
    }
    if (_match(t, r'\b(eteins|desactive|coupe)\b.{0,10}\b(lampe|torche|flash|lumiere)\b')) {
      return Intent(IntentType.torchOff, {});
    }

    // --- Batterie ---
    if (_match(t, r'\b(batterie|niveau.de.batterie|combien.de.batterie)\b')) {
      return Intent(IntentType.battery, {});
    }

    // --- Réglages rapides (Wi-Fi / Bluetooth / mode avion) ---
    // Depuis Android 10, on ne peut plus les activer/désactiver soi-même :
    // on ouvre le panneau de réglage et on guide l'utilisateur.
    if (_match(t, r'\b(wifi|wi.fi|reseau.sans.fil)\b')) {
      return Intent(IntentType.openSetting, {'setting': 'wifi'});
    }
    if (_match(t, r'\b(bluetooth)\b')) {
      return Intent(IntentType.openSetting, {'setting': 'bluetooth'});
    }
    if (_match(t, r'\b(mode.avion)\b')) {
      return Intent(IntentType.openSetting, {'setting': 'airplane'});
    }

    // --- Documents / lecture ---
    if (_match(t, r'\b(lis|lit)\b.{0,20}\b(pdf|document|fichier|livre)\b')) {
      return Intent(IntentType.readDocument, {});
    }

    // --- Perception ---
    if (_match(t, r'\b(lis|lit)\b.{0,10}\b(texte|ecriture|ecrit)\b') ||
        _match(t, r'\b(ocr|reconnais.le.texte)\b') ||
        _match(t, r'\b(lis.moi)\b.{0,10}\b(ce.qui.est.ecrit|le.texte)\b')) {
      return Intent(IntentType.ocr, {});
    }
    if (_match(t, r'\b(prends|prend)\b.{0,10}\b(photo|picture)\b')) {
      return Intent(IntentType.takePhoto, {});
    }
    if (_match(t, r'\b(decris|decrit)\b') ||
        _match(t, r'\b(qu.est.ce.que.c.est|qu.est.ce.que.je.vois|que.vois.je|qu.ai.je.devant.moi|quel.objet|identifie.cet.objet)\b')) {
      return Intent(IntentType.describeImage, {});
    }

    // --- YouTube ---
    if (_match(t, r'\b(youtube)\b')) {
      return Intent(IntentType.openYoutube, {});
    }

    // --- Lecture vidéo (locale) ---
    if (_match(t, r'\b(joue|lis|lit|lance|regarde)\b.{0,10}\b(video|vidéo|film)\b') ||
        _match(t, r'\b(lecture.video|lecture.vidéo|ouvre.une.video)\b')) {
      return Intent(IntentType.playVideo, {});
    }

    // --- Email / Gmail ---
    if (_match(t, r'\b(gmail|email|mail|courriel)\b')) {
      return Intent(IntentType.readEmail, {});
    }

    return Intent(IntentType.unknown, {});
  }

  // ------------------------------------------------------------------
  // Outils internes
  // ------------------------------------------------------------------

  /// Normalise : minuscules + suppression des accents + ponctuation.
  static String normalize(String s) {
    var out = s.toLowerCase();
    const map = {
      'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
      'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o',
      'û': 'u', 'ü': 'u', 'ù': 'u', 'ú': 'u',
      'ç': 'c', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae',
    };
    map.forEach((k, v) => out = out.replaceAll(k, v));
    // Réduit les espaces multiples à un espace simple.
    return out.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _match(String text, String pattern) {
    return RegExp(pattern, caseSensitive: false).hasMatch(text);
  }

  /// Extrait un numéro de téléphone (au moins 4 chiffres) de la phrase.
  static String? _extractNumber(String text) {
    final m = RegExp(r'(\+?\d[\d\s.\-]{3,})').firstMatch(text);
    if (m == null) return null;
    return m.group(1)!.replaceAll(RegExp(r'[\s.\-]'), '');
  }

  /// Extrait le texte qui suit une expression.
  static String _extractAfter(String text, String pattern) {
    final m = RegExp('$pattern\\s*(.+)').firstMatch(text);
    if (m == null) return '';
    return (m.group(1) ?? '').trim();
  }

  /// Mots à ignorer lors de l'extraction d'un nom de contact.
  static const Set<String> _contactStopWords = {
    'avec', 'au', 'aux', 'est', 'le', 'la', 'les', 'un', 'une', 'de', 'du',
    'des', 'pour', 'mon', 'ma', 'mes', 'numero', 'numéro', 'contact',
    'definis', 'definit', 'enregistre', 'enregistrer', 'ajoute', 'ajouter',
    'supprime', 'supprimer', 'oublie', 'efface', 'effacer', 'quel', 'quelle',
  };

  /// Extrait le nom d'un contact dans une commande de définition/suppression.
  /// Ex. : "définis le contact maman avec le numéro 06..." -> "maman"
  ///       "enregistre maman au numéro 06..." -> "maman"
  static String _extractContactName(String text) {
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Repère l'indice de départ : juste après un mot-clé d'action.
    const actionKeywords = {
      'definis', 'definit', 'enregistre', 'enregistrer', 'ajoute', 'ajouter',
      'supprime', 'supprimer', 'oublie', 'efface', 'effacer',
    };
    var startIndex = -1;
    for (var i = 0; i < words.length; i++) {
      if (actionKeywords.contains(words[i])) {
        startIndex = i + 1;
        break;
      }
    }
    // Si un mot "contact" apparaît juste après l'action, on part après lui.
    if (startIndex >= 0) {
      for (var i = startIndex; i < words.length && i < startIndex + 2; i++) {
        if (words[i] == 'contact') {
          startIndex = i + 1;
          break;
        }
      }
    }

    // Récolte les mots non-réservés à partir de startIndex.
    final nameParts = <String>[];
    final scanFrom = startIndex >= 0 ? startIndex : 0;
    for (var i = scanFrom; i < words.length; i++) {
      final w = words[i];
      if (_contactStopWords.contains(w)) break;
      nameParts.add(w);
      if (nameParts.length >= 2) break; // un nom composé au maximum
    }
    return nameParts.join(' ').trim();
  }

  /// Extrait un nom de contact (heuristique simple).
  static String _extractContact(String text) {
    // Essaie de trouver "à X" ou "a X" ou "pour X" ou "vers X".
    final m = RegExp(r'\b(?:a|pour|vers|au)\s+([a-z]+(?:\s+[a-z]+)?)')
        .firstMatch(text);
    if (m != null) return m.group(1)!.trim();
    // Sinon, prend le premier mot après "message/sms/whatsapp".
    final m2 = RegExp(r'\b(?:message|sms|whatsapp|texto)\b\s+([a-z]+)')
        .firstMatch(text);
    return m2?.group(1)?.trim() ?? '';
  }

  /// Extrait le corps du message (texte après ":" ou après le contact).
  static String _extractMessage(String text) {
    final m = RegExp(r'[:]\s*(.+)').firstMatch(text);
    if (m != null) return m.group(1)!.trim();
    final m2 = RegExp(r'\b(?:dis|dit|dis.lui|dis.moi)\s*(.+)').firstMatch(text);
    if (m2 != null) return m2.group(1)!.trim();
    return '';
  }

  /// Extrait le nom d'une application (heuristique).
  static String _extractAppName(String text) {
    final m = RegExp(r'\b(?:de|pour|sur|l.application)\s+([a-z]+(?:\s+[a-z]+)?)')
        .firstMatch(text);
    return m?.group(1)?.trim() ?? '';
  }

  /// Détecte un pourcentage ou niveau de volume (ex. "à 50 %", "volume 50").
  static int? _extractVolume(String text) {
    final m = RegExp(r'(\d{1,3})\s*(?:%|pour.cent|sur.cent)').firstMatch(text);
    if (m != null) return int.tryParse(m.group(1)!);
    final m2 = RegExp(r'\bvolume\s*(\d{1,3})\b').firstMatch(text);
    if (m2 != null) return int.tryParse(m2.group(1)!);
    return null;
  }
}
