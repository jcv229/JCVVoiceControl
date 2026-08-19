#!/usr/bin/env bash
#
# Script d'installation automatique de JCV Voice Control.
#
# Il crée un projet Flutter Android « propre » (pour générer le wrapper Gradle
# et tous les fichiers de plateforme adaptés à VOTRE version de Flutter), puis
# y injecte le code source de l'assistant (Dart + Kotlin + manifest).
#
# Usage :
#   ./setup.sh [nom_du_dossier]
#
# Exemple :
#   ./setup.sh mon_assistant
#
set -euo pipefail

# Répertoire de ce script (le dossier contenant lib/, android/, etc.)
APP_DIR="$(cd "$(dirname "$0")" && pwd)"

# Dossier du projet à créer (par défaut : jcv_voice_control_app)
TARGET="${1:-jcv_voice_control_app}"

# Identifiants du projet (cohérents avec le code fourni)
ORG="com.jcv"
PROJECT_NAME="jcv_voice_control"

echo "======================================================"
echo " JCV Voice Control — Installation automatique"
echo "======================================================"

# 1) Vérifier que Flutter est disponible
if ! command -v flutter >/dev/null 2>&1; then
  echo "ERREUR : Flutter n'est pas installé ou pas dans le PATH."
  echo "Installez-le : https://docs.flutter.dev/get-started/install"
  exit 1
fi
echo "✔ Flutter détecté : $(flutter --version | head -1)"

# 2) Créer le projet Flutter
echo ""
echo "➜ Étape 1/5 : création du projet Flutter « $TARGET »..."
flutter create --org "$ORG" --project-name "$PROJECT_NAME" "$TARGET"

# 3) Copier le code source
echo ""
echo "➜ Étape 2/5 : copie du code source..."
# Code Dart
cp -r "$APP_DIR/lib" "$TARGET/"
cp -r "$APP_DIR/test" "$TARGET/"
# Code natif Kotlin (remplace le MainActivity de template)
rm -rf "$TARGET/android/app/src/main/kotlin"
cp -r "$APP_DIR/android/app/src/main/kotlin" "$TARGET/android/app/src/main/"
# Manifest (permissions + service d'accessibilité + récepteur SMS)
cp "$APP_DIR/android/app/src/main/AndroidManifest.xml" "$TARGET/android/app/src/main/"
# Configuration du service d'accessibilité
mkdir -p "$TARGET/android/app/src/main/res/xml"
cp "$APP_DIR/android/app/src/main/res/xml/accessibility_service_config.xml" \
   "$TARGET/android/app/src/main/res/xml/"
# Chaînes (libellés du service d'accessibilité)
cp "$APP_DIR/android/app/src/main/res/values/strings.xml" \
   "$TARGET/android/app/src/main/res/values/"
# Assets (modèle Vosk : dossier + instructions de téléchargement)
mkdir -p "$TARGET/android/app/src/main/assets"
cp -r "$APP_DIR/android/app/src/main/assets/." \
   "$TARGET/android/app/src/main/assets/"

# 4) Ajuster minSdk à 26 (Android 8.0, requis par le cahier des charges)
echo ""
echo "➜ Étape 3/6 : ajustement de minSdkVersion à 26..."
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 26/' \
  "$TARGET/android/app/build.gradle"

# 4bis) Ajouter les dépendances natives (ML Kit + CameraX + Vosk) au build.gradle
echo ""
echo "➜ Étape 4/6 : ajout des dépendances natives (CameraX + ML Kit + Vosk)..."
python3 - "$TARGET/android/app/build.gradle" << 'PY'
import sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    content = f.read()

# 1) Dépendances natives
marker = "dependencies {"
if "camera-core" not in content:
    idx = content.index(marker) + len(marker)
    insert = '''
    implementation("androidx.camera:camera-core:1.3.4")
    implementation("androidx.camera:camera-camera2:1.3.4")
    implementation("androidx.camera:camera-lifecycle:1.3.4")
    implementation("androidx.camera:camera-view:1.3.4")
    implementation("com.google.mlkit:text-recognition:16.0.1")
    implementation("com.google.mlkit:image-labeling:17.0.8")
    implementation("com.alphacephei:vosk-android:0.3.47")
'''
    content = content[:idx] + insert + content[idx:]
    print("   ✔ Dépendances natives ajoutées")
else:
    print("   (déjà présentes)")

# 2) packagingOptions pour éviter le conflit libc++_shared.so (Vosk)
if "packagingOptions" not in content:
    anchor = "android {"
    idx = content.index(anchor) + len(anchor)
    insert2 = '''
    packagingOptions {
        pickFirst 'lib/**/libc++_shared.so'
    }
'''
    content = content[:idx] + insert2 + content[idx:]
    print("   ✔ packagingOptions ajouté (libc++_shared.so)")

# 3) Forcer namespace + applicationId vers com.jcv.voicecontrol
# (flutter create génère com.jcv.jcv_voice_control par défaut, ce qui
#  ne correspondrait pas au package Kotlin com.jcv.voicecontrol).
import re
content = re.sub(r'namespace\s+"[^"]*"', 'namespace "com.jcv.voicecontrol"', content)
content = re.sub(r'applicationId\s+"[^"]*"', 'applicationId "com.jcv.voicecontrol"', content)
print("   ✔ namespace/applicationId = com.jcv.voicecontrol")

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PY

# 5) Ajouter les dépendances Dart
echo ""
echo "➜ Étape 5/6 : ajout des dépendances Dart..."
cd "$TARGET"
flutter pub add flutter_tts permission_handler cupertino_icons

# 6) Récupérer les dépendances et lancer les tests
echo ""
echo "➜ Étape 6/6 : récupération des dépendances + tests..."
flutter pub get
flutter test

echo ""
echo "======================================================"
echo " ✔ Installation terminée avec succès !"
echo "======================================================"
echo ""
echo "Pour compiler l'APK :"
echo "  cd $TARGET && flutter build apk --debug"
echo ""
echo "Après installation sur l'appareil, n'oubliez pas d'activer :"
echo "  1. Le service d'accessibilité (Réglages > Accessibilité > JCV Voice Control)"
echo "  2. L'application SMS par défaut (pour lire/envoyer les SMS)"
echo "  3. Les voix françaises hors-ligne (Réglages > Synthèse vocale)"
echo "  4. La permission microphone (à la première écoute)"
echo ""
echo "⚠️  IMPORTANT — reconnaissance vocale (Vosk) :"
echo "  Le modèle français (~40 Mo) n'est PAS inclus dans ce dépôt."
echo "  Téléchargez-le et placez-le AVANT de compiler :"
echo "    https://alphacephei.com/vosk/models  →  vosk-model-small-fr-0.22.zip"
echo "  puis copiez son contenu dans :"
echo "    $TARGET/android/app/src/main/assets/model-fr/"
echo "  (voir le fichier android/app/src/main/assets/model-fr/README.md)"
echo ""
