#!/usr/bin/env python3
"""Build Flop Siege's local project record, including its generated concept art."""
import pathlib
import runpy
import subprocess
import sys

PROJECT = pathlib.Path(__file__).resolve().parents[2]
GALLERIES = ["art/concept"]
builder = runpy.run_path(str(pathlib.Path.home() / ".local/bin/docs-build"))
builder["PICTURE_DIRS"].extend(GALLERIES)
builder["build"](PROJECT)
if "--publish" in sys.argv:
    subprocess.run([str(pathlib.Path.home() / ".local/bin/docs-site"), "publish"], check=True)
