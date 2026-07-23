$ErrorActionPreference = "Stop"

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content.Replace("`r`n", "`n"), $utf8)
}

function Find-Repo {
    $name = "rapportini-arte-in-ferro"
    $candidates = New-Object System.Collections.Generic.List[string]
    $candidates.Add($PSScriptRoot)
    $candidates.Add((Get-Location).Path)

    foreach ($start in @($PSScriptRoot, (Get-Location).Path)) {
        $current = Get-Item $start
        while ($null -ne $current) {
            $candidates.Add($current.FullName)
            $current = $current.Parent
        }
    }

    $candidates.Add((Join-Path $HOME "Documents\GitHub\$name"))
    $candidates.Add((Join-Path $HOME "GitHub\$name"))
    $candidates.Add((Join-Path $HOME "Desktop\$name"))
    $candidates.Add((Join-Path $HOME "source\repos\$name"))

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if ((Test-Path (Join-Path $candidate ".git")) -and
            (Test-Path (Join-Path $candidate "apps\mobile\pubspec.yaml"))) {
            return (Resolve-Path $candidate).Path
        }
    }
    throw "Repository rapportini-arte-in-ferro non trovato."
}

function Replace-Once([string]$Text, [string]$Old, [string]$New, [string]$Label) {
    $count = ([regex]::Matches($Text, [regex]::Escape($Old))).Count
    if ($count -ne 1) {
        throw "Impossibile aggiornare ${Label}: modello trovato $count volte."
    }
    return $Text.Replace($Old, $New)
}

$workflow = @'
name: Build mobile integrato

on:
  workflow_dispatch:
  push:
    branches:
      - ricostruzione-mobile-integrata
      - main
    paths:
      - "apps/mobile/**"
      - "tools/bootstrap_mobile.sh"
      - "tools/configure_mobile_platforms.py"
      - ".github/workflows/build-mobile-integrato.yml"

permissions:
  contents: read

concurrency:
  group: mobile-integrato-${{ github.ref }}
  cancel-in-progress: true

