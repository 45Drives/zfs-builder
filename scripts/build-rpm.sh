#!/bin/bash
# Build OpenZFS RPM packages for Rocky Linux / EL systems
# Usage: build-rpm.sh <version> [output-dir]

set -e

VERSION="${1:-}"
OUTPUT_DIR="${2:-/tmp/zfs-build/output/el9}"

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
echo "OpenZFS RPM Builder"
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

# Run autogen
echo "[3/5] Configuring build..."
echo "Running autogen.sh..."
if ! bash autogen.sh 2>&1 | tail -20; then
    echo "Error: autogen.sh failed"
    exit 1
fi

echo "Running configure..."
if ! ./configure 2>&1 | tail -20; then
    echo "Error: configure failed"
    exit 1
fi

# Build RPM packages
echo "[4/5] Building RPM packages..."
# Use 'make rpm' (standard OpenZFS method)
SPEC_FILE="$BUILD_DIR/zfs.spec"

if ! make rpm 2>&1 | tee build.log; then
    echo "Error: RPM build failed with 'make rpm'. See build.log for details."
    exit 1
fi

# Find and copy generated RPMs (search more thoroughly)
echo "[5/5] Verifying and copying RPMs..."
echo "Searching for generated RPM files..."
if find . -name "*.rpm" -type f 2>/dev/null | grep -q .; then
    echo "Found RPM files, copying to output directory..."
    find . -name "*.rpm" -type f -exec cp {} "$OUTPUT_DIR/" \;
    echo "✓ RPMs copied successfully"
else
    echo "Warning: No RPM files found after 'make rpm'. Checking rpmbuild directory..."
    if [[ -d "rpmbuild/RPMS" ]]; then
        find "rpmbuild/RPMS" -name "*.rpm" -exec cp {} "$OUTPUT_DIR/" \;
        echo "✓ RPMs found and copied from rpmbuild directory"
    fi
fi

# Copy built RPMs to output directory
echo ""
echo "========================================="
cd /tmp/zfs-build
echo "Checking for RPM packages in output directory: $OUTPUT_DIR"
if find "$OUTPUT_DIR" -name "*.rpm" -type f 2>/dev/null | grep -q .; then
    echo "✓ Build completed successfully!"
    echo "✓ Packages saved to: $OUTPUT_DIR"
    ls -lh "$OUTPUT_DIR"/*.rpm
else
    echo "Error: No RPM packages found in $OUTPUT_DIR"
    echo "Debug info - checking for any .rpm files in build directory:"
    find . -name "*.rpm" -type f 2>/dev/null || echo "No .rpm files found in current build directory"
    exit 1
fi

echo "========================================="
echo "RPM build complete!"
