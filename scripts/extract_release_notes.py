#!/usr/bin/env python3
"""Print the changelog section matching a release tag, without its heading."""

import argparse
from pathlib import Path
import re


_FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
_HEADING = re.compile(r"^ {0,3}##(?:[ \t]+(.*))?$")
_VERSION = re.compile(r"^\[([^\]]+)\](?:[ \t].*)?$")


def extract_release_notes(changelog: str, tag: str) -> str:
    if not tag.startswith("v") or len(tag) == 1:
        raise ValueError("Release tag must start with v, for example v0.5.1.")
    version = tag[1:]
    lines = changelog.splitlines()
    sections = []
    start = None
    fence = None

    for index, line in enumerate(lines):
        marker = _FENCE.match(line)
        if fence is not None:
            if (
                marker
                and marker[1][0] == fence[0]
                and len(marker[1]) >= fence[1]
                and not marker[2].strip()
            ):
                fence = None
            continue
        if marker:
            fence = (marker[1][0], len(marker[1]))
            continue

        heading = _HEADING.match(line)
        if heading is None:
            continue
        if start is not None:
            sections.append((start, index))
            start = None
        label = _VERSION.match(heading[1] or "")
        if label and label[1] == version:
            start = index + 1

    if start is not None:
        sections.append((start, len(lines)))
    if not sections:
        raise ValueError(f"Missing changelog section: ## [{version}]")
    if len(sections) != 1:
        raise ValueError(f"Duplicate changelog section: ## [{version}]")

    start, end = sections[0]
    while start < end and not lines[start].strip():
        start += 1
    while end > start and not lines[end - 1].strip():
        end -= 1
    if start == end:
        raise ValueError(f"Empty changelog section: ## [{version}]")
    return "\n".join(lines[start:end]) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag", help="Release tag, for example v0.5.1")
    parser.add_argument(
        "--changelog",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "CHANGELOG.md",
        help="Changelog file (default: repository CHANGELOG.md)",
    )
    args = parser.parse_args()
    try:
        notes = extract_release_notes(args.changelog.read_text(encoding="utf-8"), args.tag)
    except (OSError, UnicodeError, ValueError) as error:
        parser.error(str(error))
    print(notes, end="")


if __name__ == "__main__":
    main()
