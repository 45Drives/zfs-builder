#!/bin/bash
# Build OpenZFS DEB packages for Ubuntu 22.04
# Usage: build-deb.sh <version> [output-dir]

set -e

VERSION="${1:-}"
OUTPUT_DIR="${2:-/tmp/zfs-build/output/ubuntu22}"

if [[ -z "$VERSION" ]]; then
    echo "Error: Version argument required"
    echo "Usage: $0 <version> [output-dir]"
    echo "Example: $0 2.4.1"
    exit 1
fi

# Normalize version (remove 'zfs-' prefix if present)
VERSION="${VERSION#zfs-}"

# Validate version format (basic semver check)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-.+)?$ ]]; then
    echo "Error: Invalid version format '$VERSION'. Expected semver (e.g., 2.4.1)"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
BUILD_DIR="/tmp/zfs-build/zfs-$VERSION"
TARBALL_URL="https://github.com/openzfs/zfs/releases/download/zfs-${VERSION}/zfs-${VERSION}.tar.gz"

echo "========================================="
echo "OpenZFS DEB Builder for Ubuntu 22.04"
echo "========================================="
echo "Version: $VERSION"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Download tarball
echo "[1/5] Downloading OpenZFS source tarball..."
cd /tmp/zfs-build
if ! wget -q "$TARBALL_URL" -O "zfs-${VERSION}.tar.gz"; then
    echo "Error: Failed to download tarball from $TARBALL_URL"
    exit 1
fi
echo "✓ Downloaded successfully"

# Extract tarball
echo "[2/5] Extracting source..."
tar xzf "zfs-${VERSION}.tar.gz"
cd "$BUILD_DIR"
echo "✓ Extracted to $BUILD_DIR"

# Generate custom debian/changelog with 45Drives entry
echo "[3/5] Preparing Debian packaging..."
if [[ ! -d "contrib/debian" ]]; then
    echo "Error: debian directory not found at contrib/debian"
    exit 1
fi
echo "✓ Debian packaging ready"

# Run autoconf/configure
echo "[4/5] Configuring build..."
if [[ ! -f "configure" ]]; then
    autoreconf -i || true
fi

./configure 2>&1 | tail -20

# Build DEB packages
echo "[5/5] Building DEB packages..."
# Use 'make native-deb' (standard OpenZFS method for native DEBs)
if ! make native-deb 2>&1 | tee build.log; then
    echo "Error: DEB build failed. See build.log for details."
    exit 1
fi

# Copy built DEBs to output directory
echo ""
echo "========================================="
cd /tmp/zfs-build
echo "Searching for DEB packages..."
if find . -name "*.deb" -type f 2>/dev/null | grep -q .; then
    echo "Found DEB files, copying to output directory..."
    find . -name "*.deb" -type f -exec cp {} "$OUTPUT_DIR/" \;
    echo "✓ DEBs copied successfully"
fi

echo "Checking for DEB packages in output directory: $OUTPUT_DIR"
if find "$OUTPUT_DIR" -name "*.deb" -type f 2>/dev/null | grep -q .; then
    echo "✓ Build completed successfully!"
    echo "✓ Packages saved to: $OUTPUT_DIR"
    ls -lh "$OUTPUT_DIR"/*.deb
else
    echo "Error: No DEB packages found in $OUTPUT_DIR"
    echo "Debug info - checking for any .deb files in build directory:"
    find . -name "*.deb" -type f 2>/dev/null || echo "No .deb files found in build directory"
    exit 1
fi

echo "========================================="
echo "DEB build complete!"
