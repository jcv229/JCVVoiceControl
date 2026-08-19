import 'package:flutter_test/flutter_test.dart';
import 'package:jcv_voice_control/core/nlu/intent.dart';
import 'package:jcv_voice_control/core/nlu/rule_engine.dart';

void main() {
  group('Moteur de compréhension — appels', () {
    test('détecte un appel avec numéro', () {
      final intent = RuleEngine.parse('Appelle le 06 12 34 56 78');
      expect(intent.type, IntentType.call);
      expect(intent.param('number'), '0612345678');
    });

    test('détecte un appel avec contact', () {
      final intent = RuleEngine.parse('appelle maman');
      expect(intent.type, IntentType.call);
      expect(intent.param('contact'), 'maman');
    });
  });

  group('Moteur de compréhension — SMS', () {
    test('détecte la lecture de SMS', () {
      final intent = RuleEngine.parse('lis mes messages');
      expect(intent.type, IntentType.readSms);
    });

    test('détecte l\'envoi de SMS', () {
      final intent = RuleEngine.parse('envoie un SMS à Jean : je serai en retard');
      expect(intent.type, IntentType.sendSms);
      expect(intent.param('contact'), 'jean');
      expect(intent.param('message'), 'je serai en retard');
    });
  });

  group('Moteur de compréhension — WhatsApp', () {
    test('détecte la lecture WhatsApp', () {
      final intent = RuleEngine.parse('lis mes messages WhatsApp');
      expect(intent.type, IntentType.whatsappRead);
    });

    test('détecte l\'envoi WhatsApp', () {
      final intent = RuleEngine.parse('envoie à Pierre sur WhatsApp : je rentre');
      expect(intent.type, IntentType.whatsappSend);
    });
  });

  group('Moteur de compréhension — divers', () {
    test('navigation', () {
      final intent = RuleEngine.parse('guide-moi vers la pharmacie');
      expect(intent.type, IntentType.navigate);
    });

    test('batterie', () {
      final intent = RuleEngine.parse('quelle est ma batterie');
      expect(intent.type, IntentType.battery);
    });

    test('urgence SOS', () {
      final intent = RuleEngine.parse('appelle à l\'aide');
      expect(intent.type, IntentType.sos);
    });

    test('lecture d\'écran', () {
      final intent = RuleEngine.parse('lis-moi l\'écran');
      expect(intent.type, IntentType.readScreen);
    });

    test('torche', () {
      final intent = RuleEngine.parse('allume la lampe torche');
      expect(intent.type, IntentType.torchOn);
    });

    test('aide', () {
      final intent = RuleEngine.parse('aide');
      expect(intent.type, IntentType.help);
    });

    test('volume en pourcentage', () {
      final intent = RuleEngine.parse('mets le volume à 50 %');
      expect(intent.type, IntentType.volumeSet);
      expect(intent.param('level'), '50');
    });

    test('incompréhension', () {
      final intent = RuleEngine.parse('xylophone quantique');
      expect(intent.type, IntentType.unknown);
    });

    test('définition d\'un contact', () {
      final intent = RuleEngine.parse('définis le contact maman avec le numéro 06 12 34 56 78');
      expect(intent.type, IntentType.defineContact);
      expect(intent.param('name'), 'maman');
      expect(intent.param('number'), '0612345678');
    });

    test('définition d\'un contact (variante enregistre)', () {
      final intent = RuleEngine.parse('enregistre maman au numéro 06 12 34 56 78');
      expect(intent.type, IntentType.defineContact);
      expect(intent.param('name'), 'maman');
    });

    test('liste des contacts', () {
      final intent = RuleEngine.parse('liste mes contacts');
      expect(intent.type, IntentType.listContacts);
    });

    test('suppression d\'un contact', () {
      final intent = RuleEngine.parse('supprime le contact maman');
      expect(intent.type, IntentType.deleteContact);
      expect(intent.param('name'), 'maman');
    });

    test('lecture vidéo', () {
      final intent = RuleEngine.parse('joue une vidéo');
      expect(intent.type, IntentType.playVideo);
    });

    test('lecture vidéo (variante)', () {
      final intent = RuleEngine.parse('lis la vidéo');
      expect(intent.type, IntentType.playVideo);
    });

    test('YouTube reste distinct de la vidéo locale', () {
      final intent = RuleEngine.parse('ouvre youtube');
      expect(intent.type, IntentType.openYoutube);
    });

    test('OCR : lire le texte', () {
      final intent = RuleEngine.parse('lis-moi ce qui est écrit');
      expect(intent.type, IntentType.ocr);
    });

    test('prise de photo', () {
      final intent = RuleEngine.parse('prends une photo');
      expect(intent.type, IntentType.takePhoto);
    });

    test('description d\'image / objet', () {
      final intent = RuleEngine.parse('décris ce que je vois');
      expect(intent.type, IntentType.describeImage);
    });
  });

  group('Normalisation', () {
    test('supprime les accents', () {
      expect(RuleEngine.normalize('ÀÉÎÔÙ Ç'), 'aeiou c');
    });
  });
}
