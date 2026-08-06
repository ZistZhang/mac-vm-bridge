#!/usr/bin/env python3
"""Patch freshly generated Flutter platform scaffolding for MinerU Flow."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_ID = "dev.zist.mineruflow"
APP_NAME = "MinerU Flow"


def replace(path: Path, old: str, new: str) -> None:
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")
    if old in text:
        path.write_text(text.replace(old, new), encoding="utf-8")


def patch_android() -> None:
    manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
    if not manifest.exists():
        return
    text = manifest.read_text(encoding="utf-8")
    if "android.permission.INTERNET" not in text:
        text = text.replace(
            "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">",
            "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">\n"
            "    <uses-permission android:name=\"android.permission.INTERNET\" />\n"
            "    <uses-permission android:name=\"android.permission.POST_NOTIFICATIONS\" />",
        )
    text = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', text, count=1)
    text = text.replace('android:launchMode="singleTop"', 'android:launchMode="singleTask"')
    text = text.replace(
        "</activity>",
        """            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="application/pdf" />
                <data android:mimeType="application/msword" />
                <data android:mimeType="application/vnd.openxmlformats-officedocument.wordprocessingml.document" />
                <data android:mimeType="application/vnd.ms-powerpoint" />
                <data android:mimeType="application/vnd.openxmlformats-officedocument.presentationml.presentation" />
                <data android:mimeType="application/vnd.ms-excel" />
                <data android:mimeType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" />
                <data android:mimeType="image/*" />
                <data android:mimeType="text/html" />
                <data android:mimeType="text/plain" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND_MULTIPLE" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="*/*" />
            </intent-filter>
        </activity>""",
        1,
    )
    manifest.write_text(text, encoding="utf-8")

    for gradle in [ROOT / "android/app/build.gradle.kts", ROOT / "android/app/build.gradle"]:
        if not gradle.exists():
            continue
        text = gradle.read_text(encoding="utf-8")
        text = re.sub(r'namespace\s*=\s*"[^"]+"', f'namespace = "{APP_ID}"', text)
        text = re.sub(r'applicationId\s*=\s*"[^"]+"', f'applicationId = "{APP_ID}"', text)
        text = re.sub(r'namespace\s+"[^"]+"', f'namespace "{APP_ID}"', text)
        text = re.sub(r'applicationId\s+"[^"]+"', f'applicationId "{APP_ID}"', text)
        gradle.write_text(text, encoding="utf-8")

    kotlin_root = ROOT / "android/app/src/main/kotlin"
    if kotlin_root.exists():
        for activity in kotlin_root.rglob("MainActivity.kt"):
            text = activity.read_text(encoding="utf-8")
            text = re.sub(r"^package\s+[^\n]+", f"package {APP_ID}", text, count=1, flags=re.MULTILINE)
            destination = kotlin_root.joinpath(*APP_ID.split("."), "MainActivity.kt")
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(text, encoding="utf-8")
            if activity.resolve() != destination.resolve():
                activity.unlink()
            break


def patch_macos() -> None:
    project = ROOT / "macos/Runner.xcodeproj/project.pbxproj"
    if project.exists():
        text = project.read_text(encoding="utf-8")
        text = text.replace("PRODUCT_BUNDLE_IDENTIFIER = dev.zist.mineruFlow;", f"PRODUCT_BUNDLE_IDENTIFIER = {APP_ID};")
        text = text.replace("PRODUCT_BUNDLE_IDENTIFIER = dev.zist.mineru_flow;", f"PRODUCT_BUNDLE_IDENTIFIER = {APP_ID};")
        text = text.replace("PRODUCT_NAME = mineru_flow;", f'PRODUCT_NAME = "{APP_NAME}";')
        project.write_text(text, encoding="utf-8")

    info = ROOT / "macos/Runner/Info.plist"
    if info.exists():
        text = info.read_text(encoding="utf-8")
        if "CFBundleDisplayName" not in text:
            text = text.replace(
                "<key>CFBundleName</key>",
                f"<key>CFBundleDisplayName</key>\n\t<string>{APP_NAME}</string>\n\t<key>CFBundleName</key>",
            )
        info.write_text(text, encoding="utf-8")

    for name in ["DebugProfile.entitlements", "Release.entitlements"]:
        path = ROOT / "macos/Runner" / name
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        additions = []
        if "com.apple.security.network.client" not in text:
            additions.append("\t<key>com.apple.security.network.client</key>\n\t<true/>")
        if "com.apple.security.files.user-selected.read-write" not in text:
            additions.append("\t<key>com.apple.security.files.user-selected.read-write</key>\n\t<true/>")
        if additions:
            text = text.replace("</dict>", "\n".join(additions) + "\n</dict>")
        path.write_text(text, encoding="utf-8")


def patch_windows() -> None:
    rc = ROOT / "windows/runner/Runner.rc"
    if rc.exists():
        text = rc.read_text(encoding="utf-8")
        text = text.replace('VALUE "FileDescription", "mineru_flow"', f'VALUE "FileDescription", "{APP_NAME}"')
        text = text.replace('VALUE "InternalName", "mineru_flow"', 'VALUE "InternalName", "MinerUFlow"')
        text = text.replace('VALUE "OriginalFilename", "mineru_flow.exe"', 'VALUE "OriginalFilename", "MinerUFlow.exe"')
        text = text.replace('VALUE "ProductName", "mineru_flow"', f'VALUE "ProductName", "{APP_NAME}"')
        rc.write_text(text, encoding="utf-8")

    cmake = ROOT / "windows/CMakeLists.txt"
    if cmake.exists():
        text = cmake.read_text(encoding="utf-8")
        text = text.replace('set(BINARY_NAME "mineru_flow")', 'set(BINARY_NAME "MinerUFlow")')
        cmake.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    patch_android()
    patch_macos()
    patch_windows()
    print("Platform scaffolding patched for MinerU Flow")
