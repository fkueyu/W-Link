"""Verify built Apple bundle metadata against the application version source."""
import argparse
import plistlib
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("bundle", type=Path)
parser.add_argument("--ios", action="store_true")
args = parser.parse_args()
match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", Path("pubspec.yaml").read_text(), re.M)
if not match:
    raise SystemExit("Invalid pubspec application version")
version, build = match.groups()
plist_path = args.bundle / ("Info.plist" if args.ios else "Contents/Info.plist")
info = plistlib.loads(plist_path.read_bytes())
if info.get("CFBundleShortVersionString") != version or info.get("CFBundleVersion") != build:
    raise SystemExit("Built bundle version does not match pubspec.yaml")
if args.ios and set(info.get("UIDeviceFamily", [])) != {1, 2}:
    raise SystemExit("The iOS archive must support both iPhone and iPad")
print(f"Verified {args.bundle.name}: {version} ({build})")
if args.ios:
    print("Verified device families: iPhone and iPad")
