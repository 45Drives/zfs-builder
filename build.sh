#!/bin/bash
# OpenZFS RPM/DEB Builder - Main Orchestrator
# Builds unmodified upstream OpenZFS packages for multiple distributions using Podman
# Usage: ./build.sh <distribution|all> <version> [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINERFILE_DIR="$SCRIPT_DIR/podman"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
KEYRING_FILE="$SCRIPT_DIR/keys/openzfs-release-keys.asc"
OUTPUT_DIR="${ZFS_OUTPUT_DIR:-$SCRIPT_DIR/output}"
CACHE_DIR="${ZFS_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/zfs-builder}"
RELEASE_URL="https://github.com/openzfs/zfs/releases/download"

# Fingerprints of the keys OpenZFS releases are signed with (shipped in keys/).
# https://openzfs.github.io/openzfs-docs/Project%20and%20Community/Signing%20Keys.html
TRUSTED_FINGERPRINTS=(
    "C33DF142657ED1F7C328A2960AB9E991C6AF658B"  # Brian Behlendorf
    "4F3BA9AB6D1F8D683DC2DFB56AD860EED4598027"  # Tony Hutter
)

# Supported distributions: name -> "<package type>|<base image release>|<display name>"
DISTROS=(rocky8 rocky9 rocky10 ubuntu20 ubuntu22 ubuntu24)
declare -A DISTRO_INFO=(
    [rocky8]="rpm|8|Rocky Linux 8"
    [rocky9]="rpm|9|Rocky Linux 9"
    [rocky10]="rpm|10|Rocky Linux 10"
    [ubuntu20]="deb|20.04|Ubuntu 20.04 LTS"
    [ubuntu22]="deb|22.04|Ubuntu 22.04 LTS"
    [ubuntu24]="deb|24.04|Ubuntu 24.04 LTS"
)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat <<USAGE
OpenZFS RPM/DEB Builder
Usage: $0 <distribution|all> <version> [options]

Supported Distributions:
  rocky8, rocky9, rocky10       RPM packages for Rocky Linux / EL 8, 9, 10
  ubuntu20, ubuntu22, ubuntu24  DEB packages for Ubuntu 20.04, 22.04, 24.04 LTS
  all                           Every distribution above

Arguments:
  version             OpenZFS release version (e.g., 2.4.1 or zfs-2.4.1)

Options:
  --output-dir <dir>  Output directory for built packages (default: ./output)
  --cache-dir <dir>   Where verified source tarballs are cached
                      (default: ~/.cache/zfs-builder)
  --jobs <n>          Build up to <n> distributions at once (default: 1)
  --no-cache          Rebuild container images from scratch
  --no-verify         Skip GPG signature verification of the source tarball
  --help              Show this help message

Environment Variables:
  ZFS_OUTPUT_DIR      Default output directory (overridden by --output-dir)
  ZFS_CACHE_DIR       Default cache directory (overridden by --cache-dir)

Examples:
  $0 rocky9 2.4.1                               # RPMs for Rocky 9
  $0 ubuntu22 2.4.1                             # DEBs for Ubuntu 22.04
  $0 all 2.4.1 --jobs 3                         # Everything, three builds at a time
  $0 all 2.4.1 --output-dir /var/zfs-packages   # Custom output directory

Output layout (per distribution):
  <output-dir>/<distro>/latest/              Packages and build.log of the last successful build
  <output-dir>/<distro>/archive/<timestamp>/ Previous successful builds
  <output-dir>/<distro>/failed-build.log     Log of the most recent failed build, if any

A failed build never touches latest/.
USAGE
}

error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1" >&2
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
for arg in "$@"; do
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
        usage
        exit 0
    fi
done

if [[ $# -lt 2 ]]; then
    echo -e "${RED}Error: Missing arguments${NC}" >&2
    usage >&2
    exit 2
fi

DISTRO="$1"
VERSION="$2"
shift 2

NO_CACHE=0
VERIFY=1
JOBS=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            [[ -n "${2:-}" ]] || error "--output-dir requires an argument"
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --cache-dir)
            [[ -n "${2:-}" ]] || error "--cache-dir requires an argument"
            CACHE_DIR="$2"
            shift 2
            ;;
        --jobs|-j)
            [[ "${2:-}" =~ ^[1-9][0-9]*$ ]] || error "--jobs requires a positive integer"
            JOBS="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE=1
            shift
            ;;
        --no-verify)
            VERIFY=0
            shift
            ;;
        --all)
            DISTRO="all"
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

if [[ "$DISTRO" == "all" ]]; then
    DISTRIBUTIONS=("${DISTROS[@]}")
