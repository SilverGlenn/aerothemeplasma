#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Run the real patch helper against disposable companion repositories."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "scripts/apply-aeroglassblur-patch.sh"
PATCH = ROOT / "patches/aeroshell-kwin-components/0001-register-background-damage.patch"
FILES = ["effects_cpp/wayland/kde-effects-aeroglassblur/src/blur.cpp",
         "effects_cpp/wayland/kde-effects-aeroglassblur/src/blur.h"]
SOURCE_ROOT = None


class PatchApplication(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="aero-blur-patch-")
        self.addCleanup(self.directory.cleanup)
        self.repo = Path(self.directory.name) / "companion with spaces"
        self.repo.mkdir()
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        for name in FILES:
            target = self.repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(SOURCE_ROOT / name, target)
        # Normalize only the disposable fixture, whether the caller's checkout
        # has the patch committed, applied but uncommitted, or not yet applied.
        reverse = ["git", "-C", str(self.repo), "apply", "--reverse"]
        if subprocess.run([*reverse, "--check", str(PATCH)], capture_output=True).returncode == 0:
            subprocess.run([*reverse, str(PATCH)], check=True)
        self.original = {name: (self.repo / name).read_bytes() for name in FILES}
        (self.repo / "CMakeLists.txt").write_text("# Preserve local compatibility adjustment: WaylandProtocols 1.47\n")

    def apply(self, path=None):
        return subprocess.run(["bash", str(HELPER), str(path or self.repo)],
                              capture_output=True, text=True)

    def snapshot(self):
        return {name: (self.repo / name).read_bytes() for name in [*FILES, "CMakeLists.txt"]}

    def test_fresh_application_and_repeat_preserve_unrelated_changes(self):
        unrelated = (self.repo / "CMakeLists.txt").read_bytes()
        first = self.apply()
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        patched = self.snapshot()
        for name in FILES:
            self.assertNotEqual(patched[name], self.original[name])
        self.assertEqual(patched["CMakeLists.txt"], unrelated)
        second = self.apply()
        self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
        self.assertEqual(self.snapshot(), patched, "repeat application must not change files again")

    def test_incompatible_source_fails_without_partial_modification(self):
        (self.repo / FILES[1]).write_text("// incompatible upstream header\n")
        before = self.snapshot()
        result = self.apply()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.snapshot(), before)

    def test_partially_applied_source_is_rejected_atomically(self):
        first = self.apply()
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        (self.repo / FILES[1]).write_bytes(self.original[FILES[1]])
        before = self.snapshot()
        result = self.apply()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.snapshot(), before)

    def test_requires_repository_root(self):
        before = self.snapshot()
        result = self.apply(self.repo / "effects_cpp")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.snapshot(), before)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_root", type=Path)
    args = parser.parse_args()
    SOURCE_ROOT = args.source_root.resolve()
    unittest.main(argv=[__file__], verbosity=2)
