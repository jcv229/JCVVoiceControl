# CAHIER DES CHARGES — JCV Voice Control Android 100% local pour personne aveugle

**Version :** 1.0 — 19/08/2026
**Statut :** À valider

---

## 1. Contexte et objectifs

### 1.1 Contexte
Une personne aveugle ou malvoyante souhaite utiliser son smartphone Android de façon autonome. Les lecteurs d'écran existants (TalkBack) permettent d'entendre l'écran, mais ne proposent pas une **commande vocale conversationnelle** permettant de réaliser des tâches complètes (« Appelle maman », « Envoie un message WhatsApp à Pierre », « Guide-moi vers la pharmacie »).

### 1.2 Objectif
Développer une application Android qui permet de **piloter le téléphone à la voix**, **entièrement hors-ligne** (aucun traitement par une IA distante, aucune donnée envoyée sur Internet), couvrant cinq domaines : **appels, SMS, WhatsApp, navigation, et assistance aux permissions des applications**.

### 1.3 Objectifs mesurables
- Une commande vocale simple est comprise et exécutée en **moins de 3 secondes**.
- 100 % des traitements (reconnaissance vocale, compréhension, synthèse) s'exécutent **sur l'appareil**.
- Une personne aveugle réalise un appel, lit un SMS et envoie un message WhatsApp **sans assistance extérieure**.

---

## 2. Public cible et cas d'usage

- **Utilisateur principal :** personne aveugle ou malvoyante, francophone, non technicienne.
- **Interactions :** exclusivement vocales (entrée et sortie), avec retour haptique optionnel.
- **Environnement :** bruit ambiant modéré (domicile, rue), usage à une ou deux mains, téléphone en poche ou posé.

---

## 3. Périmètre fonctionnel

### 3.1 Fonctions principales (priorité 1)

**F1 — Appels**
- Passer un appel vers un contact ou un numéro dicté.
- Confirmation vocale avant l'appel ; annonce de l'état (appel en cours, refusé).
- Raccrocher par commande vocale.

