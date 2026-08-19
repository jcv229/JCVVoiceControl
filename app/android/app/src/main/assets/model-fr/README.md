# Modèle Vosk français — à télécharger

Ce dossier doit contenir le modèle acoustique **Vosk français**, décompressé,
pour la reconnaissance vocale hors-ligne.

## Instructions

1. Téléchargez le modèle français « small » (~40 Mo) depuis :
   https://alphacephei.com/vosk/models
   → fichier : `vosk-model-small-fr-0.22.zip`

2. Décompressez-le. Vous obtenez un dossier `vosk-model-small-fr-0.22`
   contenant des sous-dossiers (`am/`, `conf/`, `graph/`, `ivector/`) et des
   fichiers (`README`, etc.).

3. Copiez le **contenu** de ce dossier (les fichiers et sous-dossiers,
   pas le dossier parent) dans :
   `android/app/src/main/assets/model-fr/`

   Le résultat attendu :
   ```
   android/app/src/main/assets/model-fr/
   ├── am/
   ├── conf/
   ├── graph/
   ├── ivector/
   └── README
   ```

4. Recompilez : `flutter build apk --debug`

Au premier lancement, l'application copie automatiquement le modèle des assets
vers le stockage interne (via `StorageService.unpack`), puis la reconnaissance
vocale devient disponible hors-ligne.

> **Remarque** : le modèle n'est PAS inclus dans ce dépôt en raison de sa
> taille (~40 Mo). Vous devez le télécharger une fois et le placer ici.
