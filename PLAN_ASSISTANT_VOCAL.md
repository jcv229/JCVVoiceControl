# JCV Voice Control Android — 100% local pour personne aveugle

> Objectif : un logiciel qui permet à une personne aveugle de **piloter son téléphone à la voix**, entièrement **hors-ligne** (aucun appel à une IA sur Internet), et qui couvre : appels, SMS, WhatsApp, navigation, et explication/contrôle des permissions des APK.

---

## 1. Mes apports (ce que j'apporte au projet)

### 1.1 Compréhension du besoin réel
Une personne aveugle a besoin de :
- **Entendre** ce qui est à l'écran (retour vocal continu).
- **Commander** des actions par la voix sans toucher l'écran.
- **Un système fiable et hors-ligne** : pas de dépendance réseau, pas de latence cloud, et **confidentialité totale** (les SMS/WhatsApp ne quittent jamais le téléphone).

### 1.2 Le pilier technique : AccessibilityService (indispensable)
C'est la **seule voie légitime et autorisée** pour qu'une app contrôle d'autres apps sur Android :
- Lire le contenu de n'importe quel écran (textes, boutons, listes).
- Effectuer des actions : clic, scroll, saisie de texte, retour arrière.
- Détecter les événements d'interface (fenêtre qui change, notification).

Sans ce service, **impossible** de piloter WhatsApp, la navigation, ou le lanceur. C'est le cœur du projet.

### 1.3 La réalité du "IA 100% local"
Il faut être honnête sur ce qui est possible **sans Internet** :

| Fonction | Solution locale | Faisabilité |
|---|---|---|
| Reconnaissance vocale (FR) | Vosk (~50 Mo) ou SpeechRecognizer hors-ligne de Google | ✅ Bonne |
| Synthèse vocale (FR) | TTS Android hors-ligne (voix françaises) | ✅ Excellente |
| Compréhension de commandes | Moteur de règles (regex/mots-clés) + LLM local en secours | ✅ Fiable |
| LLM embarqué (résumé, conversation) | Gemini Nano (AICore), ou llama.cpp / MLC avec modèle Q4 (Gemma 2B, Phi-3, Qwen 2.5) | ⚠️ Selon le téléphone (RAM/SoC) |
| Navigation GPS | OSM + routage local (GraphHopper) OU Google Maps + cartes hors-ligne | ✅ Selon choix |

**Recommandation clé :** pour les commandes, privilégier un **moteur de règles déterministe** (très rapide, très fiable, 0 erreur de compréhension) plutôt qu'un LLM. Le LLM local sert en **secours** (reformulation, résumé d'un long SMS, etc.).

---

## 2. Architecture proposée

```
┌─────────────────────────────────────────────────────┐
│                    COUCHE VOCALE                    │
│  Entrée : Vosk (ASR FR hors-ligne) + mot d'éveil   │
│  Sortie : TTS Android (voix française hors-ligne)  │
└──────────────────────┬──────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────┐
│               MOTEUR DE COMPRÉHENSION (NLU)         │
│  Règles déterministes (intent + paramètres)         │
│  └─ Secours : LLM local (Gemini Nano / llama.cpp)   │
└──────────────────────┬──────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────┐
│                ORCHESTRATEUR D'ACTIONS              │
│  Appels │ SMS │ WhatsApp │ Navigation │ Permissions │
└──────────────────────┬──────────────────────────────┘
                       ▼
┌─────────────────────────────────────────────────────┐
│            ACCESSIBILITY SERVICE (mains + yeux)     │
│  Lire l'écran · cliquer · scroller · saisir        │
└─────────────────────────────────────────────────────┘
```

---

## 3. Détail des 5 fonctions demandées

### 3.1 📞 Appels
- **Composants Android :** `TelecomManager` / `Intent.ACTION_CALL` (permission `CALL_PHONE`), ou `ACTION_DIAL` (aucune permission).
- **Flux vocal :** « Appelle maman » → lecture du contact → confirmation vocale → appel.
- **Hors-ligne :** ✅ totalement (lecture des contacts via `ContactsContract`).

### 3.2 💬 SMS
- **Composants :** `SmsManager` pour envoyer ; lecture via `ContentResolver` (`Telephony.Sms`).
- **Contraintes réelles à connaître :**
  - Depuis Android 4.4, seule l'app **défaut de SMS** peut écrire dans la base SMS.
  - La lecture exige la permission `READ_SMS` (et l'app doit être app SMS par défaut).
  - Android 9+ restreint l'envoi en arrière-plan.
- **Flux vocal :** « Lis mes messages » → lecture TTS des derniers SMS → « Réponds : … ».
- **Hors-ligne :** ✅.

### 3.3 🟢 WhatsApp
- **Aucune API publique.** La seule méthode = **automatisation d'écran** via l'AccessibilityService :
  1. Ouvrir WhatsApp.
  2. Lire le contenu de l'écran de chat (nœuds d'accessibilité).
  3. Écrire dans le champ de saisie, cliquer sur « Envoyer ».