jobs:
  qualita:
    name: Analisi e test Flutter
    runs-on: ubuntu-latest
    timeout-minutes: 25
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - name: Genera piattaforme Android e iOS
        run: bash tools/bootstrap_mobile.sh
      - name: Analisi statica
        working-directory: apps/mobile
        run: flutter analyze --no-fatal-infos
      - name: Test automatici
        working-directory: apps/mobile
        run: flutter test

  android:
    name: APK e AAB Android
    needs: qualita
    runs-on: ubuntu-latest
    timeout-minutes: 35
    defaults:
      run:
        working-directory: apps/mobile
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - name: Genera piattaforme e permessi
        working-directory: .
        run: bash tools/bootstrap_mobile.sh
      - name: Configura firma Android
        env:
          KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          test -n "$KEYSTORE_BASE64"
          test -n "$KEYSTORE_PASSWORD"
          test -n "$KEY_ALIAS"
          test -n "$KEY_PASSWORD"
          python3 - <<'PY'
          import base64, os, pathlib, string
          raw = os.environ["KEYSTORE_BASE64"].strip()
          is_hex = len(raw) % 2 == 0 and all(c in string.hexdigits for c in raw)
          data = bytes.fromhex(raw) if is_hex else base64.b64decode(raw)
          pathlib.Path("android/app/arte-in-ferro-upload.jks").write_bytes(data)
          PY
          printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=%s\nstoreFile=arte-in-ferro-upload.jks\n' \
            "$KEYSTORE_PASSWORD" "$KEY_PASSWORD" "$KEY_ALIAS" > android/key.properties
      - name: Prepara configurazione Android
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_PUBLISHABLE_KEY: ${{ secrets.SUPABASE_PUBLISHABLE_KEY }}
          FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_PROJECT_ID }}
          FIREBASE_API_KEY: ${{ secrets.FIREBASE_API_KEY }}
          FIREBASE_MESSAGING_SENDER_ID: ${{ secrets.FIREBASE_MESSAGING_SENDER_ID }}
          FIREBASE_ANDROID_APP_ID: ${{ secrets.FIREBASE_ANDROID_APP_ID }}
          FIREBASE_APP_ID: ${{ secrets.FIREBASE_APP_ID }}
        run: |
          python3 - <<'PY'
          import json, os, pathlib
          keys = (
              "SUPABASE_URL",
              "SUPABASE_PUBLISHABLE_KEY",
              "FIREBASE_PROJECT_ID",
              "FIREBASE_API_KEY",
              "FIREBASE_MESSAGING_SENDER_ID",
              "FIREBASE_ANDROID_APP_ID",
              "FIREBASE_APP_ID",
          )
          values = {key: os.environ[key] for key in keys if os.environ.get(key)}
          pathlib.Path("build-defines.json").write_text(
              json.dumps(values), encoding="utf-8"
          )
          PY
      - name: Crea APK release
        run: flutter build apk --release --dart-define-from-file=build-defines.json
      - name: Crea AAB Play Store
        run: flutter build appbundle --release --dart-define-from-file=build-defines.json
      - uses: actions/upload-artifact@v4
        with:
          name: arte-in-ferro-android-apk
          path: apps/mobile/build/app/outputs/flutter-apk/app-release.apk
          if-no-files-found: error
          retention-days: 14
      - uses: actions/upload-artifact@v4
        with:
          name: arte-in-ferro-play-store-aab
          path: apps/mobile/build/app/outputs/bundle/release/app-release.aab
          if-no-files-found: error
          retention-days: 14

  ios:
    name: App iPhone nativa
    needs: qualita
    runs-on: macos-latest
    timeout-minutes: 50
    defaults:
      run:
        working-directory: apps/mobile
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - name: Genera piattaforme e permessi iOS
        working-directory: .
        env:
          IOS_BUNDLE_ID: ${{ secrets.IOS_BUNDLE_ID }}
        run: bash tools/bootstrap_mobile.sh
      - name: Prepara configurazione iPhone
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_PUBLISHABLE_KEY: ${{ secrets.SUPABASE_PUBLISHABLE_KEY }}
          FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_PROJECT_ID }}
          FIREBASE_API_KEY: ${{ secrets.FIREBASE_API_KEY }}
          FIREBASE_MESSAGING_SENDER_ID: ${{ secrets.FIREBASE_MESSAGING_SENDER_ID }}
          FIREBASE_IOS_APP_ID: ${{ secrets.FIREBASE_IOS_APP_ID }}
          FIREBASE_IOS_BUNDLE_ID: ${{ secrets.IOS_BUNDLE_ID }}
          FIREBASE_APP_ID: ${{ secrets.FIREBASE_APP_ID }}
        run: |
          python3 - <<'PY'
          import json, os, pathlib
          keys = (
              "SUPABASE_URL",
              "SUPABASE_PUBLISHABLE_KEY",
              "FIREBASE_PROJECT_ID",
              "FIREBASE_API_KEY",
              "FIREBASE_MESSAGING_SENDER_ID",
              "FIREBASE_IOS_APP_ID",
              "FIREBASE_IOS_BUNDLE_ID",
              "FIREBASE_APP_ID",
          )
          values = {key: os.environ[key] for key in keys if os.environ.get(key)}
          pathlib.Path("build-defines.json").write_text(
              json.dumps(values), encoding="utf-8"
          )
          PY
      - name: Compila iOS senza firma
        run: flutter build ios --release --no-codesign --dart-define-from-file=build-defines.json
      - name: Prepara pacchetto di verifica
        run: ditto -c -k --sequesterRsrc --keepParent build/ios/iphoneos/Runner.app ArteInFerro-iOS-verifica.zip
      - uses: actions/upload-artifact@v4
        with:
          name: arte-in-ferro-ios-verifica
          path: apps/mobile/ArteInFerro-iOS-verifica.zip
          if-no-files-found: error
          retention-days: 14

