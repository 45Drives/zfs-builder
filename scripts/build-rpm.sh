#!/bin/bash
# Build OpenZFS RPM packages for EL9
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
echo "OpenZFS RPM Builder for EL9"
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

# Generate custom spec file with 45Drives changelog
echo "[3/5] Generating custom RPM spec file..."
if [[ -f "rpm/generic/zfs.spec.in" ]]; then
    # Copy and process the spec file
    cp "rpm/generic/zfs.spec.in" "zfs.spec"
    
    # Basic variable substitution for spec file
    sed -i "s|@VERSION@|${VERSION}|g" "zfs.spec"
    sed -i "s|@RELEASE@|1|g" "zfs.spec"
    
    # Replace %changelog section with custom entry
    # Find the %changelog marker and replace everything after it
    if grep -q "%changelog" "zfs.spec"; then
        # Create a temp file with new changelog
        CHANGELOG_SECTION=$(/bin/bash /usr/local/bin/generate-changelog rpm "$VERSION")
        
        # Split file at %changelog and replace
        sed -i '/^%changelog/,$d' "zfs.spec"
        echo "%changelog" >> "zfs.spec"
        echo "$CHANGELOG_SECTION" >> "zfs.spec"
    fi
    echo "✓ Spec file prepared"
else
    echo "Error: spec file not found at rpm/generic/zfs.spec.in"
    exit 1
fi

# Run autoconf/configure
echo "[4/5] Configuring build..."
if [[ ! -f "configure" ]]; then
    autoreconf -i || true
fi

# Build RPM packages
echo "[5/5] Building RPM packages..."
if ! rpmbuild -ba zfs.spec \
    --define "_topdir $(pwd)/rpmbuild" \
    --define "_sourcedir $(pwd)" \
    --define "dist .el9" \
    2>&1 | tee build.log; then
    echo "Error: RPM build failed. See build.log for details."
    exit 1
fi

# Copy built RPMs to output directory
echo ""
echo "========================================="
if [[ -d "rpmbuild/RPMS" ]]; then
    find "rpmbuild/RPMS" -name "*.rpm" -exec cp {} "$OUTPUT_DIR/" \;
    echo "✓ Build completed successfully!"
    echo "✓ Packages saved to: $OUTPUT_DIR"
    ls -lh "$OUTPUT_DIR"/*.rpm
else
    echo "Warning: RPMS directory not found, checking alternative locations..."
    if find . -name "*.rpm" -type f; then
        find . -name "*.rpm" -type f -exec cp {} "$OUTPUT_DIR/" \;
        echo "✓ Packages copied to: $OUTPUT_DIR"
    else
        echo "Error: No RPM packages found after build"
        exit 1
    fi
fi

echo "========================================="
echo "RPM build complete!"
