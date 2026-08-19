# JCV Voice Control Android — 100 % local pour personne aveugle

Application Android permettant de **piloter le téléphone à la voix**, avec un
cerveau **100 % local** (reconnaissance, compréhension et synthèse sur l'appareil,
aucune donnée envoyée sur Internet).

> **État actuel : Phase 0 + socle de la Phase 1 (MVP).**
> Le projet est un squelette fonctionnel : toute la chaîne vocale
> (compréhension → action → synthèse) est en place et testable. Les fonctions
> métier (appels, SMS) sont branchées côté natif ; les autres (WhatsApp,
> perception, médias…) sont des points d'ancrage prêts à compléter.

---

## 📁 Structure du projet

```
app/
├── lib/
│   ├── main.dart                      # Interface (gros boutons, contraste élevé)
│   ├── core/
│   │   ├── config.dart                # Configuration (langue, vitesse…)
│   │   ├── nlu/
│   │   │   ├── intent.dart            # Types d'intention
│   │   │   └── rule_engine.dart       # Moteur de règles (français, hors-ligne)
│   │   ├── tts/tts_service.dart       # Synthèse vocale (flutter_tts)
│   │   ├── asr/asr_service.dart       # Reconnaissance vocale (interface + mock)
│   │   └── orchestrator/orchestrator.dart
│   ├── platform/native_bridge.dart    # Pont Dart ↔ Kotlin (MethodChannel)
│   └── features/                      # Une fonction par dossier
│       ├── calls/                     # F1 Appels
│       ├── sms/                       # F2 SMS
│       ├── whatsapp/                  # F3 WhatsApp
│       ├── perception/                # F4 Perception + F5 Documents
│       ├── media/                     # F5 Médias (musique)
│       ├── navigation/                # F6 Navigation
│       ├── permissions/               # F7 Permissions
│       ├── system/                    # F9 Contrôle du téléphone
│       └── emergency/                 # F10 SOS
├── android/app/src/main/
│   ├── AndroidManifest.xml            # Permissions + déclarations
│   ├── kotlin/com/assistantvocal/jcv_voice_control/
│   │   ├── MainActivity.kt            # Pont natif (appels, SMS, réglages…)
│   │   ├── AssistantAccessibilityService.kt  # Cœur : lecture d'écran + actions
│   │   ├── SmsReceiver.kt             # Réception des SMS
│   │   └── PermissionHelper.kt        # Lecture des permissions
│   └── res/xml/accessibility_service_config.xml
└── test/rule_engine_test.dart         # Tests du moteur de compréhension
```

---

## 🚀 Lancer le projet

### Prérequis
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable, ≥ 3.19)
- Android Studio (ou SDK Android) + un appareil/émulateur Android 8.0+ (API 26)

### Méthode recommandée : script d'installation automatique

Le script `setup.sh` crée un projet Flutter « propre » (ce qui génère le wrapper
Gradle et les fichiers de plateforme adaptés à **votre** version de Flutter),
puis y injecte tout le code source de l'assistant.

```bash
cd jcv_voice_control_android/app
chmod +x setup.sh
./setup.sh mon_assistant          # crée le dossier "mon_assistant"

# Compiler l'APK
cd mon_assistant
flutter build apk --debug

# Installer sur un appareil connecté
flutter install
```

### Méthode manuelle (alternative)

```bash
# 1. Créer un projet Flutter propre
flutter create --org com.jcv --project-name jcv_voice_control mon_assistant

# 2. Copier le code source dans le projet créé
cp -r lib mon_assistant/
cp -r test mon_assistant/
rm -rf mon_assistant/android/app/src/main/kotlin
cp -r android/app/src/main/kotlin mon_assistant/android/app/src/main/
cp android/app/src/main/AndroidManifest.xml mon_assistant/android/app/src/main/
mkdir -p mon_assistant/android/app/src/main/res/xml
cp android/app/src/main/res/xml/accessibility_service_config.xml mon_assistant/android/app/src/main/res/xml/
cp android/app/src/main/res/values/strings.xml mon_assistant/android/app/src/main/res/values/

# 3. minSdk 26 + dépendances
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 26/' mon_assistant/android/app/build.gradle
cd mon_assistant
flutter pub add flutter_tts permission_handler cupertino_icons

# 4. Récupérer + tester + compiler
flutter pub get
flutter test
flutter build apk --debug
```

> **Pourquoi ce détour par `flutter create` ?** Le wrapper Gradle
> (`gradle-wrapper.jar`) et `.metadata` sont des fichiers binaires/générés qui
> dépendent de votre installation Flutter. Ils ne peuvent pas être fournis tels
> quels ; `flutter create` les génère automatiquement de façon fiable.

---

## ⚙️ Activation indispensable après installation