'@
$appConfig = @'
import 'dart:io';

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.firebaseProjectId = '',
    this.firebaseApiKey = '',
    this.firebaseSenderId = '',
    this.firebaseAndroidAppId = '',
    this.firebaseIosAppId = '',
    this.firebaseIosBundleId = 'it.arteinferrolascari.rapportini',
  });

  factory AppConfig.fromEnvironment() {
    const configuredUrl = String.fromEnvironment('SUPABASE_URL');
    const configuredPublishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    );
    final url = configuredUrl.isEmpty
        ? 'https://oibibghbgcdjyimkvere.supabase.co'
        : configuredUrl;
    final publishableKey = configuredPublishableKey.isEmpty
        ? 'sb_publishable_a2pl_IOhqK3c7_gHUBnnmw_MoKaoptI'
        : configuredPublishableKey;

    const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const firebaseSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    );
    const legacyFirebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
    const configuredAndroidAppId = String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
    );
    const configuredIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
    const configuredIosBundleId = String.fromEnvironment(
      'FIREBASE_IOS_BUNDLE_ID',
    );

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const AppConfigurationException(
        'SUPABASE_URL non è un indirizzo valido.',
      );
    }

    return AppConfig(
      supabaseUrl: url,
      supabasePublishableKey: publishableKey,
      firebaseProjectId: firebaseProjectId,
      firebaseApiKey: firebaseApiKey,
      firebaseSenderId: firebaseSenderId,
      firebaseAndroidAppId: configuredAndroidAppId.isEmpty
          ? legacyFirebaseAppId
          : configuredAndroidAppId,
      firebaseIosAppId:
          configuredIosAppId.isEmpty ? legacyFirebaseAppId : configuredIosAppId,
      firebaseIosBundleId: configuredIosBundleId.isEmpty
          ? 'it.arteinferrolascari.rapportini'
          : configuredIosBundleId,
    );
  }

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String firebaseProjectId;
  final String firebaseApiKey;
  final String firebaseSenderId;
  final String firebaseAndroidAppId;
  final String firebaseIosAppId;
  final String firebaseIosBundleId;

  String get firebaseAppId =>
      Platform.isIOS ? firebaseIosAppId : firebaseAndroidAppId;

  bool get firebaseEnabled =>
      firebaseProjectId.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseApiKey.isNotEmpty &&
      firebaseSenderId.isNotEmpty;
}

class AppConfigurationException implements Exception {
  const AppConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

'@
$pushService = @'
import 'dart:async';
import 'dart:io';

import 'package:arte_in_ferro_rapportini/core/config/app_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService._(this._messaging);

  final FirebaseMessaging _messaging;
  static PushNotificationService? instance;
  StreamSubscription<String>? _refreshSubscription;

  static Future<void> initialize(AppConfig config) async {
    if (!config.firebaseEnabled) return;

    try {
      if (Firebase.apps.isEmpty) {
        final options = Platform.isIOS
            ? FirebaseOptions(
                apiKey: config.firebaseApiKey,
                appId: config.firebaseAppId,
                messagingSenderId: config.firebaseSenderId,
                projectId: config.firebaseProjectId,
                iosBundleId: config.firebaseIosBundleId,
              )
            : FirebaseOptions(
                apiKey: config.firebaseApiKey,
                appId: config.firebaseAppId,
                messagingSenderId: config.firebaseSenderId,
                projectId: config.firebaseProjectId,
              );

        await Firebase.initializeApp(options: options);
      }

      final messaging = FirebaseMessaging.instance;
      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      instance = PushNotificationService._(messaging);
    } on Object {
      instance = null;
    }
  }

  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp;

  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  Future<void> activateForUser(String employeeId) async {
    final permission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (permission.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    if (Platform.isIOS) {
      await _waitForApnsToken();
    }

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _register(employeeId, token);
    }

    await _refreshSubscription?.cancel();
    _refreshSubscription = _messaging.onTokenRefresh.listen(
      (value) => _register(employeeId, value),
    );
  }

