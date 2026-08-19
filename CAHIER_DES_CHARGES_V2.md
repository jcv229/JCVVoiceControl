# CAHIER DES CHARGES CONSOLIDÉ — JCV Voice Control Android
### (Version unique et complète)

**Version :** 2.0 — 19/08/2026
**Statut :** Version consolidée (fusion du plan technique + cahier des charges + extension des fonctions)

---

# PARTIE 1 — VISION & OBJECTIFS

## 1.1 Contexte
Une personne aveugle ou malvoyante souhaite utiliser son smartphone Android de façon autonome. Les lecteurs d'écran existants (TalkBack) permettent d'entendre l'écran mais ne proposent pas de **commande vocale conversationnelle** réalisant des tâches complètes.

## 1.2 Objectif
Développer une application qui permet de **piloter le téléphone à la voix**, avec un **cerveau 100 % local** (aucune IA distante, aucune donnée envoyée sur Internet), couvrant les appels, SMS, WhatsApp, la navigation, l'aide aux permissions, **la perception assistée (caméra + OCR)**, les médias, et bien plus.

## 1.3 Principes directeurs
1. **Cerveau local** : reconnaissance vocale, compréhension, synthèse, lecture de fichiers → toujours sur l'appareil.
2. **Classification du contenu** : chaque fonction est étiquetée 🟢 hors-ligne, 🟡 mixte, ou 🔴 en ligne (voir Partie 3).
3. **Confidentialité** : aucune donnée personnelle ne quitte l'appareil.
4. **Confirmation vocale** avant toute action irréversible.

## 1.4 Objectifs mesurables
- Commande vocale comprise et exécutée en **< 3 secondes**.
- 100 % du traitement (voix, compréhension, lecture) **sur l'appareil**.
- Une personne aveugle réalise un appel, lit un SMS, lit un document et identifie un billet de banque **sans assistance**.

---

# PARTIE 2 — ARCHITECTURE TECHNIQUE

## 2.1 Choix techniques validés

| Couche | Choix | Justification |
|---|---|---|
| Interface utilisateur | **Flutter** | Développement rapide, rendu homogène |
| Service d'accessibilité | **Kotlin natif** | *Obligatoire* : Flutter ne peut pas lire/contrôler les autres apps |
| Communication | Platform Channels / MethodChannels | Pont Flutter ↔ natif |
| Reconnaissance vocale (FR) | **Vosk** (modèle FR ~50 Mo) | Entièrement local |
| Synthèse vocale | `android.speech.tts` (voix FR) | Entièrement local |
| Mot d'éveil | **Porcupine** (Picovoice) | Sur-appareil |
| Compréhension (NLU) | **Moteur de règles déterministe** | Fiable, rapide, 0 erreur critique |
| IA locale (secours) | Gemini Nano (AICore) / llama.cpp / MLC | Résumé de longs textes, reformulation |
| OCR / vision | **ML Kit sur-appareil**, Tesseract, MediaPipe | Perception assistée locale |
| Navigation | **Google Maps + cartes hors-ligne** | Démarrage rapide (migration OSM possible) |
| Lecture PDF/docs | Extraction texte locale + OCR | Tout local |

**Compatibilité :** Android 8.0 (API 26) minimum, cible Android 14+.

## 2.2 Schéma d'architecture

```
[Flutter — UI & orchestration]
        │ MethodChannels
[Kotlin — AccessibilityService + ASR/TTS + NLU + Actions]
        │
[Système Android : apps tierces (WhatsApp, Maps, Téléphone, SMS, Gmail, YouTube)]
```

## 2.3 Modules fonctionnels

1. **Vocale** — ASR (Vosk) + TTS + mot d'éveil.
2. **Compréhension (NLU)** — moteur de règles + IA locale en secours.
3. **Orchestrateur d'actions** — aiguille chaque commande vers le bon module.
4. **Perception** — OCR + vision (caméra, écran, images).
5. **Médias** — lecteur audio local + contrôle.
6. **Fichiers** — explorateur de fichiers/gallerie avec lecture vocale.
7. **Connecté** — YouTube, Gmail, web (isolé, clairement marqué « en ligne »).
8. **Sécurité** — SOS, position d'urgence.

---

