#!/usr/bin/env python3
"""Structural smoke test; cannot replace iOS SDK typechecking on macOS."""
import hashlib
import shutil
import plistlib
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SWIFT = [p.name for p in (HERE / "StreamPlay").glob("*.swift")]

with tempfile.TemporaryDirectory(prefix="streamplay-v4-smoke-") as temp:
    output = Path(temp) / "StreamPlay"
    command = [sys.executable, str(HERE / "gen_xcodeproj.py"), "--output", str(output)]
    subprocess.run(command, check=True)
    plist = plistlib.loads((output / "StreamPlay" / "Info.plist").read_bytes())
    assert "UIWindowSceneSessionRoleCarPlay" in plist["UIApplicationSceneManifest"]["UISceneConfigurations"]
    assert "CPTemplateApplicationSceneSessionRoleApplication" in plist["UIApplicationSceneManifest"]["UISceneConfigurations"]
    pbx = (output / "StreamPlay.xcodeproj" / "project.pbxproj").read_text()
    for name in SWIFT:
        assert name in pbx, name
        expected = (HERE / "StreamPlay" / name).read_bytes()
        received = (output / "StreamPlay" / name).read_bytes()
        assert hashlib.sha256(expected).digest() == hashlib.sha256(received).digest(), name
    for name in (".github/workflows/build-ipa.yml", "scripts/build-unsigned-ipa.sh", "README.md"):
        assert (output / name).exists()
    ui = (output / "StreamPlay" / "ContentView.swift").read_text()
    model = (output / "StreamPlay" / "ChannelViewModel.swift").read_text()
    assert "Reproduzidos recentemente" in ui
    assert "Qualidade da reprodução" in ui
    assert "Vídeo · codec da fonte" in ui
    assert "private func inspectCodec" in model
    assert "playbackFailure" in model and "newErrorLogEntryNotification" in model
    assert "usesExternalPlaybackWhileExternalScreenIsActive = false" in model
    assert "Copiar diagnóstico" in ui and "Tentar canal novamente" in ui
    assert "MP4 de teste" in (output / "StreamPlay" / "ChannelService.swift").read_text()
    assert (output / "DIAGNOSTICO_IPTV.md").exists()
    assert "preferredPeakBitRate" in model
    browser_source = (output / "StreamPlay" / "BrowserStore.swift").read_text()
    assert "let firstTab = BrowserTab()" in browser_source
    assert "self.tabs = [firstTab]" in browser_source
    assert "self.activeTabID = firstTab.id" in browser_source
    assert ("init() {" + chr(10) + "        activeTabID = tabs[0].id") not in browser_source
    swiftc = shutil.which("swiftc")
    if swiftc:
        result = subprocess.run([swiftc, "-frontend", "-parse", *map(str, (output / "StreamPlay").glob("*.swift"))], capture_output=True, text=True)
        if result.returncode:
            print(result.stdout, result.stderr)
            raise SystemExit(result.returncode)
    else:
        print("SKIP: swiftc indisponível; parse Swift dependerá do Xcode no GitHub Actions")
    subprocess.run(command, check=True)
    subprocess.run(command + ["--force"], check=True)
    print("PASS: v4.3 player diagnostics + retry + public test streams + preserved v4.2 features + bootstrap")
