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
    
    # Variable substitution for spec file (replace all @ variables)
    sed -i "s|@VERSION@|${VERSION}|g" "zfs.spec"
    sed -i "s|@RELEASE@|1|g" "zfs.spec"
    sed -i "s|@PACKAGE@|zfs|g" "zfs.spec"
    sed -i "s|@CONFIG@|kernel|g" "zfs.spec"
    
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

# Configure with standard OpenZFS options
./configure --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --libdir=/usr/lib64 \
    --enable-systemd \
    --enable-pyzfs \
    --with-config=kernel \
    2>&1 | grep -E "^(configure|  |checking)" | tail -15

# Build RPM packages
echo "[5/5] Building RPM packages..."
# Try using 'make rpm' first (standard OpenZFS method), fall back to rpmbuild if needed
if [[ -f "Makefile" ]] && make -n rpm &>/dev/null 2>&1; then
    echo "Using standard OpenZFS 'make rpm' method..."
    if ! make rpm 2>&1 | tee build.log; then
        echo "Error: RPM build failed with 'make rpm'. See build.log for details."
        exit 1
    fi
    # Find and copy generated RPMs (search more thoroughly)
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
else
    echo "Using rpmbuild method..."
    # Generate custom spec file with 45Drives changelog
    if [[ -f "rpm/generic/zfs.spec.in" ]]; then
        cp "rpm/generic/zfs.spec.in" "zfs.spec"
        sed -i "s|@VERSION@|${VERSION}|g" "zfs.spec"
        sed -i "s|@RELEASE@|1|g" "zfs.spec"
        sed -i "s|@PACKAGE@|zfs|g" "zfs.spec"
        sed -i "s|@CONFIG@|kernel|g" "zfs.spec"
        
        if grep -q "%changelog" "zfs.spec"; then
            CHANGELOG_SECTION=$(/bin/bash /usr/local/bin/generate-changelog rpm "$VERSION")
            sed -i '/^%changelog/,$d' "zfs.spec"
            echo "%changelog" >> "zfs.spec"
            echo "$CHANGELOG_SECTION" >> "zfs.spec"
        fi
    fi
    
    if ! rpmbuild -ba zfs.spec \
        --define "_topdir $(pwd)/rpmbuild" \
        --define "_sourcedir $(pwd)" \
        2>&1 | tee build.log; then
        echo "Error: RPM build failed. See build.log for details."
        exit 1
    fi
    
    # Copy built RPMs
    if [[ -d "rpmbuild/RPMS" ]]; then
        find "rpmbuild/RPMS" -name "*.rpm" -exec cp {} "$OUTPUT_DIR/" \;
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
