"""Prepare Flutter.framework in the archive products directory before SwiftPM scans."""
import argparse
import json
import shutil
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--flutter", default=shutil.which("flutter"))
args = parser.parse_args()
if not args.flutter:
    raise SystemExit("Flutter SDK is not on PATH")
subprocess.run([
    args.flutter, "build", "ios", "--release", "--config-only",
    "--no-codesign", "--no-pub",
], check=True)
settings = json.loads(subprocess.check_output([
    "xcodebuild", "-workspace", "ios/Runner.xcworkspace", "-scheme", "Runner",
    "-configuration", "Release", "-sdk", "iphoneos", "-destination", "generic/platform=iOS",
    "-archivePath", "build/ios/archive/Runner", "CODE_SIGNING_ALLOWED=NO",
    "archive", "-showBuildSettings", "-json",
], text=True))
build = next(item["buildSettings"] for item in settings if item.get("target") == "Runner")
products = Path(build["BUILT_PRODUCTS_DIR"])
subprocess.run([
    args.flutter, "assemble", "--no-version-check", f"--output={products}",
    "-dTargetPlatform=ios", "-dBuildMode=release", f"-dSdkRoot={build['SDKROOT']}",
    f"-dIosArchs={build['ARCHS']}", "-dAction=install", "release_unpack_ios",
], check=True)
modulemap = products / "Flutter.framework/Modules/module.modulemap"
if not modulemap.is_file():
    raise SystemExit("Flutter framework module is missing after preparation")
print(f"Prepared Flutter module for archive: {modulemap}")