# PARTIE 3 — CLASSIFICATION DES FONCTIONS (règle validée)

| Étiquette | Signification |
|---|---|
| 🟢 **Hors-ligne** | Aucun Internet nécessaire (traitement ET contenu). |
| 🟡 **Mixte** | Traitement local, contenu partiellement en ligne. |
| 🔴 **En ligne** | Contenu exige Internet ; le traitement reste local. |

> **Principe conservé (validé) :** le cerveau est 100 % local. Seul le *contenu* de certaines fonctions (vidéos YouTube, pages web, envoi de mail) nécessite Internet. L'utilisateur est toujours informé de l'étiquette de la fonction qu'il utilise.

---

# PARTIE 4 — SPÉCIFICATIONS FONCTIONNELLES

## 4.1 Fonctions cœur (P0 — priorité absolue)

### F1 — Appels 📞 🟢
- « Appelle maman », « Appelle le 06 12 34 56 78 ».
- Confirmation vocale avant l'appel ; annonce de l'état ; raccrocher à la voix.
- `TelecomManager` / `ACTION_CALL` (permission `CALL_PHONE`).

### F2 — SMS 💬 🟢
- Lire les derniers SMS ; dicter/envoyer ; annoncer les SMS entrants.
- `SmsManager` + `ContentResolver` ; l'app doit être **app SMS par défaut** (Android 4.4+).

### F3 — WhatsApp 🟢 🟢
- Lire les conversations, dicter/envoyer, annoncer les messages entrants.
- **Automatisation d'écran** via l'AccessibilityService (aucune API publique).
- Limite : structure d'écran dépendante des mises à jour WhatsApp.

### F4 — Perception assistée 🔍 🟢 (FONCTION CŒUR — validée prioritaire)
- **OCR caméra temps réel** : pointer vers un texte → lu à voix haute.
- **OCR photo** : « Prends une photo et lis ce qui est écrit ».
- **OCR écran** : capturer l'écran courant et lire son texte.
- **Reconnaissance de billets de banque** : identifier la valeur.
- **Reconnaissance d'objets** : « Qu'est-ce que j'ai devant moi ? ».
- **Description d'images** : décrire une photo de la galerie.
- Tout local (ML Kit, Tesseract, MediaPipe, Gemini Nano si compatible).

### F5 — Lecture de documents & médias 📄 🟢
- **PDF / documents (Word, texte)** : lecture à voix haute ; OCR si scanné.
- **Musique locale** : lecture, pause, suivant, volume, par artiste/album.
- **Images** : description vocale.
- `MediaPlayer`/`MediaSession` + extraction texte + OCR.

### F6 — Navigation 🧭 🟢 (Google Maps + cartes hors-ligne)
- « Guide-moi vers la pharmacie », « Emmène-moi à la maison ».
- Guidage vocal tour-par-tour délégué à Google Maps.

## 4.2 Fonctions prioritaires (P1)

### F7 — Permissions des applications 🔐 🟢
- Lister les apps et leurs permissions ; **expliquer** chaque permission en français.
- **Guider** vers l'écran de réglages (l'assistant ne peut PAS modifier les permissions d'une autre app — limite système).

### F8 — Organisation personnelle 📅 🟢
- Agenda (lire/créer des rendez-vous), alarmes, minuteurs, notes dictées, rappels de médicaments, contacts.

### F9 — Contrôle du téléphone ⚙️ 🟢/🟡
- Volume, luminosité, lampe torche (🟢) ; Wi-Fi/Bluetooth/mode avion (🟡).
- « Quelle est ma batterie ? », lecture des notifications.

### F10 — Sécurité & urgence 🚨 🟢
- Commande SOS : appel + SMS + position GPS à des contacts de confiance.
- Partage de position d'urgence.

## 4.3 Fonctions secondaires (P2)

### F11 — Gmail ✉️ 🟡
- Lire les e-mails (déjà synchronisés = hors-ligne), dicter/envoyer (en ligne).

### F12 — YouTube ▶️ 🔴
- Ouvrir, rechercher, lancer, contrôler la lecture (Intent + accessibility).

### F13 — Navigation web 🌐 🔴
- Ouvrir un site, **mode lecture** (extraction du texte seul) pour un confort maximal.