  Future<void> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      final token = await _messaging.getAPNSToken();
      if (token != null && token.isNotEmpty) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _register(String employeeId, String token) async {
    await Supabase.instance.client.from('dispositivi_push').upsert({
      'dipendente_id': employeeId,
      'token': token,
      'piattaforma': Platform.isIOS ? 'ios' : 'android',
      'nome_dispositivo': Platform.operatingSystem,
      'attivo': true,
      'ultimo_accesso_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }
}

'@
$configurePlatforms = @'
#!/usr/bin/env python3
"""Configura Android e iOS in modo idempotente."""

from pathlib import Path
import os
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)

def configure_android(root: Path) -> None:
    manifest = root / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    tree = ET.parse(manifest)
    node = tree.getroot()
    existing = {
        item.attrib.get(f"{{{ANDROID_NS}}}name")
        for item in node.findall("uses-permission")
    }
    permissions = [
        "android.permission.INTERNET",
        "android.permission.CAMERA",
        "android.permission.ACCESS_COARSE_LOCATION",
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.POST_NOTIFICATIONS",
    ]
    for permission in reversed(permissions):
        if permission not in existing:
            item = ET.Element("uses-permission")
            item.set(f"{{{ANDROID_NS}}}name", permission)
            node.insert(0, item)
    application = node.find("application")
    if application is not None:
        application.set(f"{{{ANDROID_NS}}}label", "Arte In Ferro Lascari")
    tree.write(manifest, encoding="utf-8", xml_declaration=True)

    gradle = root / "android" / "app" / "build.gradle.kts"
    text = gradle.read_text(encoding="utf-8")
    text = re.sub(
        r'applicationId\s*=\s*"[^"]+"',
        'applicationId = "com.arteinferrolascari.myapp"',
        text,
    )
    if "import java.util.Properties" not in text:
        text = "import java.util.Properties\n\n" + text
    marker = "android {"
    loader = """val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

"""
    if "val keystoreProperties =" not in text:
        text = text.replace(marker, loader + marker, 1)
    build_types = "    buildTypes {"
    signing = """    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

"""
    if 'create("release")' not in text:
        text = text.replace(build_types, signing + build_types, 1)
    text = text.replace(
        'signingConfig = signingConfigs.getByName("debug")',
        'signingConfig = signingConfigs.getByName("release")',
    )
    gradle.write_text(text, encoding="utf-8")

def configure_ios(root: Path) -> None:
    info = root / "ios" / "Runner" / "Info.plist"
    project = root / "ios" / "Runner.xcodeproj" / "project.pbxproj"
    entitlements = root / "ios" / "Runner" / "Runner.entitlements"
    bundle_id = os.environ.get(
        "IOS_BUNDLE_ID",
        "it.arteinferrolascari.rapportini",
    ).strip()

    with info.open("rb") as stream:
        values = plistlib.load(stream)
    values["CFBundleDisplayName"] = "Arte In Ferro Lascari"
    values["NSCameraUsageDescription"] = (
        "La fotocamera serve per documentare il lavoro svolto in cantiere."
    )
    values["NSPhotoLibraryUsageDescription"] = (
        "L’accesso alle foto serve per allegare immagini ai rapportini."
    )
    values["NSPhotoLibraryAddUsageDescription"] = (
        "L’app può salvare sul dispositivo i documenti prodotti."
    )
    values["NSLocationWhenInUseUsageDescription"] = (
        "La posizione viene registrata soltanto durante operazioni aziendali."
    )
    modes = list(values.get("UIBackgroundModes", []))
    if "remote-notification" not in modes:
        modes.append("remote-notification")
    values["UIBackgroundModes"] = modes
    values["ITSAppUsesNonExemptEncryption"] = False
    with info.open("wb") as stream:
        plistlib.dump(values, stream, sort_keys=False)

    with entitlements.open("wb") as stream:
        plistlib.dump(
            {"aps-environment": "production"},
            stream,
            sort_keys=False,
        )

    lines = project.read_text(encoding="utf-8").splitlines()
    result = []
    for line in lines:
        match = re.match(r"(\s*)PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", line)
        if match:
            indent, old_id = match.groups()
            new_id = (
                f"{bundle_id}.RunnerTests"
                if "RunnerTests" in old_id
                else bundle_id
            )
            result.append(f"{indent}PRODUCT_BUNDLE_IDENTIFIER = {new_id};")
            if "RunnerTests" not in old_id:
                result.append(
                    f"{indent}CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;"
                )
        else:
            result.append(line)
    project.write_text("\n".join(result) + "\n", encoding="utf-8")

def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    configure_android(root)
    configure_ios(root)
    print("Configurazione Android/iOS applicata.")

if __name__ == "__main__":
    main()

'@

try {
    $repo = Find-Repo

    $gitMarker = Join-Path $repo ".git"
    if (Test-Path $gitMarker -PathType Container) {
        $headPath = Join-Path $gitMarker "HEAD"
    }
    elseif (Test-Path $gitMarker -PathType Leaf) {
        $gitLine = [System.IO.File]::ReadAllText($gitMarker).Trim()
        if (-not $gitLine.StartsWith("gitdir:")) {
            throw "Cartella Git non riconosciuta."
        }
        $gitDirectory = $gitLine.Substring(7).Trim()
        if (-not [System.IO.Path]::IsPathRooted($gitDirectory)) {
            $gitDirectory = Join-Path $repo $gitDirectory
        }
        $headPath = Join-Path $gitDirectory "HEAD"
    }
    else {
        throw "Cartella Git non trovata."
    }

    $head = [System.IO.File]::ReadAllText($headPath).Trim()
    if (-not $head.StartsWith("ref: refs/heads/")) {
        throw "Il progetto non si trova su un ramo Git normale."
    }
    $branch = $head.Substring("ref: refs/heads/".Length)
    if ($branch -ne "ricostruzione-mobile-integrata") {
        throw "Ramo non corretto: $branch. Seleziona ricostruzione-mobile-integrata in GitHub Desktop."
    }

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backup = Join-Path ([Environment]::GetFolderPath("Desktop")) "Backup-Mobile-ArteInFerro-$stamp"

    $paths = @(
        "apps\mobile\pubspec.yaml",
        "apps\mobile\lib\core\config\app_config.dart",
        "apps\mobile\lib\core\notifications\push_notification_service.dart",
        "tools\configure_mobile_platforms.py",
        "apps\mobile\lib\features\rapportini\data\repositories\offline_rapportini_repository.dart",
        "apps\mobile\lib\features\rapportini\presentation\cubit\rapportini_cubit.dart",
        "apps\mobile\lib\features\rapportini\presentation\pages\rapportini_page.dart"
    )

    foreach ($relative in $paths) {
        $source = Join-Path $repo $relative
        if (Test-Path $source) {
            $destination = Join-Path $backup $relative
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
            Copy-Item $source $destination -Force
        }
    }

    $pubspecPath = Join-Path $repo "apps\mobile\pubspec.yaml"
    $pubspec = [System.IO.File]::ReadAllText($pubspecPath).Replace("`r`n", "`n")
    $updated = [regex]::Replace($pubspec, "(?m)^version:\s*[^\n]+$", "version: 0.7.0+8", 1)
    if ($updated -eq $pubspec) { throw "Versione mobile non trovata in pubspec.yaml." }
    Write-Utf8NoBom $pubspecPath $updated

    Write-Utf8NoBom (Join-Path $repo "apps\mobile\lib\core\config\app_config.dart") $appConfig
    Write-Utf8NoBom (Join-Path $repo "apps\mobile\lib\core\notifications\push_notification_service.dart") $pushService
    Write-Utf8NoBom (Join-Path $repo "tools\configure_mobile_platforms.py") $configurePlatforms
    Write-Utf8NoBom (Join-Path $repo ".github\workflows\build-mobile-integrato.yml") $workflow

    $offlinePath = Join-Path $repo "apps\mobile\lib\features\rapportini\data\repositories\offline_rapportini_repository.dart"
    $offline = [System.IO.File]::ReadAllText($offlinePath).Replace("`r`n", "`n")
    $offlineOld = @'
  Future<SyncResult> sync(String dipendenteId) async {
    try {
'@
    $offlineNew = @'
  Future<SyncResult> sync(String dipendenteId) async {
    if (!await _hasConnection()) {
      return const SyncResult(synced: 0, failed: 0, offline: true);
    }

    try {
'@
    $offline = Replace-Once $offline $offlineOld $offlineNew "controllo connessione"
    Write-Utf8NoBom $offlinePath $offline

    $cubitPath = Join-Path $repo "apps\mobile\lib\features\rapportini\presentation\cubit\rapportini_cubit.dart"
    $cubit = [System.IO.File]::ReadAllText($cubitPath).Replace("`r`n", "`n")
    $cubit = Replace-Once $cubit "  Future<void> sync() async {" "  Future<void> sync({bool silent = false}) async {" "sincronizzazione silenziosa"
    $cubitOld = "      emit(state.copyWith(isSyncing: false, message: message));"
    $cubitNew = @'
      emit(state.copyWith(
        isSyncing: false,
        message: silent ? null : message,
        clearMessage: silent,
      ));
'@
    $cubit = Replace-Once $cubit $cubitOld $cubitNew "messaggio sincronizzazione"
    Write-Utf8NoBom $cubitPath $cubit

    $pagePath = Join-Path $repo "apps\mobile\lib\features\rapportini\presentation\pages\rapportini_page.dart"
    $page = [System.IO.File]::ReadAllText($pagePath).Replace("`r`n", "`n")
    $page = Replace-Once $page "import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';" "import 'dart:async';`n`nimport 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';" "import timer"
    $page = Replace-Once $page "class _RapportiniViewState extends State<_RapportiniView> {" "class _RapportiniViewState extends State<_RapportiniView>`n    with WidgetsBindingObserver {" "osservatore ciclo vita"

    $initOld = @'
  StatoRapportino? _filter;
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
'@
    $initNew = @'
  StatoRapportino? _filter;
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
'@
    $page = Replace-Once $page $initOld $initNew "sincronizzazione automatica"
    Write-Utf8NoBom $pagePath $page

    $originalReadme = @'
1. Put this entire folder inside the rapportini-arte-in-ferro project folder.
2. Run APPLICA_CORREZIONE_CODIFICA.cmd.
3. Wait for ENCODING CORRECTION COMPLETED.
4. Move this correction folder back out of the repository before committing.
'@
    Write-Utf8NoBom (Join-Path $repo "LEGGIMI.txt") $originalReadme

    foreach ($oldHelper in @(
        "APPLICA_RICOSTRUZIONE_MOBILE.cmd",
        "apply_mobile_rebuild.py"
    )) {
        $oldHelperPath = Join-Path $repo $oldHelper
        if (Test-Path $oldHelperPath) {
            Remove-Item $oldHelperPath -Force
        }
    }

    Write-Host ""
    Write-Host "RICOSTRUZIONE MOBILE FASE 1 APPLICATA." -ForegroundColor Green
    Write-Host "Preparati APK, AAB e compilazione iPhone nativa."
    Write-Host "Backup creato in: $backup"
    Write-Host ""
    exit 0
}
catch {
    Write-Host ""
    Write-Host ("ERRORE: " + $_.Exception.Message) -ForegroundColor Red
    Write-Host ""
    exit 1
}