**F2 — SMS**
- Lire à voix haute les derniers SMS reçus (expéditeur + contenu).
- Dicter et envoyer un SMS à un contact.
- Annoncer les SMS entrants (avec l'expéditeur).

**F3 — WhatsApp**
- Lire les conversations (liste des discussions, messages non lus).
- Dicter et envoyer un message à un contact.
- Annoncer les messages entrants.

**F4 — Navigation**
- Lancer un guidage piéton/voiture vers un lieu dicté ou un favori.
- Guidage vocal tour-par-tour via Google Maps (cartes hors-ligne).

**F5 — Permissions des applications**
- Lister les applications installées et leurs permissions.
- Expliquer en français simple chaque permission sensible.
- Guider vocalement l'utilisateur vers l'écran de réglages pour modifier une permission.

### 3.2 Fonctions transverses (priorité 2)
- **Mot d'éveil** (« Dis assistant ») pour un usage mains libres.
- **Lecture d'écran générique** : décrire le contenu de l'écran courant à la demande.
- **Résumé vocal** d'un long message (option, via IA locale).
- **Aide vocale** : liste des commandes disponibles.

---

## 4. Exigences non fonctionnelles

| Exigence | Description |
|---|---|
| **Hors-ligne** | Aucune dépendance réseau pour les fonctions principales. Internet autorisé uniquement pour la mise à jour des cartes hors-ligne et des voix. |
| **Confidentialité** | Aucune donnée (SMS, contacts, conversations) ne quitte l'appareil. |
| **Latence** | Commande vocale → début d'exécution < 3 s sur un appareil milieu de gamme. |
| **Fiabilité** | Taux de compréhension correct des commandes > 95 % dans un environnement calme. |
| **Accessibilité** | 100 % des fonctions accessibles sans écran ; contrastes et tailles adaptés pour la malvoyance. |
| **Compatibilité** | Android 8.0 (API 26) minimum ; cible Android 14+. |
| **Autonomie** | Mode veille vocale économe ; consommation raisonnable en mode actif. |

---

## 5. Architecture technique (choix validés)

- **Interface utilisateur : Flutter** (choix retenu) — développement rapide, rendu homogène.
- **Service d'accessibilité : Kotlin natif** — *obligatoire*, car Flutter ne peut pas lire/contrôler les autres applications. Ce service est le cœur du système.
- **Communication Flutter ↔ natif :** Platform Channels / MethodChannels.
- **Reconnaissance vocale (ASR) :** Vosk, modèle français (~50 Mo), entièrement local.
- **Synthèse vocale (TTS) :** `android.speech.tts`, voix françaises téléchargées.
- **Mot d'éveil :** Porcupine (Picovoice) sur-appareil.
- **Compréhension (NLU) :** moteur de règles déterministe (grammaire française). IA locale (Gemini Nano / llama.cpp) en secours uniquement.
- **Navigation :** Google Maps (Intent + cartes hors-ligne), guidage vocal natif.
- **Permissions :** lecture via `PackageManager`, explication locale, guidage vers les réglages.

```
[Flutter — UI & orchestration]
        │ MethodChannels
[Kotlin — AccessibilityService + ASR/TTS + NLU + Actions]
        │
[Système Android : apps tierces (WhatsApp, Maps, Téléphone, SMS)]
```

---

## 6. Spécifications détaillées par fonction

### 6.1 F1 — Appels
- **Commande type :** « Appelle maman », « Appelle le 06 12 34 56 78 ».
- **Flux :** reconnaissance → résolution du contact → annonce « Voulez-vous appeler maman ? » → confirmation (« Oui ») → appel via `TelecomManager`/`ACTION_CALL` (permission `CALL_PHONE`).
- **Critères d'acceptation :** l'appel est lancé en < 3 s ; annonce claire avant l'appel ; possibilité d'annuler.

### 6.2 F2 — SMS
- **Commandes :** « Lis mes messages », « Envoie un SMS à Jean : je serai en retard ».
- **Flux :** lecture via `ContentResolver` ; envoi via `SmsManager` ; dictée du corps du message avec relecture avant envoi.
- **Contraintes :** l'app doit être **app SMS par défaut** (Android 4.4+) ; permission `READ_SMS`.
- **Critères d'acceptation :** lecture fidèle expéditeur + contenu ; envoi avec confirmation et relecture avant validation.

### 6.3 F3 — WhatsApp
- **Commandes :** « Lis mes messages WhatsApp », « Envoie à Pierre sur WhatsApp : je rentre ».
- **Méthode :** automatisation d'écran via l'AccessibilityService (ouvrir l'app, lire les nœuds, saisir dans le champ, cliquer « Envoyer »).
- **Limites connues :** structure d'écran dépendante des versions de WhatsApp ; maintenance nécessaire.
- **Critères d'acceptation :** lecture des messages non lus ; envoi fiable d'un message à un contact.

### 6.4 F4 — Navigation
- **Commandes :** « Guide-moi vers la pharmacie la plus proche », « Emmène-moi à la maison ».
- **Méthode :** résolution du lieu (favoris, ou recherche dictée) → ouverture Google Maps avec l'itinéraire ; les cartes hors-ligne assurent le fonctionnement sans connexion.
- **Critères d'acceptation :** lancement de l'itinéraire ; guidage vocal fourni par Google Maps ; retour à l'assistant à la fin.

### 6.5 F5 — Permissions
- **Commandes :** « Quelles permissions utilise WhatsApp ? », « Explique les permissions de cette application ».
- **Méthode :** `PackageManager.getPackageInfo(..., GET_PERMISSIONS)` → explication locale en français → ouverture de l'écran de réglages (`ACTION_APPLICATION_DETAILS_SETTINGS`) avec guidage vocal.
- **Limite système :** l'assistant **ne peut pas modifier** les permissions d'une autre app ; il guide l'utilisateur.

---

## 7. Modèle vocal (UX conversationnelle)

- **Toujours annoncer** : ce que l'assistant a compris (« J'ai compris : appeler maman »), ce qu'il va faire, et le résultat.
- **Confirmation obligatoire** avant toute action irréversible (appel, envoi de message).
- **Relecture** de tout message avant envoi.
- **Gestion des erreurs** : en cas d'incompréhension, reformuler la demande et proposer des alternatives (« Vouliez-vous dire : appeler maman ? »).
- **Ton :** naturel, calme, phrases courtes.

---

## 8. Sécurité et confidentialité

- Traitement 100 % local : aucune transmission des SMS, contacts, conversations.
- Permissions demandées réduites au strict nécessaire, expliquées à l'utilisateur.
- Journalisation locale anonymisée (aucun contenu personnel dans les logs).
- Les données de cartes et les modèles vocaux sont les seuls téléchargements autorisés.

---

## 9. Plan de tests

- **Tests unitaires** du moteur de compréhension (jeu de commandes françaises, y compris reformulations).
- **Tests d'intégration** : chaque fonction (appel, SMS, WhatsApp, navigation, permissions).
- **Tests hors-ligne** : mode avion activé, vérifier que tout fonctionne.
- **Tests utilisateurs aveugles** : au moins 5 utilisateurs, scénarios de bout en bout, mesure du taux de réussite et du temps.
- **Tests de robustesse WhatsApp** : à chaque mise à jour majeure de l'app.

---

## 10. Jalons et livrables

| Phase | Contenu | Durée estimée |
|---|---|---|
| 0 — Fondations | Projet Flutter + AccessibilityService Kotlin, boucle ASR→TTS, lecture d'écran | 2 sem. |
| 1 — MVP | Moteur de règles, appels + SMS complets | 3 sem. |
| 2 — WhatsApp | Automatisation d'écran (lire + envoyer) | 3 sem. |
| 3 — Navigation | Google Maps + cartes hors-ligne, guidage | 2 sem. |
| 4 — Permissions & confort | Assistant permissions, mot d'éveil, résumé IA locale | 2 sem. |
| **Total** | | **≈ 12 semaines** |

---

## 11. Risques

1. **WhatsApp** : cassure possible à chaque mise à jour (maintenance continue).
2. **SMS par défaut** : contrainte à bien expliquer à l'utilisateur.
3. **Modification des permissions d'autrui** : impossible (limite système) — objectif reformulé en « expliquer + guider ».
4. **IA locale** : qualité moindre que le cloud — utilisée en secours uniquement.
5. **Batterie** : mot d'éveil + ASR continus — prévoir un mode d'activation alternatif (geste/bouton).

---

## 12. Livrables du projet

1. Application Android (APK) installable.
2. Documentation d'installation et d'activation (service d'accessibilité, app SMS par défaut, cartes hors-ligne).
3. Guide utilisateur en version audio.
4. Rapports de tests (dont tests avec utilisateurs aveugles).
