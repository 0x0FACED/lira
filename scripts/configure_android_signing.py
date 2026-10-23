#!/usr/bin/env python3
"""Restore Android release signing files from GitHub Actions secrets."""

import base64
import binascii
import os
from pathlib import Path
import sys


def property_value(value: str) -> str:
    """Encode a value for java.util.Properties.load(InputStream)."""
    escaped = []
    encoded = value.encode("utf-16-be")
    for index in range(0, len(encoded), 2):
        code = int.from_bytes(encoded[index : index + 2], "big")
        char = chr(code)
        if char in "\\ :=#!":
            escaped.append("\\" + char)
        elif 0x21 <= code <= 0x7E:
            escaped.append(char)
        else:
            escaped.append(f"\\u{code:04x}")
    return "".join(escaped)


def main() -> int:
    names = ("ANDROID_KEYSTORE", "KEY_STORE_PASSWORD", "KEY_PASSWORD", "KEY_ALIAS")
    missing = [name for name in names if not os.environ.get(name)]
    if missing:
        print("Missing signing secrets: " + ", ".join(missing), file=sys.stderr)
        return 1

    try:
        keystore = base64.b64decode(
            "".join(os.environ["ANDROID_KEYSTORE"].split()), validate=True
        )
    except (binascii.Error, ValueError):
        print("ANDROID_KEYSTORE must contain a base64-encoded keystore.", file=sys.stderr)
        return 1
    if not keystore:
        print("ANDROID_KEYSTORE decoded to an empty file.", file=sys.stderr)
        return 1

    android = Path(__file__).resolve().parent.parent / "android"
    keystore_path = android / "ci-release-key.jks"
    properties_path = android / "key.properties"
    if any(path.exists() or path.is_symlink() for path in (keystore_path, properties_path)):
        print("Refusing to overwrite existing Android signing files.", file=sys.stderr)
        return 1

    properties = {
        "storeFile": str(keystore_path),
        "storePassword": os.environ["KEY_STORE_PASSWORD"],
        "keyPassword": os.environ["KEY_PASSWORD"],
        "keyAlias": os.environ["KEY_ALIAS"],
    }
    contents = "".join(
        f"{key}={property_value(value)}\n" for key, value in properties.items()
    ).encode("ascii")

    created = []
    try:
        for path, data in ((keystore_path, keystore), (properties_path, contents)):
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            created.append(path)
            with os.fdopen(fd, "wb") as output:
                output.write(data)
    except OSError:
        for path in created:
            path.unlink(missing_ok=True)
        print("Could not create Android signing files.", file=sys.stderr)
        return 1

    print("Android release signing configured.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
