#!/bin/bash
# Build OpenZFS RPM packages (utils + DKMS) inside an EL build container.
# Usage: build-rpm.sh <version> <source-tarball> <output-dir>
#
# Packages are built unmodified from the upstream release tarball, so names and
# versions match the official OpenZFS EL packages (zfs, zfs-dkms, libzfs*, ...).

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

echo "========================================="
echo "OpenZFS RPM Builder (EL$(rpm -E '%{rhel}'))"
echo "========================================="
echo "Version: $VERSION"
echo ""

echo "[1/4] Extracting source..."
tar xzf "$TARBALL" -C "$WORK_DIR"
cd "$BUILD_DIR"

echo "[2/4] Configuring..."
# Release tarballs ship a generated configure script; only run autogen if not.
[[ -x ./configure ]] || bash autogen.sh
# rpmbuild re-runs the real configure itself, so the top-level configure only
# needs to produce the packaging Makefile and spec files.
./configure --with-config=srpm

echo "[3/4] Building RPM packages (utils + DKMS)..."
# Upstream documents these targets as non-parallel at the top level; the
# compile itself is parallelised by rpmbuild.
make -j1 rpm-utils rpm-dkms

echo "[4/4] Collecting RPM packages..."
find . -maxdepth 1 -name "*.rpm" ! -name "*.src.rpm" -type f -exec cp -t "$OUTPUT_DIR" {} +

if ! compgen -G "$OUTPUT_DIR/*.rpm" > /dev/null; then
    echo "Error: no RPM packages were produced" >&2
    exit 1
fi

echo ""
ls -lh "$OUTPUT_DIR"/*.rpm
echo "RPM build complete"