1. **Service d'accessibilité** : Réglages → Accessibilité → « JCV Voice Control » → Activer.
   *Sans lui, l'application ne peut pas lire l'écran ni piloter WhatsApp.*
2. **Application SMS par défaut** (pour lire/envoyer les SMS) : Réglages → Applications → Application SMS par défaut.
3. **Voix française hors-ligne** : Réglages → Langue et saisie → Synthèse vocale → Installer la voix française.
4. **Cartes hors-ligne** (pour la navigation sans connexion) : Google Maps → Profil → Cartes hors connexion.

---

## 🎤 Tester la chaîne vocale

L'écran principal propose :
- un **gros bouton micro** (actuellement en mode démonstration) ;
- un **champ de saisie** pour taper une commande et tester la chaîne complète.

Exemples de commandes reconnues :

| Commande | Fonction |
|---|---|
| « appelle le 06 12 34 56 78 » | Appel |
| « lis mes messages » | Lecture SMS |
| « envoie un SMS à Jean : je serai en retard » | Envoi SMS |
| « lis mes messages WhatsApp » | Lecture WhatsApp |
| « guide-moi vers la pharmacie » | Navigation |
| « quelle est ma batterie ? » | État du téléphone |
| « allume la lampe torche » | Torche |
| « appelle à l'aide » | SOS |
| « lis-moi l'écran » | Lecture d'écran |
| « aide » | Liste des commandes |

---

## 🗺️ Feuille de route (ce qui reste à faire)

| Étape | Contenu |
|---|---|
| ✅ Phase 0 | Squelette + pont natif + chaîne vocale + moteur de règles |
| ✅ Perception assistée | Caméra + OCR (ML Kit) + détection d'objets (hors-ligne) |
| ✅ Contacts | Résolution nom → numéro (ContentResolver) |
| ✅ SMS | Lecture de la base SMS (app SMS par défaut) |
| ✅ Médias | Musique locale (MediaPlayer) + volume (AudioManager) |
| ✅ Sécurité | SOS avec position GPS (LocationManager) |
| ✅ Torche | Allumer/éteindre la lampe (CameraManager) |
| ✅ Permissions | Résolution app → package + explication française |
| ✅ WhatsApp | Automatisation d'écran complète (saisie + envoi) |
| ✅ Vosk | Reconnaissance vocale française hors-ligne (~40 Mo) |
| ✅ Documents | Lecture PDF + texte (rendu + OCR, hors-ligne) |
| ✅ Réglages rapides | Wi-Fi / Bluetooth / mode avion (ouverture + guidage) |
| ✅ Contacts définis | Associer un nom → numéro, appeler/SMS en priorité, base du SOS |
| ✅ Lecture vidéo | Sélecteur vidéo + lecteur système (hors-ligne) |
| ✅ Écran réglages | Activation accessibilité + gestion visuelle des contacts |

---

## 👁️ Perception assistée (implémentée)

La fonction « perception » permet à une personne aveugle de **lire du texte** et
d'**identifier des objets** avec la caméra, **entièrement hors-ligne** (ML Kit
sur-appareil, aucun envoi sur Internet).

| Commande vocale | Fonction | Mode caméra |
|---|---|---|
| « lis le texte » / « lis-moi ce qui est écrit » | OCR (lire un texte) | `ocr` |
| « prends une photo » | Capture + lecture du texte | `ocr` |
| « décris ce que je vois » / « qu'est-ce que c'est ? » | Détection d'objets | `label` |

**Fonctionnement** : la commande ouvre la caméra (CameraX) ; l'utilisateur pointe
le téléphone vers le texte ou l'objet ; l'analyse est continue ; le résultat est
**lu à voix haute automatiquement** dès qu'il est stable (ou sur appui du gros
bouton « LIRE À VOIX HAUTE »).

**Composants natifs ajoutés** (`android/.../jcv_voice_control/`) :
- `PerceptionEngine.kt` — OCR + étiquetage d'images (ML Kit), libellés français.
- `CameraActivity.kt` — aperçu caméra + analyse continue + retour du résultat.
- `PerceptionBridge.kt` — renvoi du résultat vers Flutter.

**Remarques** :
- L'OCR (reconnaissance de texte latin/français) est **intégré à l'APK** et
  fonctionne sans aucune connexion.
- La détection d'objets (image labeling) utilise le modèle de base ML Kit ;
  selon l'appareil, un téléchargement unique peut être nécessaire à la première
  utilisation (via Google Play Services).

---

## 🎙️ Reconnaissance vocale (Vosk, hors-ligne)

La reconnaissance vocale est assurée par **Vosk** (modèle français ~40 Mo),
entièrement **sur l'appareil**. La phrase reconnue est envoyée au moteur de
compréhension, qui déclenche l'action, puis la synthèse vocale répond.

