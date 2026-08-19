# Extension des fonctions — JCV Voice Control Android

> Complément au cahier des charges. Ajout des fonctions demandées (données locales, photo/vidéo, musique, YouTube, Gmail, navigation web, lecture PDF/documents/images) + propositions supplémentaires.

---

## ⚠️ Règle de classification (à garder en tête)

Le **cerveau** de l'application (reconnaissance vocale, compréhension, synthèse, lecture de fichiers) reste **100 % local**. Mais le **contenu** de certaines fonctions vient d'Internet. Chaque fonction est donc étiquetée :

| Étiquette | Signification |
|---|---|
| 🟢 **Hors-ligne** | Aucun Internet nécessaire, ni pour le traitement, ni pour le contenu. |
| 🟡 **Mixte** | Traitement local, mais contenu partiellement en ligne (ex. mails déjà téléchargés lisibles hors-ligne). |
| 🔴 **En ligne** | Le contenu exige Internet (vidéo, web, envoi de mail). Le traitement reste local. |

---

## 1. Fonctions demandées

### 📁 1.1 Accès aux données locales (fichiers, galerie)
- **Détail :** naviguer dans les dossiers, lister photos, vidéos, documents, musique.
- **Méthode :** `MediaStore` + `Storage Access Framework` (accès aux fichiers de l'utilisateur avec son consentement).
- **Vocal :** « Quelles photos ai-je prises cette semaine ? », « Ouvre le dossier Documents ».
- **Statut :** 🟢 Hors-ligne.
- **Permissions :** `READ_MEDIA_IMAGES/VIDEO/AUDIO` (Android 13+), `READ_EXTERNAL_STORAGE` (avant).

### 📷 1.2 Prise de photo / vidéo
- **Détail :** prendre une photo/vidéo à la voix, puis l'**analyser** (OCR) — très utile pour lire un document, une étiquette, un écran.
- **Méthode :** `CameraX` ou `Intent` caméra ; analyse via **OCR local** (ML Kit sur-appareil) ou modèle de vision local.
- **Vocal :** « Prends une photo et lis-moi ce qui est écrit dessus ».
- **Statut :** 🟢 Hors-ligne (la prise de vue et l'OCR sont locaux).
- **Permissions :** `CAMERA`.

### 🎵 1.3 Jouer de la musique
- **Détail :** lire les morceaux locaux, contrôler la lecture (pause, suivant, volume), par artiste/album/playlist.
- **Méthode :** `MediaPlayer` / `MediaSession` ; indexation locale de la bibliothèque.
- **Vocal :** « Joue de la musique », « Mets le volume à 50 % », « Chanson suivante ».
- **Statut :** 🟢 Hors-ligne (musique locale).
- **Note :** les services de streaming (Spotify, Deezer) passent en 🔴 En ligne, pilotables via l'accessibilité ou leurs intents.

### ▶️ 1.4 YouTube
- **Détail :** ouvrir YouTube, rechercher une vidéo, la lancer, contrôler la lecture.
- **Méthode :** `Intent` YouTube (recherche/lecture) + AccessibilityService pour le contrôle précis.
- **Vocal :** « Ouvre YouTube et cherche des tutoriels de cuisine », « Mets en pause ».
- **Statut :** 🔴 En ligne (les vidéos viennent d'Internet) — traitement local.

### ✉️ 1.5 Gmail
- **Détail :** lire les e-mails reçus, dicter et envoyer un e-mail, annoncer les nouveaux messages.
- **Méthode :** `Intent` pour composer (`ACTION_SENDTO`) ; lecture via AccessibilityService (e-mails déjà synchronisés lisibles hors-ligne).
- **Vocal :** « Lis mes derniers e-mails », « Écris à Jean : objet Réunion, contenu … ».
- **Statut :** 🟡 Mixte (lecture possible hors-ligne, envoi/réception en ligne).

### 🌐 1.6 Naviguer sur les plateformes (web)
- **Détail :** ouvrir un site, lire une page à voix haute, rechercher sur le web.
- **Méthode :** navigateur intégré (WebView) avec **lecture vocale du contenu** (mode lecture), ou `Intent` vers le navigateur + accessibility.
- **Vocal :** « Ouvre Wikipédia et lis l'article sur … », « Recherche la météo à Cotonou ».
- **Statut :** 🔴 En ligne (contenu web). Le rendu vocal reste local.
- **Astuce :** un **mode lecture** (extraction du texte seul) améliore énormément l'expérience des aveugles sur le web.

### 📄 1.7 Lecture PDF / documents / images
- **Détail :** ouvrir un PDF ou un document (Word, texte) et le **lire à voix haute** ; décrire une image.
- **Méthode :**
  - PDF texte → extraction du texte (bibliothèque locale) + TTS.
  - PDF scanné / image → **OCR local** (ML Kit, Tesseract).
  - Description d'image → modèle de vision local (MediaPipe, ou Gemini Nano sur appareils compatibles).
- **Vocal :** « Lis-moi ce PDF », « Décris cette image », « Lis le texte de cette photo ».
- **Statut :** 🟢 Hors-ligne (tout est sur l'appareil).
- **Permissions :** accès fichiers.

---

## 2. Autres fonctions que je propose (forte valeur pour une personne aveugle)

### 🔍 Perception assistée (priorité haute)
| Fonction | Description | Statut |
|---|---|---|
| **OCR temps réel (caméra)** | Pointer la caméra vers un texte (étiquette, facture, livre) et entendre le texte lu | 🟢 |
| **Reconnaissance d'objets** | « Qu'est-ce que j'ai devant moi ? » via modèle de vision local | 🟢 |
| **Reconnaissance de billets de banque** | Identifier la valeur d'un billet (modèles légers disponibles) | 🟢 |
| **Lecture de l'écran par OCR** | Capturer l'écran courant et lire son texte quand l'accessibilité est insuffisante | 🟢 |

### 📅 Organisation personnelle
| Fonction | Description | Statut |
|---|---|---|
| **Agenda / calendrier** | Lire les rendez-vous, en créer à la voix (`CalendarProvider`) | 🟢 |
| **Alarmes & minuteurs** | Régler une alarme, un minuteur, une horloge | 🟢 |
| **Notes & dictée** | Prendre des notes, les relire, listes de courses | 🟢 |
| **Rappels de médicaments** | Rappels vocaux à heure fixe | 🟢 |
| **Liste de contacts** | Lire, ajouter, modifier les contacts | 🟢 |

### ⚙️ Contrôle du téléphone (très demandé)
| Fonction | Description | Statut |
|---|---|---|
| **Réglages rapides** | Activer/couper Wi-Fi, Bluetooth, mode avion, lampe torche | 🟢 (torche/volume) / 🟡 (réglages restreints) |
| **Volume & luminosité** | « Baisse le volume », « Allume la torche » | 🟢 |
| **État du téléphone** | « Quelle est ma batterie ? », « Ai-je des notifications ? » | 🟢 |
| **Traduction hors-ligne** | Traduire un texte lu via ML Kit sur-appareil (FR↔EN…) | 🟢 |

### 🚨 Sécurité & urgence (essentiel pour l'autonomie)
| Fonction | Description | Statut |
|---|---|---|
| **Bouton / commande SOS** | « Appelle à l'aide » → SMS/position à des contacts de confiance | 🟢 (appel/SMS local) |
| **Partage de position d'urgence** | Envoyer sa localisation GPS à un proche | 🟡 (GPS local, envoi SMS local) |
| **Lecture des notifications** | Annoncer toutes les notifications entrantes | 🟢 |

### 📚 Culture & loisirs
| Fonction | Description | Statut |
|---|---|---|
| **Lecture de livres (ePub/txt)** | Lire un livre à voix haute, reprendre où on s'était arrêté | 🟢 |
| **Radio FM** | Radio locale du téléphone (si tuner présent) | 🟢 |
| **Podcasts téléchargés** | Lire les épisodes déjà enregistrés | 🟢 |

---

## 3. Matrice récapitulative (priorisation conseillée)

| Priorité | Fonctions | Justification |
|---|---|---|
| **P0 — Immédiat** | Lecture PDF/documents, OCR images, musique locale, lecture notifications, alarmes | 100 % hors-ligne, très forte valeur quotidienne, faible complexité |
| **P1 — Court terme** | Prise photo + OCR, perception (objets/billets), agenda, notes, réglages (volume/torche), SOS | Autonomie critique, tout local |
| **P2 — Moyen terme** | Gmail (lecture), YouTube (contrôle), navigation web (mode lecture) | Nécessitent Internet ou automatisation d'écran plus fragile |
| **P3 — Long terme** | Description d'images/scènes riches (vision locale avancée), traduction, contrôle de réglages système restreints | Dépend de la puissance du téléphone / modèles locaux |

---

## 4. Impacts sur l'architecture

1. **Nouveau module « Perception »** : OCR + vision (ML Kit, Tesseract, MediaPipe) — tout sur-appareil.
2. **Nouveau module « Médias »** : lecteur audio local (MediaPlayer/MediaSession) + contrôle par commandes vocales.
3. **Nouveau module « Fichiers »** : explorateur de fichiers/gallerie avec lecture TTS des contenus.
4. **Nouveau module « Connecté »** : YouTube, Gmail, web — isolé dans un sous-système clairement marqué « en ligne », avec bascule hors-ligne propre.
5. **Sécurité/confidentialité** : les modules 🟢 ne transmettent rien ; les modules 🔴 ne transmettent que ce qui est strictement nécessaire à la requête de l'utilisateur.

## 5. Permissions supplémentaires à prévoir

`CAMERA`, `READ_MEDIA_IMAGES/VIDEO/AUDIO`, `READ_EXTERNAL_STORAGE`, `READ_CALENDAR`/`WRITE_CALENDAR`, `SET_ALARM`, `READ_CONTACTS`, `ACCESS_FINE_LOCATION` (SOS), `INTERNET` (uniquement pour les modules 🔴/🟡).

## 6. Questions restantes pour toi

1. La **caméra + OCR/description** (fonction « perception ») est-elle une priorité pour toi ? C'est la plus grande valeur ajoutée pour une personne aveugle.
2. Acceptes-tu le **classement 🟢/🟡/🔴**, ou veux-tu exclure totalement les fonctions « en ligne » (YouTube, web) ?
3. Veux-tu que j'**intègre tout ceci au cahier des charges** en une seule version consolidée ?
