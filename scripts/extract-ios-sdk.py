#!/usr/bin/env python3
"""Restore an iPhoneOS SDK ZIP, preserving Unix symlinks safely.

Python's ZipFile.extractall() extracts symbolic links as plain text files,
which makes Clang parse paths such as 'pthread/pthread.h' as C code.
"""
import os
import pathlib
import posixpath
import shutil
import stat
import sys
import zipfile


def extract(archive: pathlib.Path, destination: pathlib.Path) -> None:
    root = destination.resolve()
    root.mkdir(parents=True, exist_ok=True)
    links = []
    with zipfile.ZipFile(archive) as zf:
        entries = zf.infolist()
        if len(entries) > 100_000 or sum(x.file_size for x in entries) > 1_000_000_000:
            raise ValueError("SDK ZIP exceeds safe size limits")
        seen = set()
        for entry in entries:
            name = entry.filename
            normalized = pathlib.PurePosixPath(name)
            if (not name or normalized.is_absolute() or ".." in normalized.parts
                    or not normalized.parts or normalized.parts[0] != "iPhoneOS.sdk"
                    or "\\" in name or ":" in name):
                raise ValueError("Unsafe SDK ZIP entry: " + name)
            relative = str(normalized).rstrip("/")
            if relative in seen:
                raise ValueError("Duplicate SDK ZIP entry: " + name)
            seen.add(relative)
            mode = entry.external_attr >> 16
            if stat.S_ISLNK(mode):
                target = zf.read(entry).decode("utf-8")
                if not target or target.startswith("/") or "\\" in target:
                    raise ValueError("Unsafe SDK symlink: " + name)
                dest = posixpath.normpath(posixpath.join(posixpath.dirname(relative), target))
                if not (dest == "iPhoneOS.sdk" or dest.startswith("iPhoneOS.sdk/")):
                    raise ValueError("Escaping SDK symlink: " + name)
                links.append((relative, target))
            elif not entry.is_dir():
                if stat.S_IFMT(mode) not in (0, stat.S_IFREG):
                    raise ValueError("Unexpected SDK entry type: " + name)
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                with zf.open(entry) as src, path.open("xb") as dst:
                    shutil.copyfileobj(src, dst)
            else:
                (root / relative).mkdir(parents=True, exist_ok=True)
        for relative, target in links:
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            os.symlink(target, path)
    for relative, _ in links:
        path = root / relative
        if not path.exists():
            raise ValueError("Broken SDK symlink: " + relative)
        if not path.resolve().is_relative_to(root):
            raise ValueError("SDK symlink resolves outside destination: " + relative)
    print(f"Extracted SDK with {len(links)} preserved symbolic links")
    for relative in ("iPhoneOS.sdk/usr/include/pthread.h", "iPhoneOS.sdk/usr/lib/libobjc.tbd"):
        path = root / relative
        if not path.is_symlink():
            raise ValueError("Expected SDK symlink missing: " + relative)
        print(f"Verified SDK link: {relative} -> {os.readlink(path)}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: extract-ios-sdk.py <private-sdk.zip> <destination-directory>")
    try:
        extract(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]))
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        sys.exit(str(exc))