**⚠️ Installation du modèle (obligatoire avant compilation)** :
le modèle n'est pas inclus dans ce dépôt (taille ~40 Mo). Vous devez :

1. Télécharger `vosk-model-small-fr-0.22.zip` depuis
   https://alphacephei.com/vosk/models
2. Le décompresser.
3. Copier son **contenu** dans `android/app/src/main/assets/model-fr/`
   (voir `android/app/src/main/assets/model-fr/README.md` pour le détail).

Au premier lancement, l'application copie le modèle vers le stockage interne
(`StorageService.unpack`) et la reconnaissance devient disponible hors-ligne.

**Composants ajoutés** :
- `VoskSpeechRecognizer.kt` — écoute micro + écoute continue (relance auto).
- Permission `RECORD_AUDIO` (demandée à l'utilisateur au premier appui sur le micro).
- Dépendance `com.alphacephei:vosk-android:0.3.47`.

**Fonctionnement** : appui sur le gros bouton micro → demande de permission →
écoute continue (chaque phrase est traitée, puis l'écoute reprend) → réappui
pour arrêter. Le champ de saisie reste disponible pour tester sans micro.

---

## 📄 Lecture de documents (PDF + texte)

La commande « lis ce document » ou « lis ce PDF » ouvre le sélecteur de fichier,
puis **lit le contenu à voix haute**, entièrement hors-ligne :

- **Fichiers texte** (`.txt`, `.md`) : lecture directe.
- **PDF** : rendu page par page (`PdfRenderer`) puis **OCR** via ML Kit.
  Cette approche fonctionne aussi pour les **PDF scannés** (courriers, notices).

**Composants ajoutés** :
- `DocumentReader.kt` — extraction du texte (texte direct / PDF via OCR).
- `MainActivity` — sélecteur `ACTION_OPEN_DOCUMENT` + lecture du résultat.

**Remarque** : les formats `.docx` (Word) ne sont pas encore pris en charge
directement ; il faut d'abord les convertir en PDF ou en texte.

---

## ⚙️ Réglages rapides (Wi-Fi / Bluetooth / mode avion)

Depuis Android 10, une application **ne peut plus** activer/désactiver
elle-même le Wi-Fi, le Bluetooth ou le mode avion (API restreintes par sécurité).
L'assistant adopte donc l'approche honnête : il **ouvre le panneau de réglage**
concerné et **guide vocalement** l'utilisateur (« Touchez l'interrupteur »).

| Commande | Action |
|---|---|
| « active le wifi » / « désactive le wifi » | Ouvre les réglages Wi-Fi + guidage |
| « active le bluetooth » | Ouvre les réglages Bluetooth + guidage |
| « active le mode avion » | Ouvre les réglages mode avion + guidage |

---

## 👥 Contacts définis (nom → numéro)

Vous pouvez **définir vos propres contacts** directement dans l'application, en
associant un nom à un numéro. Ces contacts sont stockés **localement** (aucune
donnée envoyée) et utilisés **en priorité** pour les appels et les SMS, et
servent de base à la fonction **SOS**.

| Commande | Action |
|---|---|
| « définis le contact maman avec le numéro 06 12 34 56 78 » | Enregistre le contact |
| « enregistre maman au numéro 06 12 34 56 78 » | Variante d'enregistrement |
| « liste mes contacts » | Liste les contacts définis |
| « supprime le contact maman » | Supprime un contact |
| « appelle maman » | Appel (priorité aux contacts définis, sinon carnet d'adresses) |

**Résolution en deux temps** : l'assistant cherche d'abord dans les contacts
définis, puis dans le carnet d'adresses du téléphone si le nom n'est pas défini.

---

## 🎬 Lecture vidéo (locale)

| Commande | Action |
|---|---|
| « joue une vidéo » / « lis la vidéo » / « regarde le film » | Ouvre le sélecteur de vidéo, puis lance le lecteur système |

**Remarque** : la lecture est **hors-ligne** (vidéos stockées sur l'appareil).
Le contrôle de la lecture (pause, avance) est géré par le lecteur système.
La commande « ouvre youtube » reste distincte (fonction en ligne).

---

## ⚙️ Écran de réglages

Un bouton ⚙️ dans la barre supérieure ouvre l'écran de réglages, qui permet de :
- **activer le service d'accessibilité** (avec indicateur d'état) ;
- **définir un contact** nom → numéro (complément visuel à la commande vocale) ;
- **consulter la liste** des contacts définis.

Cet écran est accessible (gros champs, retours vocaux) et complète les commandes
vocales pour les personnes accompagnées ou malvoyantes.

---

## 🔒 Confidentialité

Tout le traitement est **local** : aucune donnée personnelle (SMS, contacts,
conversations) ne quitte l'appareil. Seuls les modules explicitement « en ligne »
(YouTube, web) utilisent Internet, et l'utilisateur en est toujours informé.