- **Fonctions possibles :** lire les messages non lus, dicter/envoyer un message à un contact, lire la liste des conversations.
- **Limites :** dépend de la structure d'écran de WhatsApp (peut casser lors de mises à jour) ; nécessite que WhatsApp soit installé.
- **Hors-ligne :** ✅ (l'automatisation est locale).

### 3.4 🧭 Navigation
Deux stratégies :
- **Option A — 100 % hors-ligne (OSM) :** cartes OpenStreetMap embarquées (OSMDroid) + moteur de routage local **GraphHopper/OSRM** + guidage vocal tour-par-tour via TTS. Zéro Internet, mais cartes à télécharger (~qq centaines de Mo par pays).
- **Option B — Google Maps :** `Intent` vers Google Maps avec cartes hors-ligne déjà téléchargées + guidage par Google. Plus simple, mais dépend des services Google et des cartes téléchargées.
- **Recommandation :** commencer par l'Option B (MVP rapide), migrer vers OSM pour l'indépendance totale.

### 3.5 🔐 Permissions des APK (lecture + explication)
- **Ce qui est possible :** via `PackageManager`, lister toutes les apps et leurs permissions déclarées (`requestedPermissions`), et **expliquer à voix haute** en français ce que chaque permission signifie (« Accès aux contacts : l'app peut lire votre carnet d'adresses »).
- **Ce qui n'est PAS possible (contrainte de sécurité Android) :** une app **ne peut pas modifier** les permissions d'une autre app. C'est verrouillé par le système, volontairement.
- **Solution proposée :** l'assistant détecte une permission sensible, l'explique, puis **ouvre l'écran de réglages de l'app** (`ACTION_APPLICATION_DETAILS_SETTINGS`) et guide l'utilisateur vocalement pour la désactiver (« Touchez maintenant le bouton "Refuser" »).

---

## 4. Stack technique recommandée

| Couche | Choix recommandé | Alternative |
|---|---|---|
| Langage | **Kotlin** | — |
| UI | Jetpack Compose (simple, tactile) | XML |
| Accès autres apps | **AccessibilityService** | — |
| Reconnaissance vocale FR | **Vosk** (modèle FR ~50 Mo) | SpeechRecognizer hors-ligne |
| Synthèse vocale | `android.speech.tts` (voix FR téléchargées) | — |
| Mot d'éveil (mains libres) | Porcupine (Picovoice, sur-appareil) | Vosk keyword spotting |
| NLU (commandes) | **Moteur de règles** (Regex/grammaire FR) | — |
| LLM local (option) | Gemini Nano via AICore (Pixel 8+, Android 14+) | llama.cpp / MLC (Gemma 2B, Qwen 2.5) |
| Cartes (option offline) | OSMDroid + GraphHopper | Google Maps + cartes hors-ligne |

**Compatibilité minimale visée :** Android 8.0 (API 26) ou plus récent.

---

## 5. Feuille de route (phases)

### Phase 0 — Fondations (semaine 1-2)
- Projet Kotlin + AccessibilityService activable.
- Boucle vocale de base : ASR (Vosk FR) → TTS (« test, un, deux »).
- Lecture à voix haute du contenu de l'écran courant (TalkBack-like).

### Phase 1 — MVP utile (semaine 3-5)
- Moteur de règles FR (intentions : appeler, envoyer, lire).
- **Appels** + **SMS** complets (lecture + dictée).
- Confirmation vocale avant chaque action sensible.

### Phase 2 — WhatsApp (semaine 6-8)
- Automatisation d'écran : lire les conversations, dicter/envoyer.
- Gestion robuste des changements d'interface WhatsApp.

### Phase 3 — Navigation (semaine 9-10)
- Intégration Google Maps (cartes hors-ligne) puis option OSM.
- Guidage tour-par-tour vocal.

### Phase 4 — Permissions & confort (semaine 11-12)
- Assistant permissions (lecture + explication + guidage réglages).
- Mot d'éveil mains-libres, gestes, retours haptiques.
- Option : LLM local pour résumer les longs messages.

---

## 6. Risques & points de vigilance

1. **WhatsApp** : fragile face aux mises à jour de l'app (l'automatisation d'écran doit être maintenue).
2. **Permissions SMS** : l'app doit devenir app SMS par défaut pour tout lire/écrire — à expliquer clairement à l'utilisateur.
3. **LLM local** : qualité inférieure au cloud ; ne l'utiliser qu'en secours, jamais pour les commandes critiques.
4. **Batterie** : mot d'éveil + ASR en continu = consommation ; prévoir un mode « activé par geste/bouton » en alternative.
5. **Aucune app ne peut modifier les permissions d'une autre app** : à communiquer pour éviter un objectif irréalisable.

---

## 7. Références utiles (existants, pour inspiration)

- **TalkBack** (Google) : lecteur d'écran natif.
- **Voice Access** (Google) : contrôle d'Android par la voix — proche de ton besoin, mais à comparer avec ton exigence « 100 % local et hors des services Google ».
- **Vosk**, **Porcupine**, **GraphHopper**, **OSMDroid**, **llama.cpp / MLC** : bibliothèques open-source embarquables.

*Ton projet se différencie des solutions Google par : l'absence totale de dépendance cloud, la confidentialité, et la personnalisation totale (grammaire de commandes en français, ajout de fonctions spécifiques).*
