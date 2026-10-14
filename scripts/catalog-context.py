#!/usr/bin/env python3
"""Print every catalog key with what a translator needs to translate it well:
its English (each plural form), its comment, and where in the source the build
found it. Run after a build, so the .stringsdata files exist.

Usage:
    python3 scripts/catalog-context.py              # every key
    python3 scripts/catalog-context.py --missing de # only keys translations/de.json lacks
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from catalog_format import CATALOG_PATH, REPO_ROOT

# sync-catalog.py has a hyphen in its name, so load it by path for its build finder.
spec = importlib.util.spec_from_file_location("sync_catalog", HERE / "sync-catalog.py")
sync_catalog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync_catalog)


def locations() -> dict[str, list[str]]:
    found: dict[str, list[str]] = {}
    for path in sorted(sync_catalog.default_stringsdata_dir().glob("*.stringsdata")):
        data = json.loads(subprocess.run(["plutil", "-convert", "json", "-o", "-", str(path)],
                                         capture_output=True, text=True, check=True).stdout)
        source = data.get("source", path.stem)
        for entry in data.get("tables", {}).get("Localizable", []):
            line = entry.get("location", {}).get("startingLine")
            found.setdefault(entry["key"], []).append(f"{Path(source).name}:{line}")
    return found


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--missing", metavar="LANG", help="only keys translations/LANG.json lacks")
    args = parser.parse_args()

    strings = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))["strings"]
    skip: set[str] = set()
    if args.missing:
        path = REPO_ROOT / "translations" / f"{args.missing}.json"
        if path.exists():
            skip = set(json.loads(path.read_text(encoding="utf-8")))
    where = locations()

    for key in sorted(strings):
        if key in skip:
            continue
        entry = strings[key]
        english = entry["localizations"]["en"]
        print(json.dumps(key, ensure_ascii=False))
        if "variations" in english:
            for category, unit in english["variations"]["plural"].items():
                print(f"   {category}: {json.dumps(unit['stringUnit']['value'], ensure_ascii=False)}")
        else:
            value = english["stringUnit"]["value"]
            if value != key:
                print(f"   value: {json.dumps(value, ensure_ascii=False)}")
        if entry.get("comment"):
            print(f"   comment: {entry['comment']}")
        print(f"   source: {', '.join(where.get(key, ['(not found in this build)']))}")


if __name__ == "__main__":
    main()
