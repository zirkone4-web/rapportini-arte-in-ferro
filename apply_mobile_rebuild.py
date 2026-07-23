#!/usr/bin/env python3
from __future__ import annotations

import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

REPO_NAME = "rapportini-arte-in-ferro"
EXPECTED_BRANCH = "ricostruzione-mobile-integrata"

WORKFLOW = 'name: Build mobile integrato\n\non:\n  workflow_dispatch:\n  push:\n    branches:\n      - ricostruzione-mobile-integrata\n      - main\n    paths:\n      - "apps/mobile/**"\n      - "tools/bootstrap_mobile.sh"\n      - "tools/configure_mobile_platforms.py"\n      - ".github/workflows/build-mobile-integrato.yml"\n\npermissions:\n  contents: read\n\nconcurrency:\n  group: mobile-integrato-${{ github.ref }}\n  cancel-in-progress: true\n\njobs:\n  qualita:\n    name: Analisi e test Flutter\n    runs-on: ubuntu-latest\n    timeout-minutes: 25\n    steps:\n      - uses: actions/checkout@v4\n      - uses: subosito/flutter-action@v2\n        with:\n          channel: stable\n          cache: true\n      - name: Genera piattaforme Android e iOS\n        run: bash tools/bootstrap_mobile.sh\n      - name: Analisi statica\n        working-directory: apps/mobile\n        run: flutter analyze --no-fatal-infos\n      - name: Test automatici\n        working-directory: apps/mobile\n        run: flutter test\n\n  android:\n    name: APK e AAB Android\n    needs: qualita\n    runs-on: ubuntu-latest\n    timeout-minutes: 35\n    defaults:\n      run:\n        working-directory: apps/mobile\n    steps:\n      - uses: actions/checkout@v4\n      - uses: actions/setup-java@v4\n        with:\n          distribution: temurin\n          java-version: "17"\n      - uses: subosito/flutter-action@v2\n        with:\n          channel: stable\n          cache: true\n      - name: Genera piattaforme e permessi\n        working-directory: .\n        run: bash tools/bootstrap_mobile.sh\n      - name: Configura firma Android\n        env:\n          KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}\n          KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}\n          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}\n          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}\n        run: |\n          test -n "$KEYSTORE_BASE64"\n          test -n "$KEYSTORE_PASSWORD"\n          test -n "$KEY_ALIAS"\n          test -n "$KEY_PASSWORD"\n          python3 - <<\'PY\'\n          import base64, os, pathlib, string\n          raw = os.environ["KEYSTORE_BASE64"].strip()\n          is_hex = len(raw) % 2 == 0 and all(c in string.hexdigits for c in raw)\n          data = bytes.fromhex(raw) if is_hex else base64.b64decode(raw)\n          pathlib.Path("android/app/arte-in-ferro-upload.jks").write_bytes(data)\n          PY\n          printf \'storePassword=%s\\nkeyPassword=%s\\nkeyAlias=%s\\nstoreFile=arte-in-ferro-upload.jks\\n\' \\\n            "$KEYSTORE_PASSWORD" "$KEY_PASSWORD" "$KEY_ALIAS" > android/key.properties\n      - name: Prepara configurazione Android\n        env:\n          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}\n          SUPABASE_PUBLISHABLE_KEY: ${{ secrets.SUPABASE_PUBLISHABLE_KEY }}\n          FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_PROJECT_ID }}\n          FIREBASE_API_KEY: ${{ secrets.FIREBASE_API_KEY }}\n          FIREBASE_MESSAGING_SENDER_ID: ${{ secrets.FIREBASE_MESSAGING_SENDER_ID }}\n          FIREBASE_ANDROID_APP_ID: ${{ secrets.FIREBASE_ANDROID_APP_ID }}\n          FIREBASE_APP_ID: ${{ secrets.FIREBASE_APP_ID }}\n        run: |\n          python3 - <<\'PY\'\n          import json, os, pathlib\n          keys = (\n              "SUPABASE_URL",\n              "SUPABASE_PUBLISHABLE_KEY",\n              "FIREBASE_PROJECT_ID",\n              "FIREBASE_API_KEY",\n              "FIREBASE_MESSAGING_SENDER_ID",\n              "FIREBASE_ANDROID_APP_ID",\n              "FIREBASE_APP_ID",\n          )\n          values = {key: os.environ[key] for key in keys if os.environ.get(key)}\n          pathlib.Path("build-defines.json").write_text(\n              json.dumps(values), encoding="utf-8"\n          )\n          PY\n      - name: Crea APK release\n        run: flutter build apk --release --dart-define-from-file=build-defines.json\n      - name: Crea AAB Play Store\n        run: flutter build appbundle --release --dart-define-from-file=build-defines.json\n      - uses: actions/upload-artifact@v4\n        with:\n          name: arte-in-ferro-android-apk\n          path: apps/mobile/build/app/outputs/flutter-apk/app-release.apk\n          if-no-files-found: error\n          retention-days: 14\n      - uses: actions/upload-artifact@v4\n        with:\n          name: arte-in-ferro-play-store-aab\n          path: apps/mobile/build/app/outputs/bundle/release/app-release.aab\n          if-no-files-found: error\n          retention-days: 14\n\n  ios:\n    name: App iPhone nativa\n    needs: qualita\n    runs-on: macos-latest\n    timeout-minutes: 50\n    defaults:\n      run:\n        working-directory: apps/mobile\n    steps:\n      - uses: actions/checkout@v4\n      - uses: subosito/flutter-action@v2\n        with:\n          channel: stable\n          cache: true\n      - name: Genera piattaforme e permessi iOS\n        working-directory: .\n        env:\n          IOS_BUNDLE_ID: ${{ secrets.IOS_BUNDLE_ID }}\n        run: bash tools/bootstrap_mobile.sh\n      - name: Prepara configurazione iPhone\n        env:\n          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}\n          SUPABASE_PUBLISHABLE_KEY: ${{ secrets.SUPABASE_PUBLISHABLE_KEY }}\n          FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_PROJECT_ID }}\n          FIREBASE_API_KEY: ${{ secrets.FIREBASE_API_KEY }}\n          FIREBASE_MESSAGING_SENDER_ID: ${{ secrets.FIREBASE_MESSAGING_SENDER_ID }}\n          FIREBASE_IOS_APP_ID: ${{ secrets.FIREBASE_IOS_APP_ID }}\n          FIREBASE_IOS_BUNDLE_ID: ${{ secrets.IOS_BUNDLE_ID }}\n          FIREBASE_APP_ID: ${{ secrets.FIREBASE_APP_ID }}\n        run: |\n          python3 - <<\'PY\'\n          import json, os, pathlib\n          keys = (\n              "SUPABASE_URL",\n              "SUPABASE_PUBLISHABLE_KEY",\n              "FIREBASE_PROJECT_ID",\n              "FIREBASE_API_KEY",\n              "FIREBASE_MESSAGING_SENDER_ID",\n              "FIREBASE_IOS_APP_ID",\n              "FIREBASE_IOS_BUNDLE_ID",\n              "FIREBASE_APP_ID",\n          )\n          values = {key: os.environ[key] for key in keys if os.environ.get(key)}\n          pathlib.Path("build-defines.json").write_text(\n              json.dumps(values), encoding="utf-8"\n          )\n          PY\n      - name: Compila iOS senza firma\n        run: flutter build ios --release --no-codesign --dart-define-from-file=build-defines.json\n      - name: Prepara pacchetto di verifica\n        run: ditto -c -k --sequesterRsrc --keepParent build/ios/iphoneos/Runner.app ArteInFerro-iOS-verifica.zip\n      - uses: actions/upload-artifact@v4\n        with:\n          name: arte-in-ferro-ios-verifica\n          path: apps/mobile/ArteInFerro-iOS-verifica.zip\n          if-no-files-found: error\n          retention-days: 14\n      - name: Verifica credenziali Apple\n        id: apple\n        env:\n          CERTIFICATE: ${{ secrets.IOS_CERTIFICATE_BASE64 }}\n          CERTIFICATE_PASSWORD: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}\n          PROFILE: ${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}\n          TEAM_ID: ${{ secrets.IOS_TEAM_ID }}\n          BUNDLE_ID: ${{ secrets.IOS_BUNDLE_ID }}\n        run: |\n          if [[ -n "$CERTIFICATE" && -n "$CERTIFICATE_PASSWORD" && -n "$PROFILE" && -n "$TEAM_ID" && -n "$BUNDLE_ID" ]]; then\n            echo "enabled=true" >> "$GITHUB_OUTPUT"\n          else\n            echo "enabled=false" >> "$GITHUB_OUTPUT"\n          fi\n      - name: Crea IPA firmata\n        if: steps.apple.outputs.enabled == \'true\'\n        env:\n          IOS_CERTIFICATE_BASE64: ${{ secrets.IOS_CERTIFICATE_BASE64 }}\n          IOS_CERTIFICATE_PASSWORD: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}\n          IOS_PROVISIONING_PROFILE_BASE64: ${{ secrets.IOS_PROVISIONING_PROFILE_BASE64 }}\n          IOS_TEAM_ID: ${{ secrets.IOS_TEAM_ID }}\n          IOS_BUNDLE_ID: ${{ secrets.IOS_BUNDLE_ID }}\n        run: |\n          KEYCHAIN_PATH="$RUNNER_TEMP/arte-in-ferro.keychain-db"\n          KEYCHAIN_PASSWORD="$(openssl rand -base64 24)"\n\n          python3 - <<\'PY\'\n          import base64, os, pathlib\n          pathlib.Path(os.environ["RUNNER_TEMP"], "distribution.p12").write_bytes(\n              base64.b64decode(os.environ["IOS_CERTIFICATE_BASE64"])\n          )\n          pathlib.Path(os.environ["RUNNER_TEMP"], "profile.mobileprovision").write_bytes(\n              base64.b64decode(os.environ["IOS_PROVISIONING_PROFILE_BASE64"])\n          )\n          PY\n\n          security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"\n          security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"\n          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"\n          security default-keychain -s "$KEYCHAIN_PATH"\n          security import "$RUNNER_TEMP/distribution.p12" \\\n            -P "$IOS_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"\n          security set-key-partition-list -S apple-tool:,apple: \\\n            -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"\n\n          mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"\n          security cms -D -i "$RUNNER_TEMP/profile.mobileprovision" \\\n            > "$RUNNER_TEMP/profile.plist"\n          PROFILE_UUID=$(/usr/libexec/PlistBuddy -c \'Print UUID\' "$RUNNER_TEMP/profile.plist")\n          PROFILE_NAME=$(/usr/libexec/PlistBuddy -c \'Print Name\' "$RUNNER_TEMP/profile.plist")\n          cp "$RUNNER_TEMP/profile.mobileprovision" \\\n            "$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"\n          export PROFILE_NAME\n\n          python3 - <<\'PY\'\n          import os, pathlib, re\n          path = pathlib.Path("ios/Runner.xcodeproj/project.pbxproj")\n          lines = path.read_text(encoding="utf-8").splitlines()\n          bundle_id = os.environ["IOS_BUNDLE_ID"]\n          team_id = os.environ["IOS_TEAM_ID"]\n          profile_name = os.environ["PROFILE_NAME"]\n          result = []\n          skip_keys = (\n              "CODE_SIGN_STYLE =",\n              "DEVELOPMENT_TEAM =",\n              "PROVISIONING_PROFILE_SPECIFIER =",\n              "CODE_SIGN_IDENTITY =",\n          )\n          for line in lines:\n              if any(key in line for key in skip_keys):\n                  continue\n              match = re.match(r"(\\s*)PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", line)\n              if not match:\n                  result.append(line)\n                  continue\n              indent, old_id = match.groups()\n              is_test = "RunnerTests" in old_id\n              new_id = f"{bundle_id}.RunnerTests" if is_test else bundle_id\n              result.append(f"{indent}PRODUCT_BUNDLE_IDENTIFIER = {new_id};")\n              if not is_test:\n                  result.append(f"{indent}DEVELOPMENT_TEAM = {team_id};")\n                  result.append(f"{indent}CODE_SIGN_STYLE = Manual;")\n                  result.append(\n                      f\'{indent}PROVISIONING_PROFILE_SPECIFIER = "{profile_name}";\'\n                  )\n                  result.append(\n                      f\'{indent}CODE_SIGN_IDENTITY = "Apple Distribution";\'\n                  )\n          path.write_text("\\n".join(result) + "\\n", encoding="utf-8")\n          PY\n\n          cat > ios/ExportOptions.plist <<EOF\n          <?xml version="1.0" encoding="UTF-8"?>\n          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n          <plist version="1.0">\n          <dict>\n            <key>method</key><string>app-store-connect</string>\n            <key>signingStyle</key><string>manual</string>\n            <key>teamID</key><string>$IOS_TEAM_ID</string>\n            <key>provisioningProfiles</key>\n            <dict>\n              <key>$IOS_BUNDLE_ID</key><string>$PROFILE_NAME</string>\n            </dict>\n            <key>uploadSymbols</key><true/>\n          </dict>\n          </plist>\n          EOF\n\n          flutter build ipa --release \\\n            --export-options-plist=ios/ExportOptions.plist \\\n            --dart-define-from-file=build-defines.json\n      - uses: actions/upload-artifact@v4\n        if: steps.apple.outputs.enabled == \'true\'\n        with:\n          name: arte-in-ferro-iphone-ipa\n          path: apps/mobile/build/ios/ipa/*.ipa\n          if-no-files-found: error\n          retention-days: 14\n'
APP_CONFIG = "import 'dart:io';\n\nclass AppConfig {\n  const AppConfig({\n    required this.supabaseUrl,\n    required this.supabasePublishableKey,\n    this.firebaseProjectId = '',\n    this.firebaseApiKey = '',\n    this.firebaseSenderId = '',\n    this.firebaseAndroidAppId = '',\n    this.firebaseIosAppId = '',\n    this.firebaseIosBundleId = 'it.arteinferrolascari.rapportini',\n  });\n\n  factory AppConfig.fromEnvironment() {\n    const configuredUrl = String.fromEnvironment('SUPABASE_URL');\n    const configuredPublishableKey = String.fromEnvironment(\n      'SUPABASE_PUBLISHABLE_KEY',\n    );\n    final url = configuredUrl.isEmpty\n        ? 'https://oibibghbgcdjyimkvere.supabase.co'\n        : configuredUrl;\n    final publishableKey = configuredPublishableKey.isEmpty\n        ? 'sb_publishable_a2pl_IOhqK3c7_gHUBnnmw_MoKaoptI'\n        : configuredPublishableKey;\n\n    const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');\n    const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');\n    const firebaseSenderId = String.fromEnvironment(\n      'FIREBASE_MESSAGING_SENDER_ID',\n    );\n    const legacyFirebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');\n    const configuredAndroidAppId = String.fromEnvironment(\n      'FIREBASE_ANDROID_APP_ID',\n    );\n    const configuredIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');\n    const configuredIosBundleId = String.fromEnvironment(\n      'FIREBASE_IOS_BUNDLE_ID',\n    );\n\n    if (url.isEmpty || publishableKey.isEmpty) {\n      throw const AppConfigurationException(\n        'Avvia l’app passando SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY '\n        'tramite --dart-define.',\n      );\n    }\n\n    final uri = Uri.tryParse(url);\n    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {\n      throw const AppConfigurationException(\n        'SUPABASE_URL non è un indirizzo valido.',\n      );\n    }\n\n    return AppConfig(\n      supabaseUrl: url,\n      supabasePublishableKey: publishableKey,\n      firebaseProjectId: firebaseProjectId,\n      firebaseApiKey: firebaseApiKey,\n      firebaseSenderId: firebaseSenderId,\n      firebaseAndroidAppId: configuredAndroidAppId.isEmpty\n          ? legacyFirebaseAppId\n          : configuredAndroidAppId,\n      firebaseIosAppId:\n          configuredIosAppId.isEmpty ? legacyFirebaseAppId : configuredIosAppId,\n      firebaseIosBundleId: configuredIosBundleId.isEmpty\n          ? 'it.arteinferrolascari.rapportini'\n          : configuredIosBundleId,\n    );\n  }\n\n  final String supabaseUrl;\n  final String supabasePublishableKey;\n  final String firebaseProjectId;\n  final String firebaseApiKey;\n  final String firebaseSenderId;\n  final String firebaseAndroidAppId;\n  final String firebaseIosAppId;\n  final String firebaseIosBundleId;\n\n  String get firebaseAppId =>\n      Platform.isIOS ? firebaseIosAppId : firebaseAndroidAppId;\n\n  bool get firebaseEnabled =>\n      firebaseProjectId.isNotEmpty &&\n      firebaseAppId.isNotEmpty &&\n      firebaseApiKey.isNotEmpty &&\n      firebaseSenderId.isNotEmpty;\n}\n\nclass AppConfigurationException implements Exception {\n  const AppConfigurationException(this.message);\n\n  final String message;\n\n  @override\n  String toString() => message;\n}\n"
PUSH_SERVICE = "import 'dart:async';\nimport 'dart:io';\n\nimport 'package:arte_in_ferro_rapportini/core/config/app_config.dart';\nimport 'package:firebase_core/firebase_core.dart';\nimport 'package:firebase_messaging/firebase_messaging.dart';\nimport 'package:supabase_flutter/supabase_flutter.dart';\n\nclass PushNotificationService {\n  PushNotificationService._(this._messaging);\n\n  final FirebaseMessaging _messaging;\n  static PushNotificationService? instance;\n  StreamSubscription<String>? _refreshSubscription;\n\n  static Future<void> initialize(AppConfig config) async {\n    if (!config.firebaseEnabled) return;\n\n    try {\n      if (Firebase.apps.isEmpty) {\n        final options = Platform.isIOS\n            ? FirebaseOptions(\n                apiKey: config.firebaseApiKey,\n                appId: config.firebaseAppId,\n                messagingSenderId: config.firebaseSenderId,\n                projectId: config.firebaseProjectId,\n                iosBundleId: config.firebaseIosBundleId,\n              )\n            : FirebaseOptions(\n                apiKey: config.firebaseApiKey,\n                appId: config.firebaseAppId,\n                messagingSenderId: config.firebaseSenderId,\n                projectId: config.firebaseProjectId,\n              );\n\n        await Firebase.initializeApp(options: options);\n      }\n\n      final messaging = FirebaseMessaging.instance;\n      if (Platform.isIOS) {\n        await messaging.setForegroundNotificationPresentationOptions(\n          alert: true,\n          badge: true,\n          sound: true,\n        );\n      }\n      instance = PushNotificationService._(messaging);\n    } on Object {\n      // Le notifiche non devono impedire l’uso di presenze e rapportini.\n      instance = null;\n    }\n  }\n\n  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;\n\n  Stream<RemoteMessage> get openedMessages =>\n      FirebaseMessaging.onMessageOpenedApp;\n\n  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();\n\n  Future<void> activateForUser(String employeeId) async {\n    final permission = await _messaging.requestPermission(\n      alert: true,\n      badge: true,\n      sound: true,\n    );\n\n    if (permission.authorizationStatus == AuthorizationStatus.denied) {\n      return;\n    }\n\n    if (Platform.isIOS) {\n      await _waitForApnsToken();\n    }\n\n    final token = await _messaging.getToken();\n    if (token != null && token.isNotEmpty) {\n      await _register(employeeId, token);\n    }\n\n    await _refreshSubscription?.cancel();\n    _refreshSubscription = _messaging.onTokenRefresh.listen(\n      (value) => _register(employeeId, value),\n    );\n  }\n\n  Future<void> _waitForApnsToken() async {\n    for (var attempt = 0; attempt < 10; attempt++) {\n      final token = await _messaging.getAPNSToken();\n      if (token != null && token.isNotEmpty) return;\n      await Future<void>.delayed(const Duration(milliseconds: 500));\n    }\n  }\n\n  Future<void> _register(String employeeId, String token) async {\n    await Supabase.instance.client.from('dispositivi_push').upsert({\n      'dipendente_id': employeeId,\n      'token': token,\n      'piattaforma': Platform.isIOS ? 'ios' : 'android',\n      'nome_dispositivo': Platform.operatingSystem,\n      'attivo': true,\n      'ultimo_accesso_at': DateTime.now().toUtc().toIso8601String(),\n    }, onConflict: 'token');\n  }\n}\n"
CONFIGURE_PLATFORMS = '#!/usr/bin/env python3\n"""Applica in modo idempotente permessi, nomi e identificativi Flutter."""\n\nfrom pathlib import Path\nimport os\nimport plistlib\nimport re\nimport sys\nimport xml.etree.ElementTree as ET\n\n\nANDROID_NS = "http://schemas.android.com/apk/res/android"\nET.register_namespace("android", ANDROID_NS)\n\n\ndef configure_android(root: Path) -> None:\n    manifest = root / "android" / "app" / "src" / "main" / "AndroidManifest.xml"\n    if not manifest.exists():\n        raise FileNotFoundError(f"Manifest Android non trovato: {manifest}")\n\n    tree = ET.parse(manifest)\n    node = tree.getroot()\n\n    existing = {\n        item.attrib.get(f"{{{ANDROID_NS}}}name")\n        for item in node.findall("uses-permission")\n    }\n\n    permissions = [\n        "android.permission.INTERNET",\n        "android.permission.CAMERA",\n        "android.permission.ACCESS_COARSE_LOCATION",\n        "android.permission.ACCESS_FINE_LOCATION",\n        "android.permission.POST_NOTIFICATIONS",\n    ]\n\n    for permission in reversed(permissions):\n        if permission not in existing:\n            item = ET.Element("uses-permission")\n            item.set(f"{{{ANDROID_NS}}}name", permission)\n            node.insert(0, item)\n\n    if not any(\n        item.attrib.get(f"{{{ANDROID_NS}}}name") == "android.hardware.camera"\n        for item in node.findall("uses-feature")\n    ):\n        feature = ET.Element("uses-feature")\n        feature.set(f"{{{ANDROID_NS}}}name", "android.hardware.camera")\n        feature.set(f"{{{ANDROID_NS}}}required", "false")\n        node.insert(len(permissions), feature)\n\n    application = node.find("application")\n    if application is not None:\n        application.set(f"{{{ANDROID_NS}}}label", "Arte In Ferro Lascari")\n\n    tree.write(manifest, encoding="utf-8", xml_declaration=True)\n\n    gradle = root / "android" / "app" / "build.gradle.kts"\n    text = gradle.read_text(encoding="utf-8")\n    text = re.sub(\n        r\'applicationId\\s*=\\s*"[^"]+"\',\n        \'applicationId = "com.arteinferrolascari.myapp"\',\n        text,\n    )\n\n    marker = "android {"\n    if "import java.util.Properties" not in text:\n        text = "import java.util.Properties\\n\\n" + text\n\n    signing_loader = """val keystoreProperties = Properties()\nval keystorePropertiesFile = rootProject.file("key.properties")\nif (keystorePropertiesFile.exists()) {\n    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }\n}\n\n"""\n    if "val keystoreProperties =" not in text:\n        text = text.replace(marker, signing_loader + marker, 1)\n\n    build_types = "    buildTypes {"\n    signing_config = """    signingConfigs {\n        create("release") {\n            keyAlias = keystoreProperties["keyAlias"] as String?\n            keyPassword = keystoreProperties["keyPassword"] as String?\n            storeFile = keystoreProperties["storeFile"]?.let { file(it) }\n            storePassword = keystoreProperties["storePassword"] as String?\n        }\n    }\n\n"""\n    if \'create("release")\' not in text:\n        text = text.replace(build_types, signing_config + build_types, 1)\n\n    text = text.replace(\n        \'signingConfig = signingConfigs.getByName("debug")\',\n        \'signingConfig = signingConfigs.getByName("release")\',\n    )\n    gradle.write_text(text, encoding="utf-8")\n\n\ndef configure_ios(root: Path) -> None:\n    info = root / "ios" / "Runner" / "Info.plist"\n    project = root / "ios" / "Runner.xcodeproj" / "project.pbxproj"\n    if not info.exists():\n        raise FileNotFoundError(f"Info.plist iOS non trovato: {info}")\n    if not project.exists():\n        raise FileNotFoundError(f"Progetto iOS non trovato: {project}")\n\n    bundle_id = os.environ.get(\n        "IOS_BUNDLE_ID",\n        "it.arteinferrolascari.rapportini",\n    ).strip()\n\n    with info.open("rb") as stream:\n        values = plistlib.load(stream)\n\n    values["CFBundleDisplayName"] = "Arte In Ferro Lascari"\n    values["NSCameraUsageDescription"] = (\n        "La fotocamera serve per documentare il lavoro svolto in cantiere."\n    )\n    values["NSPhotoLibraryUsageDescription"] = (\n        "L’accesso alle foto serve per allegare immagini ai rapportini."\n    )\n    values["NSPhotoLibraryAddUsageDescription"] = (\n        "L’app può salvare sul dispositivo i documenti prodotti."\n    )\n    values["NSLocationWhenInUseUsageDescription"] = (\n        "La posizione viene registrata soltanto quando salvi una presenza, "\n        "un rapportino o un’altra operazione aziendale che richiede il GPS."\n    )\n    background_modes = list(values.get("UIBackgroundModes", []))\n    if "remote-notification" not in background_modes:\n        background_modes.append("remote-notification")\n    values["UIBackgroundModes"] = background_modes\n    values["ITSAppUsesNonExemptEncryption"] = False\n\n    with info.open("wb") as stream:\n        plistlib.dump(values, stream, sort_keys=False)\n\n    lines = project.read_text(encoding="utf-8").splitlines()\n    result = []\n    for line in lines:\n        match = re.match(r"(\\s*)PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", line)\n        if not match:\n            result.append(line)\n            continue\n        indent, old_id = match.groups()\n        new_id = f"{bundle_id}.RunnerTests" if "RunnerTests" in old_id else bundle_id\n        result.append(f"{indent}PRODUCT_BUNDLE_IDENTIFIER = {new_id};")\n\n    project.write_text("\\n".join(result) + "\\n", encoding="utf-8")\n\n\ndef main() -> None:\n    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()\n    configure_android(root)\n    configure_ios(root)\n    print("Configurazione Android/iOS applicata.")\n\n\nif __name__ == "__main__":\n    main()\n'


