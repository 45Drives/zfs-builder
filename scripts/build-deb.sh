#!/bin/bash
# Build OpenZFS DEB packages (utils + DKMS) inside an Ubuntu build container.
# Usage: build-deb.sh <version> <source-tarball> <output-dir>
#
# The source is built unmodified from the upstream release tarball using the
# upstream native Debian packaging. Only the packaging metadata is adjusted so
# the packages carry Ubuntu's names (zfsutils-linux, zfs-dkms, libzfs7linux, ...)
# and a version tagged with the Ubuntu codename (e.g. 2.4.1-1jammy), making them
# a drop-in upgrade for the distribution's own ZFS packages.

set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <version> <source-tarball> <output-dir>" >&2
    exit 1
fi

VERSION="${1#zfs-}"
TARBALL="$2"
OUTPUT_DIR="$3"
WORK_DIR="/tmp/zfs-build"
BUILD_DIR="$WORK_DIR/zfs-$VERSION"

[[ -f "$TARBALL" ]] || { echo "Error: source tarball not found: $TARBALL" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR" "$WORK_DIR"

# Read in a subshell: os-release defines its own VERSION variable.
UBUNTU_RELEASE="$(. /etc/os-release && echo "$VERSION_ID")"
UBUNTU_CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
[[ -n "$UBUNTU_CODENAME" ]] || { echo "Error: could not determine the Ubuntu codename" >&2; exit 1; }
echo "========================================="
echo "OpenZFS DEB Builder (Ubuntu $UBUNTU_RELEASE $UBUNTU_CODENAME)"
echo "========================================="
echo "Version: $VERSION"
echo ""

echo "[1/5] Extracting source..."
tar xzf "$TARBALL" -C "$WORK_DIR"
cd "$BUILD_DIR"

echo "[2/5] Configuring..."
# Release tarballs ship a generated configure script; only run autogen if not.
[[ -x ./configure ]] || bash autogen.sh
./configure

echo "[3/5] Applying Ubuntu package names..."
# Must run after configure (which generates the packaging files) and before
# make copies contrib/debian to debian/.
/usr/local/bin/ubuntu-package-names contrib/debian "$UBUNTU_CODENAME"

echo "[4/5] Building DEB packages (utils + DKMS)..."
# native-deb-utils also produces zfs-dkms.
make -j1 native-deb-utils

# The upstream make target does not propagate a dpkg-buildpackage failure, so
# check for the .changes file, which is only written when the build succeeds.
if ! compgen -G "$WORK_DIR/*.changes" > /dev/null; then
    echo "Error: dpkg-buildpackage did not complete (no .changes file)" >&2
    exit 1
fi

echo "[5/5] Collecting DEB packages..."
# The dracut package is not used on Ubuntu (initramfs-tools).
rm -f "$WORK_DIR"/zfs-dracut_*.deb

# Every package must carry the Ubuntu codename in its version and must not
# still use an upstream openzfs-* name.
bad=0
for deb in "$WORK_DIR"/*.deb; do
    name="$(basename "$deb")"
    if [[ "$name" != *"_${VERSION}-"*"${UBUNTU_CODENAME}_"* || "$name" == openzfs-* ]]; then
        echo "Error: unexpected package file name: $name" >&2
        bad=1
    fi
done
(( bad == 0 )) || exit 1
find "$WORK_DIR" -maxdepth 1 -name "*.deb" -type f -exec cp -t "$OUTPUT_DIR" {} +

if ! compgen -G "$OUTPUT_DIR/*.deb" > /dev/null; then
    echo "Error: no DEB packages were produced" >&2
    exit 1
fi

echo ""
ls -lh "$OUTPUT_DIR"/*.deb
echo "DEB build complete"
