#!/usr/bin/env python3
"""Structural smoke test; cannot replace iOS SDK typechecking on macOS."""
import hashlib
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
    result = subprocess.run(["swiftc", "-frontend", "-parse", *map(str, (output / "StreamPlay").glob("*.swift"))], capture_output=True, text=True)
    if result.returncode:
        print(result.stdout, result.stderr)
        raise SystemExit(result.returncode)
    subprocess.run(command, check=True)
    subprocess.run(command + ["--force"], check=True)
    print("PASS: project + CarPlay scene roles + all Swift sources + generator idempotence + --force")