def is_repo(path: Path) -> bool:
    return (
        (path / ".git").exists()
        and (path / "apps/mobile/pubspec.yaml").exists()
        and (path / "tools/bootstrap_mobile.sh").exists()
    )


def find_repo() -> Path:
    script_dir = Path(__file__).resolve().parent
    candidates: list[Path] = []
    for start in (Path.cwd(), script_dir):
        current = start.resolve()
        candidates.append(current)
        candidates.extend(current.parents)

    home = Path.home()
    candidates.extend(
        [
            home / "Documents" / "GitHub" / REPO_NAME,
            home / "GitHub" / REPO_NAME,
            home / "Desktop" / REPO_NAME,
            home / "source" / "repos" / REPO_NAME,
        ]
    )

    seen: set[Path] = set()
    for candidate in candidates:
        candidate = candidate.resolve()
        if candidate in seen:
            continue
        seen.add(candidate)
        if is_repo(candidate):
            return candidate

    raise RuntimeError(
        "Repository non trovato. Apri GitHub Desktop sul progetto "
        "'rapportini-arte-in-ferro' e riprova."
    )


def run_git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.replace("\r\n", "\n"), encoding="utf-8", newline="\n")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(
            f"Impossibile aggiornare {label}: modello atteso trovato {count} volte."
        )
    return text.replace(old, new, 1)


