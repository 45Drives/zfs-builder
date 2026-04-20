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
    # Replace any remaining @ variables
    sed -i 's|@[A-Z_]*@||g' "zfs.spec"
    
    # Ensure %changelog section exists and is properly formatted
    if ! grep -q "%changelog" "zfs.spec"; then
        # Add changelog section if it doesn't exist
        echo "%changelog" >> "zfs.spec"
        echo "* $(date +'%a %b %d %Y') 45Drives <support@45drives.com> - ${VERSION}-1" >> "zfs.spec"
        echo "- OpenZFS ${VERSION} release" >> "zfs.spec"
    else
        # Replace the changelog section with our version
        sed -i '/^%changelog/,$d' "zfs.spec"
        echo "%changelog" >> "zfs.spec"
        echo "* $(date +'%a %b %d %Y') 45Drives <support@45drives.com> - ${VERSION}-1" >> "zfs.spec"
        echo "- OpenZFS ${VERSION} release" >> "zfs.spec"
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

./configure 2>&1 | tail -20

# Build RPM packages
echo "[5/5] Building RPM packages..."
# Try using 'make rpm' first (standard OpenZFS method), fall back to rpmbuild if needed
SPEC_FILE="$BUILD_DIR/zfs.spec"

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
    cd /tmp/zfs-build
    
    # Generate custom spec file with 45Drives changelog
    if [[ -f "rpm/generic/zfs.spec.in" ]]; then
        cp "rpm/generic/zfs.spec.in" "$SPEC_FILE"
        
        # Replace all known template variables
        sed -i "s|@VERSION@|${VERSION}|g" "$SPEC_FILE"
        sed -i "s|@RELEASE@|1|g" "$SPEC_FILE"
        sed -i "s|@PACKAGE@|zfs|g" "$SPEC_FILE"
        sed -i "s|@CONFIG@|kernel|g" "$SPEC_FILE"
        # Replace any remaining @ variables
        sed -i 's|@[A-Z_]*@||g' "$SPEC_FILE"
        
        # Ensure %changelog section exists and is properly formatted
        if ! grep -q "%changelog" "$SPEC_FILE"; then
            # Add changelog section if it doesn't exist
            echo "%changelog" >> "$SPEC_FILE"
            echo "* $(date +'%a %b %d %Y') 45Drives <support@45drives.com> - ${VERSION}-1" >> "$SPEC_FILE"
            echo "- OpenZFS ${VERSION} release" >> "$SPEC_FILE"
        else
            # Replace the changelog section with our version
            sed -i '/^%changelog/,$d' "$SPEC_FILE"
            echo "%changelog" >> "$SPEC_FILE"
            echo "* $(date +'%a %b %d %Y') 45Drives <support@45drives.com> - ${VERSION}-1" >> "$SPEC_FILE"
            echo "- OpenZFS ${VERSION} release" >> "$SPEC_FILE"
        fi
    fi
    
    # Set up rpmbuild directories
    RPMBUILD_DIR="/tmp/zfs-build/rpmbuild"
    mkdir -p "$RPMBUILD_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    
    # Copy tarball to SOURCES
    cp "zfs-${VERSION}.tar.gz" "$RPMBUILD_DIR/SOURCES/"
    
    # Copy spec file to SPECS
    cp "$SPEC_FILE" "$RPMBUILD_DIR/SPECS/"
    
    if ! rpmbuild -ba "$RPMBUILD_DIR/SPECS/zfs.spec" \
        --define "_topdir $RPMBUILD_DIR" \
        2>&1 | tee build.log; then
        echo "Error: RPM build failed. See build.log for details."
        exit 1
    fi
    
    # Copy built RPMs
    if [[ -d "$RPMBUILD_DIR/RPMS" ]]; then
        find "$RPMBUILD_DIR/RPMS" -name "*.rpm" -exec cp {} "$OUTPUT_DIR/" \;
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
