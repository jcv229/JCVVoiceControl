# Guide — Compilation automatique de l'APK (GitHub Actions)

Ce guide explique comment compiler **JCV Voice Control** automatiquement sur
GitHub, sans machine locale, et télécharger l'APK final.

---

## 1. Fichiers fournis

| Fichier | Rôle |
|---|---|
| `.github/workflows/build-apk.yml` | Le workflow de compilation (push → APK) |
| `app/.gitignore` | Ignore les fichiers générés + le modèle Vosk (trop volumineux) |

---

## 2. Mise en place (une seule fois)

### 2.1 Vérifier la version de Flutter

Dans `.github/workflows/build-apk.yml`, adaptez la ligne :

```yaml
with:
  flutter-version: '3.24.5'   # ⚠️ mettre VOTRE version exacte
```

Pour connaître votre version : `flutter --version` (sur votre machine).

### 2.2 Pousser le code sur GitHub

```bash
cd JCVVOICECONTROL
git add .
git commit -m "Ajout du workflow CI + configuration"
git push origin master
```

Dès le push, **GitHub Actions lance automatiquement la compilation**.
Vous suivez la progression dans l'onglet **Actions** de votre dépôt.

---

## 3. Ce que fait le workflow (étapes)

1. Récupère le code source.
2. Installe **Flutter** (version épinglée).
3. Installe **Java 17** (requis par AGP 8.x).
4. **Télécharge le modèle Vosk français (~40 Mo)** et le place dans les assets
   (c'est pourquoi il ne doit pas être dans le repo).
5. `flutter pub get` → récupère les dépendances.
6. `flutter analyze` + `flutter test` → contrôle qualité (53 tests).
7. `flutter build apk --release` → compile l'APK.
8. **Publie l'APK** en artefact téléchargeable.
9. Si vous poussez un **tag** (`v1.0`), crée aussi une **release GitHub** avec l'APK.

---

## 4. Télécharger l'APK

1. Ouvrez votre dépôt GitHub → onglet **Actions**.
2. Cliquez sur le build réussi le plus récent.
3. Tout en bas, dans **Artifacts**, téléchargez **JCVVoiceControl-release**.

---

## 5. Signer l'APK (recommandé pour la distribution)

Actuellement l'APK est compilé en **release non signée** (ou signée avec la clé
de debug selon le build.gradle). Pour distribuer sur un vrai appareil :

1. Générez un keystore local :
   ```bash
   keytool -genkey -v -keystore jcv-voice-control.jks -keyalg RSA -keysize 2048 -validity 10000 -alias jcv
   ```
2. Stockez-le en **secret GitHub** (Settings → Secrets and variables → Actions) :
   - `KEYSTORE_BASE64` : le fichier `.jks` encodé en base64
   - `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`
3. Ajoutez une étape dans le workflow qui décode le keystore et configure la
   signature (`signingConfigs.release`).

---

## 6. Dépannage rapide

| Symptôme | Cause probable | Solution |
|---|---|---|
| `compileSdk 36 requires AGP...` | Plugin Gradle trop ancien | Mettre à jour `com.android.application` dans `android/settings.gradle` |
| `file_picker` erreur API | Mauvaise version du plugin | Rester sur `file_picker: 10.3.10` + `FilePicker.platform.*` |
| Modèle Vosk introuvable | Étape de téléchargement échouée | Vérifier l'URL + la connexion du runner |
| Build trop lent | Pas de cache | Le `cache: true` de flutter-action est déjà activé |

---

## 7. Rappel — activations après installation

Une fois l'APK installé sur le téléphone :
1. **Service d'accessibilité** (Réglages → Accessibilité → JCV Voice Control)
2. **Application SMS par défaut**
3. **Voix françaises hors-ligne** (Réglages → Synthèse vocale)
4. **Permission microphone** (au premier appui sur le micro)