def backup_files(repo: Path, paths: list[Path]) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = Path.home() / "Desktop" / f"Backup-Mobile-ArteInFerro-{timestamp}"
    for path in paths:
        if not path.exists():
            continue
        relative = path.relative_to(repo)
        destination = backup / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
    return backup


def main() -> int:
    try:
        repo = find_repo()
        branch = run_git(repo, "rev-parse", "--abbrev-ref", "HEAD")
        if branch != EXPECTED_BRANCH:
            raise RuntimeError(
                f"Ramo non corretto: '{branch}'. Seleziona "
                f"'{EXPECTED_BRANCH}' in GitHub Desktop."
            )

        status = run_git(repo, "status", "--porcelain")
        if status:
            raise RuntimeError(
                "Ci sono modifiche locali non salvate. Torna in GitHub Desktop, "
                "annullale oppure crea prima un commit."
            )

        pubspec = repo / "apps/mobile/pubspec.yaml"
        app_config_path = repo / "apps/mobile/lib/core/config/app_config.dart"
        push_path = repo / "apps/mobile/lib/core/notifications/push_notification_service.dart"
        configure_path = repo / "tools/configure_mobile_platforms.py"
        offline_repo_path = repo / (
            "apps/mobile/lib/features/rapportini/data/repositories/"
            "offline_rapportini_repository.dart"
        )
        cubit_path = repo / (
            "apps/mobile/lib/features/rapportini/presentation/cubit/"
            "rapportini_cubit.dart"
        )
        page_path = repo / (
            "apps/mobile/lib/features/rapportini/presentation/pages/"
            "rapportini_page.dart"
        )
        workflow_path = repo / ".github/workflows/build-mobile-integrato.yml"

        files = [
            pubspec,
            app_config_path,
            push_path,
            configure_path,
            offline_repo_path,
            cubit_path,
            page_path,
            workflow_path,
        ]
        backup = backup_files(repo, files)

        pubspec_text = pubspec.read_text(encoding="utf-8")
        pubspec_text, replacements = re.subn(
            r"(?m)^version:\s*[^\n]+$",
            "version: 0.7.0+8",
            pubspec_text,
            count=1,
        )
        if replacements != 1:
            raise RuntimeError("Versione mobile non trovata in pubspec.yaml.")
        write_text(pubspec, pubspec_text)

        write_text(app_config_path, APP_CONFIG)
        write_text(push_path, PUSH_SERVICE)
        write_text(configure_path, CONFIGURE_PLATFORMS)
        write_text(workflow_path, WORKFLOW)

        offline = offline_repo_path.read_text(encoding="utf-8")
        offline = replace_once(
            offline,
            """  Future<SyncResult> sync(String dipendenteId) async {
    try {
""",
            """  Future<SyncResult> sync(String dipendenteId) async {
    if (!await _hasConnection()) {
      return const SyncResult(synced: 0, failed: 0, offline: true);
    }

    try {
""",
            "controllo connessione",
        )
        write_text(offline_repo_path, offline)

        cubit = cubit_path.read_text(encoding="utf-8")
        cubit = replace_once(
            cubit,
            "  Future<void> sync() async {",
            "  Future<void> sync({bool silent = false}) async {",
            "sincronizzazione silenziosa",
        )
        cubit = replace_once(
            cubit,
            "      emit(state.copyWith(isSyncing: false, message: message));",
            """      emit(state.copyWith(
        isSyncing: false,
        message: silent ? null : message,
        clearMessage: silent,
      ));""",
            "messaggio sincronizzazione",
        )
        write_text(cubit_path, cubit)

        page = page_path.read_text(encoding="utf-8")
        page = replace_once(
            page,
            "import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';",
            """import 'dart:async';

import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';""",
            "import timer",
        )
        page = replace_once(
            page,
            "class _RapportiniViewState extends State<_RapportiniView> {",
            """class _RapportiniViewState extends State<_RapportiniView>
    with WidgetsBindingObserver {""",
            "osservatore ciclo vita",
        )
        old_init = """  StatoRapportino? _filter;
  bool _openedInitialForm = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialReportId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<RapportiniCubit>().sync();
      });
    }
  }
"""
        new_init = """  StatoRapportino? _filter;
  bool _openedInitialForm = false;
  Timer? _automaticSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RapportiniCubit>().sync(silent: true);
      }
    });
    _automaticSyncTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) {
        if (mounted) {
          context.read<RapportiniCubit>().sync(silent: true);
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<RapportiniCubit>().sync(silent: true);
    }
  }

  @override
  void dispose() {
    _automaticSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
"""
        page = replace_once(page, old_init, new_init, "sincronizzazione automatica")
        write_text(page_path, page)

        print()
        print("RICOSTRUZIONE MOBILE FASE 1 APPLICATA.")
        print("Creati: APK, AAB, build iOS nativa e IPA opzionale firmata.")
        print("Aggiunta sincronizzazione automatica con il gestionale Windows.")
        print(f"Backup locale: {backup}")
        print()
        print("Torna su GitHub Desktop e crea il commit.")
        return 0
    except Exception as exc:
        print()
        print(f"ERRORE: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
