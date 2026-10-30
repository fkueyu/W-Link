import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("verify_apple_bundle.py").resolve()

class BundleVerificationTest(unittest.TestCase):
    def verify(self, version="3.0.0", build="15", families=(1, 2)):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "pubspec.yaml").write_text("version: 3.0.0+15\n")
            app = root / "Runner.app"
            app.mkdir()
            (app / "Info.plist").write_bytes(plistlib.dumps({
                "CFBundleShortVersionString": version,
                "CFBundleVersion": build,
                "UIDeviceFamily": list(families),
            }))
            return subprocess.run(
                [sys.executable, str(SCRIPT), str(app), "--ios"],
                cwd=root, text=True, capture_output=True,
            )

    def test_current_version_with_iphone_and_ipad_is_accepted(self):
        result = self.verify()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_wrong_marketing_version_is_rejected(self):
        self.assertNotEqual(self.verify(version="2.4.7").returncode, 0)

    def test_wrong_build_number_is_rejected(self):
        self.assertNotEqual(self.verify(build="14").returncode, 0)

    def test_iphone_only_archive_is_rejected(self):
        self.assertNotEqual(self.verify(families=(1,)).returncode, 0)

    def verify_mac(self, permissions):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "pubspec.yaml").write_text("version: 3.0.0+15\n")
            app = root / "W-Link.app"
            (app / "Contents").mkdir(parents=True)
            info = {"CFBundleShortVersionString": "3.0.0", "CFBundleVersion": "15"}
            info.update(permissions)
            (app / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
            return subprocess.run(
                [sys.executable, str(SCRIPT), str(app)],
                cwd=root, text=True, capture_output=True,
            )

    def test_mac_missing_privacy_declarations_is_rejected(self):
        self.assertNotEqual(self.verify_mac({}).returncode, 0)

    def test_mac_declared_wled_access_is_accepted(self):
        result = self.verify_mac({
            "NSLocalNetworkUsageDescription": "Discover and control WLED lights.",
            "NSBonjourServices": ["_wled._tcp"],
        })
        self.assertEqual(result.returncode, 0, result.stderr)

if __name__ == "__main__":
    unittest.main()
