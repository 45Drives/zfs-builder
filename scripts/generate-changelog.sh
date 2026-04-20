#!/bin/bash
# Generate changelog entries for RPM or DEB packages
# Usage: generate-changelog.sh <format> <version> <package-name>
# Formats: rpm, deb

set -e

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 {rpm|deb} <version> [package-name]"
    echo "  rpm: Generate RPM %changelog section"
    echo "  deb: Generate Debian changelog entry"
    exit 1
fi

FORMAT="$1"
VERSION="$2"
PACKAGE_NAME="${3:-openzfs-zfs}"

# Normalize version (remove 'zfs-' prefix if present)
VERSION="${VERSION#zfs-}"

case "$FORMAT" in
    rpm)
        # Generate RPM %changelog format
        # Format: * Day Mon DD YYYY Maintainer <email> - VERSION-RELEASE
        #         - Changelog entry
        DATE=$(date '+%a %b %d %Y')
        cat <<EOF
* $DATE 45Drives <support@45drives.com> - $VERSION-45drives1
- Built by 45Drives - no source code modifications

EOF
        ;;
    deb)
        # Generate Debian changelog format
        # Format: package-name (version) distribution; urgency=level
        #         * Entry
        #         -- Name <email>  Day, DD Mon YYYY HH:MM:SS +TIMEZONE
        DATE=$(date -R)
        cat <<EOF
$PACKAGE_NAME ($VERSION-45drives1) UNRELEASED; urgency=medium

  * Built by 45Drives - no source code modifications

 -- 45Drives <support@45drives.com>  $DATE

EOF
        ;;
    *)
        echo "Error: Unknown format '$FORMAT'. Use 'rpm' or 'deb'."
        exit 1
        ;;
esac
