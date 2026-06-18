#!/usr/bin/env python3
"""Patch a Rojo project.json for Weave installation."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


def load_project(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def save_project(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def ensure_packages(data: dict) -> bool:
    tree = data.setdefault("tree", {})
    rs = tree.setdefault("ReplicatedStorage", {"$className": "ReplicatedStorage"})
    if "Packages" in rs:
        return False
    rs["Packages"] = {"$path": "Packages"}
    return True


def ensure_weave_mount(data: dict, weave_path: str) -> bool:
    tree = data.setdefault("tree", {})
    rs = tree.setdefault("ReplicatedStorage", {"$className": "ReplicatedStorage"})
    rel = weave_path.replace("\\", "/")
    if rs.get("Weave") == {"$path": rel}:
        return False
    rs["Weave"] = {"$path": rel}
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project", type=Path)
    parser.add_argument("--packages", action="store_true")
    parser.add_argument("--weave-src", type=Path, default=None)
    args = parser.parse_args()

    data = load_project(args.project)
    changed = False

    if args.packages and ensure_packages(data):
        print(f"Added ReplicatedStorage.Packages in {args.project.name}")
        changed = True

    if args.weave_src is not None:
        rel = os.path.relpath(
            args.weave_src.resolve(),
            args.project.parent.resolve(),
        )
        if ensure_weave_mount(data, rel):
            print(f"Mounted ReplicatedStorage.Weave -> {rel.replace(os.sep, '/')}")
            changed = True

    if changed:
        save_project(args.project, data)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
