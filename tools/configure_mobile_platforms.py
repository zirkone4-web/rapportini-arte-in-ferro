#!/usr/bin/env python3
"""Applica in modo idempotente permessi e nomi alle piattaforme Flutter generate."""

from pathlib import Path
import plistlib
import re
import sys
import xml.etree.ElementTree as ET


ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)


def configure_android(root: Path) -> None:
    manifest = root / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest.exists():
        raise FileNotFoundError(f"Manifest Android non trovato: {manifest}")
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
    ]
    for permission in reversed(permissions):
        if permission not in existing:
            item = ET.Element("uses-permission")
            item.set(f"{{{ANDROID_NS}}}name", permission)
            node.insert(0, item)
    if not any(
        item.attrib.get(f"{{{ANDROID_NS}}}name") == "android.hardware.camera"
        for item in node.findall("uses-feature")
    ):
        feature = ET.Element("uses-feature")
        feature.set(f"{{{ANDROID_NS}}}name", "android.hardware.camera")
        feature.set(f"{{{ANDROID_NS}}}required", "false")
        node.insert(len(permissions), feature)
    application = node.find("application")
    if application is not None:
        application.set(f"{{{ANDROID_NS}}}label", "Arte In Ferro Lascari")
    tree.write(manifest, encoding="utf-8", xml_declaration=True)

    gradle = root / "android" / "app" / "build.gradle.kts"
    text = gradle.read_text(encoding="utf-8")
    text = re.sub(
        r'applicationId\s*=\s*"[^"]+"',
        'applicationId = "it.arteinferrolascari.app"',
        text,
    )
    marker = "android {"
    signing_loader = """val keystoreProperties = java.util.Properties()
val keystorePropertiesFile = rootProject.file(\"key.properties\")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

"""
    if "val keystoreProperties =" not in text:
        text = text.replace(marker, signing_loader + marker, 1)
    build_types = "    buildTypes {"
    signing_config = """    signingConfigs {
        create(\"release\") {
            keyAlias = keystoreProperties[\"keyAlias\"] as String?
            keyPassword = keystoreProperties[\"keyPassword\"] as String?
            storeFile = keystoreProperties[\"storeFile\"]?.let { file(it) }
            storePassword = keystoreProperties[\"storePassword\"] as String?
        }
    }

"""
    if 'create("release")' not in text:
        text = text.replace(build_types, signing_config + build_types, 1)
    text = text.replace(
        "signingConfig = signingConfigs.getByName(\"debug\")",
        "signingConfig = signingConfigs.getByName(\"release\")",
    )
    gradle.write_text(text, encoding="utf-8")


def configure_ios(root: Path) -> None:
    info = root / "ios" / "Runner" / "Info.plist"
    if not info.exists():
        raise FileNotFoundError(f"Info.plist iOS non trovato: {info}")
    with info.open("rb") as stream:
        values = plistlib.load(stream)
    values["CFBundleDisplayName"] = "Arte In Ferro Lascari"
    values["NSCameraUsageDescription"] = (
        "La fotocamera serve per documentare il lavoro svolto in cantiere."
    )
    values["NSPhotoLibraryUsageDescription"] = (
        "L’accesso alle foto serve per allegare immagini ai rapportini."
    )
    values["NSLocationWhenInUseUsageDescription"] = (
        "La posizione viene registrata quando salvi un rapportino di lavoro."
    )
    with info.open("wb") as stream:
        plistlib.dump(values, stream, sort_keys=False)


def main() -> None:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    configure_android(root)
    configure_ios(root)
    print("Configurazione Android/iOS applicata.")


if __name__ == "__main__":
    main()