elif [[ -v DISTRO_INFO[$DISTRO] ]]; then
    DISTRIBUTIONS=("$DISTRO")
else
    error "Unknown distribution '$DISTRO'. Run '$0 --help' for supported options."
fi

# Normalize version (remove 'zfs-' prefix if present) and validate it
VERSION="${VERSION#zfs-}"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$ ]]; then
    error "Invalid version format '$VERSION'. Expected e.g. 2.4.1"
fi

command -v podman &> /dev/null || error "Podman is not installed. Please install Podman to continue."
command -v curl &> /dev/null || error "curl is not installed. Please install curl to continue."

# Make a path absolute (expanding a leading ~)
absolute_path() {
    local path="${1/#\~/$HOME}"
    [[ "$path" == /* ]] || path="$PWD/$path"
    echo "$path"
}
OUTPUT_DIR="$(absolute_path "$OUTPUT_DIR")"
CACHE_DIR="$(absolute_path "$CACHE_DIR")"

if (( JOBS > ${#DISTRIBUTIONS[@]} )); then
    JOBS=${#DISTRIBUTIONS[@]}
fi

TARBALL_NAME="zfs-${VERSION}.tar.gz"
TARBALL="$CACHE_DIR/$TARBALL_NAME"

# ---------------------------------------------------------------------------
# Source download and verification (once, on the host)
# ---------------------------------------------------------------------------
download() {
    local url="$1" dest="$2"
    if ! curl --fail --location --silent --show-error --retry 3 --retry-delay 2 \
        --output "$dest.part" "$url"; then
        rm -f "$dest.part"
        return 1
    fi
    mv "$dest.part" "$dest"
}

# Succeeds only if the signature is valid AND made by one of the pinned keys.
verify_signature() {
    local tarball="$1" signature="$2"
    command -v gpg &> /dev/null || \
        error "gpg is required to verify the source tarball (or pass --no-verify)"
    [[ -f "$KEYRING_FILE" ]] || error "Release keyring not found: $KEYRING_FILE"

    local gnupg_home status fingerprint trusted
    gnupg_home="$(mktemp -d)"
    chmod 700 "$gnupg_home"
    status="$(
        export GNUPGHOME="$gnupg_home"
        gpg --batch --quiet --import "$KEYRING_FILE" 2> /dev/null
        gpg --batch --status-fd 1 --verify "$signature" "$tarball" 2> /dev/null
    )" || true
    rm -rf "$gnupg_home"

    # VALIDSIG's last field is the fingerprint of the primary key that signed.
    fingerprint="$(awk '$2 == "VALIDSIG" { print $NF }' <<< "$status")"
    [[ -n "$fingerprint" ]] || return 1
    for trusted in "${TRUSTED_FINGERPRINTS[@]}"; do
        [[ "$fingerprint" == "$trusted" ]] && return 0
    done
    return 1
}

fetch_source() {
    mkdir -p "$CACHE_DIR"
    local base="$RELEASE_URL/zfs-${VERSION}"

    if [[ -f "$TARBALL" ]]; then
        info "Using cached source tarball: $TARBALL"
    else
        echo "Downloading $TARBALL_NAME..."
        download "$base/$TARBALL_NAME" "$TARBALL" || \
            error "Failed to download $base/$TARBALL_NAME (does release $VERSION exist?)"
    fi

    if (( VERIFY )); then
        if [[ ! -f "$TARBALL.asc" ]]; then
            download "$base/$TARBALL_NAME.asc" "$TARBALL.asc" || \
                error "Failed to download signature $base/$TARBALL_NAME.asc"
        fi
        if ! verify_signature "$TARBALL" "$TARBALL.asc"; then
            rm -f "$TARBALL" "$TARBALL.asc"
            error "GPG signature verification FAILED for $TARBALL_NAME; removed it from the cache"
        fi
        info "GPG signature verified (OpenZFS release key)"
    else
        warn "Skipping GPG signature verification (--no-verify)"
    fi
    echo "  SHA256: $(sha256sum "$TARBALL" | cut -d' ' -f1)"
}

# ---------------------------------------------------------------------------
# Per-distribution build
# ---------------------------------------------------------------------------
# Builds into a staging directory and only replaces latest/ on success.
# Runs in a subshell; the exit status is the build result.
build_distribution() (
    distro="$1"
    IFS='|' read -r pkg_type release display <<< "${DISTRO_INFO[$distro]}"
    image="zfs-builder-$distro:latest"
    distro_dir="$OUTPUT_DIR/$distro"
    staging_dir="$distro_dir/.staging"
    log="$distro_dir/.build.log"

    rm -rf "$staging_dir"
    mkdir -p "$staging_dir" || exit 1
    rm -f "$distro_dir/failed-build.log"

    # Sequential builds also stream to the terminal; parallel builds only log.
    run_logged() {
        if (( JOBS == 1 )); then
            "$@" 2>&1 | tee -a "$log"
        else
            "$@" >> "$log" 2>&1
        fi
    }

    # errexit is inactive here (the caller tests our exit status), so every
    # step that can fail is checked explicitly.
    fail() {
        run_logged echo "Error: $1"
        mv "$log" "$distro_dir/failed-build.log"
        rm -rf "$staging_dir"
        exit 1
    }

    : > "$log"
    run_logged echo "=== Building OpenZFS $VERSION for $display ==="

    build_args=(--pull=newer --build-arg "RELEASE=$release" -t "$image"
                -f "$CONTAINERFILE_DIR/Containerfile.$pkg_type")
    if (( NO_CACHE )); then
        build_args+=(--no-cache)
    fi
    run_logged podman build "${build_args[@]}" "$SCRIPTS_DIR" \
        || fail "container image build failed"

    run_logged podman run --rm \
        -v "$staging_dir:/output:Z" \
        -v "$CACHE_DIR:/source:ro,z" \
        "$image" "/usr/local/bin/build-$pkg_type" "$VERSION" "/source/$TARBALL_NAME" /output \
        || fail "package build failed"

    compgen -G "$staging_dir/*.$pkg_type" > /dev/null \
        || fail "build produced no .$pkg_type packages"

    # Success: archive the previous build, then promote staging to latest/
    mv "$log" "$staging_dir/build.log"
    if [[ -d "$distro_dir/latest" ]]; then
        archive_dir="$distro_dir/archive/$(date +'%Y%m%d-%H%M%S')"
        mkdir -p "$distro_dir/archive"
        mv "$distro_dir/latest" "$archive_dir" || exit 1
    fi
    mv "$staging_dir" "$distro_dir/latest"
)

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
info "OpenZFS Builder initialized"
echo "  Version: $VERSION"
echo "  Distributions: ${DISTRIBUTIONS[*]}"
echo "  Output: $OUTPUT_DIR"
echo "  Parallel builds: $JOBS"
echo ""

fetch_source
echo ""

STATUS_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$STATUS_DIR"
    local d
    for d in "${DISTRIBUTIONS[@]}"; do
        rm -rf "$OUTPUT_DIR/$d/.staging" "$OUTPUT_DIR/$d/.build.log"
    done
}
trap cleanup EXIT
trap 'exit 130' INT TERM

run_build() {
    local distro="$1" rc=0
    if (( JOBS > 1 )); then
        echo "→ $distro: build started"
    fi
    build_distribution "$distro" || rc=$?
    echo "$rc" > "$STATUS_DIR/$distro"
    if (( JOBS > 1 )); then
        if (( rc == 0 )); then
            info "$distro: build finished"
        else
            warn "$distro: build FAILED"
        fi
    fi
}

if (( JOBS == 1 )); then
    for distro in "${DISTRIBUTIONS[@]}"; do
        run_build "$distro"
        echo ""
    done
else
    running=0
    for distro in "${DISTRIBUTIONS[@]}"; do
        if (( running >= JOBS )); then
            wait -n || true
            running=$((running - 1))
        fi
        run_build "$distro" &
        running=$((running + 1))
    done
    wait
    echo ""
fi

# Summary: every distribution is attempted; any failure makes the run fail.
echo "========================================="
echo "Build summary (OpenZFS $VERSION)"
echo "========================================="
failed=0
for distro in "${DISTRIBUTIONS[@]}"; do
    IFS='|' read -r pkg_type _ _ <<< "${DISTRO_INFO[$distro]}"
    if [[ "$(cat "$STATUS_DIR/$distro" 2> /dev/null)" == "0" ]]; then
        latest="$OUTPUT_DIR/$distro/latest"
        count=$(find "$latest" -maxdepth 1 -name "*.$pkg_type" -type f | wc -l)
        info "$distro: $count packages in $latest/"
    else
        failed=$((failed + 1))
        echo -e "${RED}✗${NC} $distro: FAILED (log: $OUTPUT_DIR/$distro/failed-build.log)"
    fi
done
echo "========================================="

if (( failed > 0 )); then
    error "$failed of ${#DISTRIBUTIONS[@]} builds failed"
fi
info "All builds completed successfully"