### F14 — Traduction 🈯 🟢
- Traduction hors-ligne (ML Kit sur-appareil) FR↔EN…

### F15 — Lecture de livres 📚 🟢
- ePub/txt, reprise à l'endroit où on s'était arrêté.

---

# PARTIE 5 — MODÈLE VOCAL (UX conversationnelle)

- **Toujours annoncer** : ce qui a été compris, ce qui va être fait, le résultat.
- **Confirmation obligatoire** avant appel/envoi.
- **Relecture** de tout message avant envoi.
- **Gestion d'erreur** : reformuler et proposer des alternatives (« Vouliez-vous dire… ? »).
- **Annonce de l'étiquette** 🟢/🟡/🔴 quand on entre dans une fonction en ligne.
- Ton naturel, calme, phrases courtes.

---

# PARTIE 6 — PERMISSIONS REQUISES

`CALL_PHONE`, `READ_SMS`/`SEND_SMS`, `READ_CONTACTS`, `CAMERA`, `READ_MEDIA_IMAGES/VIDEO/AUDIO`, `READ_EXTERNAL_STORAGE`, `READ_CALENDAR`/`WRITE_CALENDAR`, `SET_ALARM`, `ACCESS_FINE_LOCATION`, `INTERNET` (modules 🔴/🟡 uniquement), `ACCESSIBILITY_SERVICE`.

---

# PARTIE 7 — SÉCURITÉ & CONFIDENTIALITÉ

- Traitement 100 % local pour les fonctions 🟢.
- Les modules 🔴 ne transmettent que le strict nécessaire à la requête utilisateur.
- Permissions réduites au minimum, expliquées à l'utilisateur.
- Journalisation anonymisée (aucun contenu personnel dans les logs).
- Seuls téléchargements autorisés : cartes hors-ligne, voix TTS, modèles (OCR/vocaux).

---

# PARTIE 8 — PLAN DE TESTS

- **Unitaires** : moteur de compréhension (jeu de commandes françaises + reformulations).
- **Intégration** : chaque fonction (F1→F15).
- **Hors-ligne** : mode avion, vérifier que tout le 🟢 fonctionne.
- **Utilisateurs aveugles** : ≥ 5 utilisateurs, scénarios de bout en bout, taux de réussite + temps.
- **Robustesse WhatsApp** : à chaque mise à jour majeure.

---

# PARTIE 9 — JALONS & LIVRABLES

| Phase | Contenu | Durée |
|---|---|---|
| 0 — Fondations | Projet Flutter + AccessibilityService Kotlin, boucle ASR→TTS, lecture d'écran | 2 sem. |
| 1 — MVP | Moteur de règles, appels + SMS | 3 sem. |
| 2 — WhatsApp | Automatisation d'écran | 3 sem. |
| 3 — Perception | OCR caméra/photo/écran, billets, objets | 3 sem. |
| 4 — Docs & médias | PDF, musique, images | 2 sem. |
| 5 — Navigation | Google Maps + cartes hors-ligne | 2 sem. |
| 6 — Confiance | Permissions, agenda, SOS, mot d'éveil | 2 sem. |
| 7 — Connecté | Gmail, YouTube, web (P2) | 2 sem. |
| **Total** | | **≈ 19 semaines** |

**Livrables :** APK installable · documentation d'installation/activation · guide utilisateur audio · rapports de tests.

---

# PARTIE 10 — RISQUES

1. **WhatsApp** : cassure possible à chaque mise à jour (maintenance).
2. **SMS par défaut** : contrainte à expliquer clairement.
3. **Permissions d'autrui** : modification impossible → « expliquer + guider ».
4. **IA locale** : qualité moindre que le cloud → secours uniquement.
5. **Batterie** : mot d'éveil + ASR continus → prévoir mode alternatif (geste/bouton).
6. **Perception** : précision de l'OCR dépend de l'éclairage/angle ; modèles de vision limités sur appareils modestes.
7. **Fonctions 🔴** : dépendance au réseau pour le contenu (pas pour le traitement).

---

# ANNEXE — Références open-source
TalkBack (Google) · Voice Access (Google) · Vosk · Porcupine · ML Kit · Tesseract · MediaPipe · Gemini Nano (AICore) · llama.cpp / MLC · GraphHopper · OSMDroid.
