#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Exercise real AeroGlassBlur region methods without needing a live compositor.

Window/protocol/scene-item boundaries are small doubles. This verifies the effect's
scene-registration contract, not KWin's damage algorithm or GPU rendering. The live
ChatGPT drag remains a required visual check.
"""
import argparse
import os
from pathlib import Path
import shlex
import subprocess
import tempfile


SOURCE = Path("effects_cpp/wayland/kde-effects-aeroglassblur/src")


def extract_block(source, declaration):
    """Copy a complete C++ declaration/body, keeping production behavior intact."""
    start = source.index(declaration)
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        if source[end] == "{":
            depth += 1
        elif source[end] == "}":
            depth -= 1
        end += 1
    if source[end:end + 1] == ";":
        end += 1
    return source[start:end]


def run(source_root):
    source = (source_root / SOURCE / "blur.cpp").read_text()
    header = (source_root / SOURCE / "blur.h").read_text()
    functions = "\n\n".join(extract_block(source, declaration) for declaration in (
        "bool BlurEffect::decorationSupportsBlurBehind(",
        "Region BlurEffect::decorationBlurRegion(",
        "Region BlurEffect::blurRegion(",
        "void BlurEffect::updateBlurRegion(",
    ))
    template = Path(__file__).with_name("scene-registration.cpp.in").read_text()
    program = template.replace("// @DATA@", extract_block(header, "struct BlurEffectData"))
    program = program.replace("// @FUNCTIONS@", functions)
    flags = shlex.split(subprocess.check_output(
        ["pkg-config", "--cflags", "--libs", "Qt6Gui", "Qt6Core"], text=True))
    with tempfile.TemporaryDirectory(prefix="aero-blur-regression-") as directory:
        cpp = Path(directory) / "test.cpp"
        executable = Path(directory) / "test"
        cpp.write_text(program)
        subprocess.run([os.environ.get("CXX", "c++"), "-std=c++20", "-fPIC", "-O0",
                        str(cpp), "-o", str(executable), *flags], check=True)
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
        return subprocess.run([str(executable)], env=env).returncode


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_root", type=Path, help="aeroshell-kwin-components checkout")
    args = parser.parse_args()
    raise SystemExit(run(args.source_root.resolve()))
