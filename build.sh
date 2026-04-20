#!/bin/bash
# OpenZFS RPM/DEB Builder - Main Orchestrator
# Builds OpenZFS packages for multiple distributions using Podman
# Usage: ./build.sh <distribution> <version> [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PODMAN_IMAGES_DIR="$SCRIPT_DIR/podman"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
# Allow output directory to be overridden by environment variable or will use default
OUTPUT_DIR="${ZFS_OUTPUT_DIR:-$SCRIPT_DIR/output}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Supported distributions
declare -A DISTRO_IMAGE
declare -A DISTRO_SCRIPT
declare -A DISTRO_OUTPUT
declare -A DISTRO_TYPE

# Rocky distributions (RPM)
DISTRO_IMAGE[rocky8]="zfs-builder-rocky8:latest"
DISTRO_SCRIPT[rocky8]="build-rpm"
DISTRO_OUTPUT[rocky8]="rocky8"
DISTRO_TYPE[rocky8]="rpm"

DISTRO_IMAGE[rocky9]="zfs-builder-rocky9:latest"
DISTRO_SCRIPT[rocky9]="build-rpm"
DISTRO_OUTPUT[rocky9]="rocky9"
DISTRO_TYPE[rocky9]="rpm"

DISTRO_IMAGE[rocky10]="zfs-builder-rocky10:latest"
DISTRO_SCRIPT[rocky10]="build-rpm"
DISTRO_OUTPUT[rocky10]="rocky10"
DISTRO_TYPE[rocky10]="rpm"

# Ubuntu distributions (DEB)
DISTRO_IMAGE[ubuntu20]="zfs-builder-ubuntu20:latest"
DISTRO_SCRIPT[ubuntu20]="build-deb"
DISTRO_OUTPUT[ubuntu20]="ubuntu20"
DISTRO_TYPE[ubuntu20]="deb"

DISTRO_IMAGE[ubuntu22]="zfs-builder-ubuntu22:latest"
DISTRO_SCRIPT[ubuntu22]="build-deb"
DISTRO_OUTPUT[ubuntu22]="ubuntu22"
DISTRO_TYPE[ubuntu22]="deb"

DISTRO_IMAGE[ubuntu24]="zfs-builder-ubuntu24:latest"
DISTRO_SCRIPT[ubuntu24]="build-deb"
DISTRO_OUTPUT[ubuntu24]="ubuntu24"
DISTRO_TYPE[ubuntu24]="deb"

usage() {
    cat <<EOF
OpenZFS RPM/DEB Builder
Usage: $0 <distribution> <version> [options]

Supported Distributions:
  Rocky Linux:
    rocky8      Build RPM for Rocky Linux 8
    rocky9      Build RPM for Rocky Linux 9
    rocky10     Build RPM for Rocky Linux 10
  Ubuntu:
    ubuntu20    Build DEB for Ubuntu 20.04 LTS
    ubuntu22    Build DEB for Ubuntu 22.04 LTS
    ubuntu24    Build DEB for Ubuntu 24.04 LTS

Arguments:
  distribution    See supported distributions above
  version         OpenZFS version (e.g., 2.4.1 or zfs-2.4.1)

Options:
  --output-dir <dir>  Output directory for built packages (default: ./output)
  --no-cache          Do not use cached layers; rebuild images from scratch
  --all               Build for all supported distributions (ignores distribution arg)
  --help              Show this help message

Environment Variables:
  ZFS_OUTPUT_DIR      Set default output directory (can be overridden by --output-dir)

Examples:
  $0 rocky9 2.4.1                              # Build RPM for Rocky 9
  $0 ubuntu22 2.4.1                            # Build DEB for Ubuntu 22
  $0 rocky9 2.4.1 --no-cache                   # Rebuild Rocky 9 image without cache
  $0 all 2.4.1 --output-dir /var/zfs-packages # Build for all, save to custom dir
  $0 rocky8 2.4.1 --output-dir ~/my-packages  # Build with custom output directory
  ZFS_OUTPUT_DIR=/mnt/packages $0 rocky9 2.4.1 # Use environment variable

Output packages are saved to (default):
  - Rocky 8 RPMs: ./output/rocky8/
  - Rocky 9 RPMs: ./output/rocky9/
  - Rocky 10 RPMs: ./output/rocky10/
  - Ubuntu 20 DEBs: ./output/ubuntu20/
  - Ubuntu 22 DEBs: ./output/ubuntu22/
  - Ubuntu 24 DEBs: ./output/ubuntu24/

EOF
    exit 0
}

error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Parse arguments
if [[ $# -lt 2 ]]; then
    echo "Error: Missing arguments" >&2
    usage
fi

DISTRO="$1"
VERSION="$2"
NO_CACHE=""
BUILD_ALL=0

# Parse optional arguments
shift 2
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            usage
            ;;
        --output-dir)
            if [[ -z "$2" ]]; then
                error "--output-dir requires an argument"
            fi
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --all)
            BUILD_ALL=1
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Handle --all flag
if [[ $BUILD_ALL -eq 1 ]] || [[ "$DISTRO" == "all" ]]; then
    DISTRIBUTIONS=("rocky8" "rocky9" "rocky10" "ubuntu20" "ubuntu22" "ubuntu24")
