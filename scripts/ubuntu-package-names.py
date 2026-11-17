#!/usr/bin/env python3
"""Rename the upstream OpenZFS Debian packages to Ubuntu's package names.

Upstream's native Debian packaging (contrib/debian) names its packages
openzfs-* (openzfs-zfsutils, openzfs-libzfs7, ...). Ubuntu ships the same
software as zfsutils-linux, libzfs7linux, zfs-dkms, and so on. This script
rewrites the packaging metadata so the built packages carry Ubuntu's names and
a version tagged with the Ubuntu codename (e.g. 2.4.1-1jammy), making them a
drop-in upgrade for the distribution's packages. No source code is changed.

Usage: ubuntu-package-names.py <debian-packaging-dir> <ubuntu-codename>

Run it on contrib/debian after ./configure and before `make native-deb-utils`.
"""

import re
import sys
from pathlib import Path

# Names that are not binary packages in debian/control but are renamed too.
SOURCE_NAME = ("openzfs-linux", "zfs-linux")
EXTRA_NAMES = {"openzfs-zfs-modules": "zfs-modules", "openzfs-zfs": "zfs"}

RELATION_FIELDS = ("Breaks", "Replaces", "Conflicts")


def ubuntu_name(name):
    """Map an upstream package name to the Ubuntu name."""
    match = re.fullmatch(r"openzfs-lib(nvpair|uutil|zfs|zpool|zfsbootenv)(\d+)", name)
    if match:
        return f"lib{match.group(1)}{match.group(2)}linux"
    if name == "openzfs-libzfs-dev":
        return "libzfslinux-dev"
    if name == "openzfs-zfsutils":
        return "zfsutils-linux"
    if name.startswith("openzfs-"):
        return name[len("openzfs-"):]
    raise ValueError(f"unexpected package name: {name}")


def build_renamer(names):
    """Return a function replacing every known upstream name in a string."""
    # Longest first so e.g. openzfs-libzfs-dev is not shadowed by a prefix.
    alternatives = "|".join(re.escape(n) for n in sorted(names, key=len, reverse=True))
    pattern = re.compile(rf"(?<![A-Za-z0-9+.-])({alternatives})(?![a-z0-9+])")
    return lambda text: pattern.sub(lambda m: names[m.group(1)], text)


def split_fields(paragraph):
    """Split a control paragraph into [name, text] fields, keeping comments."""
    fields = []
    for line in paragraph.split("\n"):
        if line.startswith("#") or not fields or not line[:1].isspace():
            match = None if line.startswith("#") else re.match(r"([A-Za-z0-9-]+):", line)
            fields.append([match.group(1) if match else None, line])
        else:
            fields[-1][1] += "\n" + line
    return fields


def fix_relations(paragraph, old_name):
    """Drop self-references created by the rename; conflict with the old name.

    Upstream's openzfs-foo declares Conflicts/Replaces on Ubuntu's foo. After
    renaming openzfs-foo to foo those point at the package itself, so remove
    them and instead conflict with / replace the upstream-named package.
    """
    new_name = None
    fields = split_fields(paragraph)
    for name, text in fields:
        if name == "Package":
            new_name = text.split(":", 1)[1].strip()
    if new_name is None:
        return paragraph

    seen = set()
    result = []
    for name, text in fields:
        if name in RELATION_FIELDS:
            entries = [e.strip() for e in text.split(":", 1)[1].split(",") if e.strip()]
            entries = [e for e in entries if e.split()[0] != new_name]
            if name in ("Replaces", "Conflicts"):
                entries.append(old_name)
                seen.add(name)
            if not entries:
                continue
            text = f"{name}: " + ",\n".join(
                entry if i == 0 else " " * (len(name) + 2) + entry
                for i, entry in enumerate(entries)
            )
        result.append((name, text))

    out = []
    for name, text in result:
        if name == "Description":
            # Fields a package did not declare at all go just before Description.
            for missing in ("Replaces", "Conflicts"):
                if missing not in seen:
                    out.append(f"{missing}: {old_name}")
        out.append(text)
    return "\n".join(out)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    debian_dir = Path(sys.argv[1])
    codename = sys.argv[2]
    control = debian_dir / "control"
    changelog = debian_dir / "changelog"
    for required in (control, changelog, debian_dir / "rules"):
        if not required.is_file():
            sys.exit(f"Error: {required} not found (run ./configure first)")
    if not re.fullmatch(r"[a-z]+", codename):
        sys.exit(f"Error: invalid Ubuntu codename: {codename!r}")

    packages = re.findall(r"^Package:\s*(\S+)", control.read_text(), flags=re.M)
    if not packages:
        sys.exit(f"Error: no packages found in {control}")
    names = {old: ubuntu_name(old) for old in packages}
    names.update(EXTRA_NAMES)
    names[SOURCE_NAME[0]] = SOURCE_NAME[1]
    if len(set(names.values())) != len(names):
        sys.exit("Error: package rename produced duplicate names")
    rename = build_renamer(names)

    # 1. Rename references inside every packaging file, then the files.
    for path in sorted(p for p in debian_dir.rglob("*") if p.is_file()):
        try:
            text = path.read_text()
        except UnicodeDecodeError:
            continue
        renamed = rename(text)
        if renamed != text:
            path.write_text(renamed)
    for path in sorted(p for p in debian_dir.iterdir() if p.is_file()):
        new_filename = rename(path.name)
        if new_filename != path.name:
            path.rename(path.with_name(new_filename))

    # 2. Fix up the package relationships in debian/control.
    paragraphs = control.read_text().rstrip("\n").split("\n\n")
    by_new_name = {new: old for old, new in names.items()}
    fixed = []
    for paragraph in paragraphs:
        match = re.search(r"^Package:\s*(\S+)", paragraph, flags=re.M)
        if match:
            paragraph = fix_relations(paragraph, by_new_name[match.group(1)])
        fixed.append(paragraph)
    control.write_text("\n\n".join(fixed) + "\n")

    # 3. Tag the package version and target distribution with the codename.
    lines = changelog.read_text().split("\n")
    match = re.fullmatch(r"(\S+) \(([^)]+)\) \S+; (.*)", lines[0])
    if not match:
        sys.exit(f"Error: unexpected changelog header: {lines[0]!r}")
    version = f"{match.group(2)}{codename}"
    lines[0] = f"{match.group(1)} ({version}) {codename}; {match.group(3)}"
    changelog.write_text("\n".join(lines))

    print(f"Package version: {version}")
    for old in packages:
        print(f"  {old} -> {names[old]}")


if __name__ == "__main__":
    main()
