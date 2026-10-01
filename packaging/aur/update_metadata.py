#!/usr/bin/env python3
"""Update the AUR recipe version and pinned upstream commit."""

import re
import sys
from pathlib import Path


if len(sys.argv) != 3:
    raise SystemExit("usage: update_metadata.py PKGVER COMMIT")

pkgver, commit = sys.argv[1:]
if not re.fullmatch(r"[0-9][A-Za-z0-9.]*", pkgver):
    raise SystemExit(f"invalid Arch package version: {pkgver}")
if not re.fullmatch(r"[0-9a-f]{40}", commit):
    raise SystemExit("commit must be a full lowercase Git SHA")

package_dir = Path(__file__).parent / "windblog-admin"
recipe_path = package_dir / "PKGBUILD"
srcinfo_path = package_dir / ".SRCINFO"
recipe = recipe_path.read_text()
srcinfo = srcinfo_path.read_text()

recipe, version_count = re.subn(r"(?m)^pkgver=.*$", f"pkgver={pkgver}", recipe)
recipe, commit_count = re.subn(r"(?<=#commit=)[0-9a-f]{40}", commit, recipe)
srcinfo, srcinfo_version_count = re.subn(
    r"(?m)^\tpkgver = .*?$", f"\tpkgver = {pkgver}", srcinfo
)
srcinfo, srcinfo_commit_count = re.subn(
    r"(?<=#commit=)[0-9a-f]{40}", commit, srcinfo
)

if (version_count, commit_count, srcinfo_version_count, srcinfo_commit_count) != (
    1,
    1,
    1,
    1,
):
    raise SystemExit("unexpected PKGBUILD/.SRCINFO format; no files written")

recipe_path.write_text(recipe)
srcinfo_path.write_text(srcinfo)