else
    # Validate distribution
    if [[ ! -v DISTRO_IMAGE[$DISTRO] ]]; then
        error "Unknown distribution '$DISTRO'. Run '$0 --help' for supported options."
    fi
    DISTRIBUTIONS=("$DISTRO")
fi

# Normalize version (remove 'zfs-' prefix if present)
VERSION="${VERSION#zfs-}"

# Validate version format (basic semver check)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-.+)?$ ]]; then
    error "Invalid version format '$VERSION'. Expected semver (e.g., 2.4.1)"
fi

# Check for Podman
if ! command -v podman &> /dev/null; then
    error "Podman is not installed. Please install Podman to continue."
fi

# Convert output directory to absolute path
OUTPUT_DIR="${OUTPUT_DIR/#\~/$HOME}"  # Expand tilde
if [[ ! "$OUTPUT_DIR" = /* ]]; then
    # Relative path - make it absolute based on current working directory
    OUTPUT_DIR="$(pwd)/$OUTPUT_DIR"
fi

info "OpenZFS Builder initialized"
echo "  Version: $VERSION"
echo "  Distributions: ${DISTRIBUTIONS[*]}"
echo "  Output: $OUTPUT_DIR"
echo ""

# Create all output directories
mkdir -p "$OUTPUT_DIR/rocky8"
mkdir -p "$OUTPUT_DIR/rocky9"
mkdir -p "$OUTPUT_DIR/rocky10"
mkdir -p "$OUTPUT_DIR/ubuntu20"
mkdir -p "$OUTPUT_DIR/ubuntu22"
mkdir -p "$OUTPUT_DIR/ubuntu24"

# Function to build for a specific distribution
build_distribution() {
    local DISTRO="$1"
    local IMAGE_NAME="${DISTRO_IMAGE[$DISTRO]}"
    local SCRIPT="${DISTRO_SCRIPT[$DISTRO]}"
    local OUTPUT="${DISTRO_OUTPUT[$DISTRO]}"
    local DISTRO_TYPE="${DISTRO_TYPE[$DISTRO]}"
    local DISTRO_DISPLAY="$DISTRO"
    
    # Friendly display names
    case "$DISTRO" in
        rocky8) DISTRO_DISPLAY="Rocky Linux 8" ;;
        rocky9) DISTRO_DISPLAY="Rocky Linux 9" ;;
        rocky10) DISTRO_DISPLAY="Rocky Linux 10" ;;
        ubuntu20) DISTRO_DISPLAY="Ubuntu 20.04 LTS" ;;
        ubuntu22) DISTRO_DISPLAY="Ubuntu 22.04 LTS" ;;
        ubuntu24) DISTRO_DISPLAY="Ubuntu 24.04 LTS" ;;
    esac
    
    echo "========================================="
    echo "Building for $DISTRO_DISPLAY"
    echo "========================================="
    
    # Find Containerfile
    local CONTAINERFILE="$PODMAN_IMAGES_DIR/Containerfile.$DISTRO"
    if [[ ! -f "$CONTAINERFILE" ]]; then
        error "Containerfile not found: $CONTAINERFILE"
    fi
    
    # Build Podman image
    echo ""
    info "Building Podman image: $IMAGE_NAME"
    if ! podman build \
        -t "$IMAGE_NAME" \
        -f "$CONTAINERFILE" \
        $NO_CACHE \
        "$SCRIPT_DIR" 2>&1 | tail -20; then
        error "Failed to build Podman image"
    fi
    
    # Run build container
    echo ""
    info "Running build in container..."
    local OUTPUT_PATH="$OUTPUT_DIR/$OUTPUT"
    if ! podman run --rm \
        -v "$OUTPUT_PATH:/tmp/zfs-build/output/$OUTPUT:Z" \
        "$IMAGE_NAME" \
        /usr/local/bin/$SCRIPT "$VERSION" /tmp/zfs-build/output/$OUTPUT 2>&1 | tail -50; then
        error "Build failed for $DISTRO_DISPLAY"
    fi
    
    echo ""
}


# Execute builds for each distribution
for DISTRO in "${DISTRIBUTIONS[@]}"; do
    build_distribution "$DISTRO"
done

# Final summary
echo ""
echo "========================================="
info "Build process completed successfully!"
echo "========================================="
echo ""
echo "Output packages:"
echo ""

# Show all generated packages
for DISTRO in "${DISTRIBUTIONS[@]}"; do
    local OUTPUT="${DISTRO_OUTPUT[$DISTRO]}"
    local OUTPUT_PATH="$OUTPUT_DIR/$OUTPUT"
    
    case "$DISTRO" in
        rocky*) EXT="rpm" ;;
        ubuntu*) EXT="deb" ;;
    esac
    
    if find "$OUTPUT_PATH" -name "*.$EXT" -type f 2>/dev/null | grep -q .; then
        echo "$DISTRO ($OUTPUT_PATH/):"
        find "$OUTPUT_PATH" -name "*.$EXT" -type f -exec ls -lh {} \;
        echo ""
    fi
done

echo "========================================="
