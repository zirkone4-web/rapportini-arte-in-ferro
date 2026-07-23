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
        "Lâ€™accesso alle foto serve per allegare immagini ai rapportini."
    )
    values["NSPhotoLibraryAddUsageDescription"] = (
        "Lâ€™app puÃ² salvare sul dispositivo i documenti prodotti."
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
