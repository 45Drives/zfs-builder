# OpenZFS RPM & DEB Builder

Build OpenZFS packages for multiple enterprise Linux and Ubuntu distributions using Podman containers. This tool downloads OpenZFS source tarballs from GitHub releases and builds reproducible RPM and DEB packages with custom changelogs attributing the build to 45Drives.

## Features

- **Podman-based builds**: Isolated, reproducible container builds (no daemon required)
- **Multi-distribution support**: Build for 6 distributions in a single command
  - **Rocky Linux**: 8, 9, 10 (RPM-based)
  - **Ubuntu**: 20.04 LTS, 22.04 LTS, 24.04 LTS (DEB-based)
- **Official OpenZFS best practices**: Follows dependencies and build methods from [OpenZFS official documentation](https://openzfs.github.io/openzfs-docs/Developer%20Resources/Building%20ZFS.html)
- **Configurable versions**: Build any OpenZFS version available on GitHub releases
- **DKMS support**: Packages include DKMS support for dynamic kernel module building
- **Custom changelogs**: Single changelog entry: "Built by 45Drives - no source code modifications"
- **Command-line friendly**: Simple CLI or Makefile targets
- **Multi-platform**: Works on any Linux system with Podman installed

## Prerequisites

- **Podman** (version 3.0+) - Install via your distribution's package manager
  - RHEL/CentOS: `dnf install podman`
  - Ubuntu/Debian: `apt-get install podman`
  - Fedora: `dnf install podman`

- **Sufficient disk space**: ~3-5 GB per build for source and build artifacts
- **Network access**: Required to download OpenZFS source tarballs from GitHub

## Quick Start

### Using the Shell Script

```bash
# Rocky Linux RPM builds
./build.sh rocky8 2.4.1      # Build RPM for Rocky Linux 8
./build.sh rocky9 2.4.1      # Build RPM for Rocky Linux 9
./build.sh rocky10 2.4.1     # Build RPM for Rocky Linux 10

# Ubuntu DEB builds
./build.sh ubuntu20 2.4.1    # Build DEB for Ubuntu 20.04
./build.sh ubuntu22 2.4.1    # Build DEB for Ubuntu 22.04
./build.sh ubuntu24 2.4.1    # Build DEB for Ubuntu 24.04

# Build all distributions at once
./build.sh all 2.4.1
```

### Using Make

```bash
# Rocky Linux builds
make build-rocky8 VERSION=2.4.1
make build-rocky9 VERSION=2.4.1
make build-rocky10 VERSION=2.4.1

# Ubuntu builds
make build-ubuntu20 VERSION=2.4.1
make build-ubuntu22 VERSION=2.4.1
make build-ubuntu24 VERSION=2.4.1

# Build all distributions
make build-all VERSION=2.4.1

# Clean output packages
make clean

# Remove Podman images
make podman-clean
```

## Usage Details

### Supported Distributions

**Rocky Linux (RPM-based):**
- `rocky8` - Rocky Linux 8 (RHEL 8 compatible)
- `rocky9` - Rocky Linux 9 (RHEL 9 compatible)
- `rocky10` - Rocky Linux 10 (RHEL 10 compatible)

**Ubuntu (DEB-based):**
- `ubuntu20` - Ubuntu 20.04 LTS (Focal Fossa)
- `ubuntu22` - Ubuntu 22.04 LTS (Jammy Jellyfish)
- `ubuntu24` - Ubuntu 24.04 LTS (Noble Numbat)

### Version Format

The version argument accepts standard semantic versioning:
- `2.4.1` (recommended)
- `zfs-2.4.1` (also accepted, `zfs-` prefix is stripped)

### Output Locations

Built packages are saved to organized by distribution:
- **Rocky 8 RPMs**: `output/rocky8/`
- **Rocky 9 RPMs**: `output/rocky9/`
- **Rocky 10 RPMs**: `output/rocky10/`
- **Ubuntu 20 DEBs**: `output/ubuntu20/`
- **Ubuntu 22 DEBs**: `output/ubuntu22/`
- **Ubuntu 24 DEBs**: `output/ubuntu24/`

Example output structure:
```
output/
├── rocky8/
│   ├── zfs-utils-2.4.1-45drives1.el8.x86_64.rpm
│   ├── libzfs7-2.4.1-45drives1.el8.x86_64.rpm
│   ├── libzfs-devel-2.4.1-45drives1.el8.x86_64.rpm
│   └── zfs-dkms-2.4.1-45drives1.el8.noarch.rpm
├── rocky9/
│   ├── zfs-utils-2.4.1-45drives1.el9.x86_64.rpm
│   ├── libzfs7-2.4.1-45drives1.el9.x86_64.rpm
│   ├── libzfs-devel-2.4.1-45drives1.el9.x86_64.rpm
│   └── zfs-dkms-2.4.1-45drives1.el9.noarch.rpm
├── rocky10/
│   ├── zfs-utils-2.4.1-45drives1.el10.x86_64.rpm
│   ├── libzfs7-2.4.1-45drives1.el10.x86_64.rpm
│   ├── libzfs-devel-2.4.1-45drives1.el10.x86_64.rpm
│   └── zfs-dkms-2.4.1-45drives1.el10.noarch.rpm
├── ubuntu20/
│   ├── openzfs-zfsutils_2.4.1-45drives1_amd64.deb
│   ├── openzfs-libzfs7_2.4.1-45drives1_amd64.deb
│   ├── openzfs-libzfs-dev_2.4.1-45drives1_amd64.deb
│   └── openzfs-zfs-dkms_2.4.1-45drives1_all.deb
├── ubuntu22/
│   ├── openzfs-zfsutils_2.4.1-45drives1_amd64.deb
│   ├── openzfs-libzfs7_2.4.1-45drives1_amd64.deb
│   ├── openzfs-libzfs-dev_2.4.1-45drives1_amd64.deb
│   └── openzfs-zfs-dkms_2.4.1-45drives1_all.deb
└── ubuntu24/
    ├── openzfs-zfsutils_2.4.1-45drives1_amd64.deb
    ├── openzfs-libzfs7_2.4.1-45drives1_amd64.deb
    ├── openzfs-libzfs-dev_2.4.1-45drives1_amd64.deb
    └── openzfs-zfs-dkms_2.4.1-45drives1_all.deb
```

### Built Packages

#### Rocky Linux RPM Packages (Rocky 8, 9, 10)
- `zfs-utils` - User-space utilities and libraries
- `libzfs7` - ZFS library (version 7 ABI)
- `libzfs-devel` - Development headers for libzfs
- `zfs-dkms` - DKMS kernel module support (builds on user system during install)

#### Ubuntu DEB Packages (Ubuntu 20.04, 22.04, 24.04)
- `openzfs-zfsutils` - User-space utilities
- `openzfs-libzfs7` - libzfs shared library
- `openzfs-libzfs-dev` - Development headers
- `openzfs-zfs-dkms` - DKMS kernel module support (builds on user system during install)

## Build Process

### How It Works

1. **Version Validation**: Validates semantic versioning format
2. **Podman Image Building**: Builds container images with required build tools and dependencies
3. **Source Download**: Downloads OpenZFS source tarball from GitHub releases
4. **Source Extraction**: Extracts tarball and prepares build environment
5. **Spec/Control Customization**: Modifies RPM spec file or DEB changelog with 45Drives attribution
6. **Package Building**: Runs `rpmbuild` (RPM) or `dpkg-buildpackage` (DEB) inside container
7. **Output Collection**: Copies built packages to output directory

### Changelog Format

The custom changelog entry for all built packages is:

**RPM** (`%changelog` section):
```
* Day Mon DD YYYY 45Drives <support@45drives.com> - 2.4.1-45drives1
- Built by 45Drives - no source code modifications
```

**DEB** (`debian/changelog`):
```
openzfs-zfs (2.4.1-45drives1) UNRELEASED; urgency=medium

  * Built by 45Drives - no source code modifications

 -- 45Drives <support@45drives.com>  Day, DD Mon YYYY HH:MM:SS +TIMEZONE
```

## Advanced Usage

### Rebuild Podman Images (Skip Cache)

To rebuild Podman images from scratch (useful if base image updates are needed):

```bash
# Rebuild a specific distribution
./build.sh rocky9 2.4.1 --no-cache
./build.sh ubuntu22 2.4.1 --no-cache

# Rebuild all distributions
./build.sh all 2.4.1 --no-cache
```

### Build Multiple Versions

```bash
./build.sh all 2.4.1
./build.sh all 2.4.0
./build.sh all 2.3.0
```

Or build specific distributions for multiple versions:

```bash
./build.sh rocky9 2.4.1
./build.sh rocky9 2.4.0
./build.sh ubuntu22 2.4.1
./build.sh ubuntu22 2.4.0
```

All outputs are organized by distribution in the `output/` directories.

### Inspect Built Packages

```bash
# List all built packages by distribution
ls -lh output/rocky8/
ls -lh output/rocky9/
ls -lh output/rocky10/
ls -lh output/ubuntu20/
ls -lh output/ubuntu22/
ls -lh output/ubuntu24/

# Query RPM package info (all Rocky variants)
rpm -qip output/rocky8/zfs-utils-*.rpm
rpm -qip output/rocky9/zfs-utils-*.rpm
rpm -qip output/rocky10/zfs-utils-*.rpm

# Query DEB package info (all Ubuntu variants)
dpkg-deb -I output/ubuntu20/openzfs-zfsutils_*.deb
dpkg-deb -I output/ubuntu22/openzfs-zfsutils_*.deb
dpkg-deb -I output/ubuntu24/openzfs-zfsutils_*.deb

# Extract and view changelog from RPM
rpm -q --changelog output/rocky9/zfs-utils-*.rpm | head -20

# Extract and view changelog from DEB
dpkg-deb --raw-extract output/ubuntu22/openzfs-zfsutils_*.deb /tmp/deb-extract
cat /tmp/deb-extract/usr/share/doc/openzfs-zfsutils/changelog.gz | gunzip
```

## Troubleshooting

### "Podman is not installed"

Install Podman for your distribution:

**RHEL/CentOS/Fedora:**
```bash
sudo dnf install podman
```

**Ubuntu/Debian:**
```bash
sudo apt-get install podman
```

**Verify installation:**
```bash
podman --version
podman info
```

### Build Fails with "Failed to download tarball"

Verify:
1. Network connectivity: `curl https://github.com`
2. Version exists on GitHub: `https://github.com/openzfs/zfs/releases`
3. Version format is correct (e.g., `2.4.1`, not `v2.4.1`)

### "Permission denied" errors when running build

Ensure `build.sh` is executable:
```bash
chmod +x build.sh
chmod +x scripts/*.sh
```

### Build container runs out of disk space

The build process requires substantial temporary space. Check available disk:
```bash
df -h /tmp
df -h /var/lib/containers  # Podman container storage
```

Increase available space or use a different disk location for Podman storage.

### Podman image build fails

Check Podman daemon status:
```bash
podman system info
```

Clean up unused images:
```bash
podman image prune -a
```

Rebuild images without cache:
```bash
./build.sh both 2.4.1 --no-cache
```

### Build succeeds but no packages in output directory

Verify Podman volume mounts are working:
```bash
podman run --rm -v $(pwd)/output/el9:/test alpine touch /test/test.txt
ls -la output/el9/test.txt
```

If volume mount fails, check SELinux context (on RHEL-based systems):
```bash
ls -laZ output/
```

## Project Structure

```
zfs-builder/
├── build.sh                 # Main orchestrator script
├── Makefile                 # Convenience make targets
├── README.md               # This file
├── .gitignore              # Git ignore patterns
├── .podmanignore           # Podman build ignore patterns
├── podman/
│   ├── Containerfile.rocky8        # Rocky Linux 8 build container
│   ├── Containerfile.rocky9        # Rocky Linux 9 build container
│   ├── Containerfile.rocky10       # Rocky Linux 10 build container
│   ├── Containerfile.ubuntu20      # Ubuntu 20.04 build container
│   ├── Containerfile.ubuntu22      # Ubuntu 22.04 build container
│   └── Containerfile.ubuntu24      # Ubuntu 24.04 build container
├── scripts/
│   ├── build-rpm.sh               # RPM build script
│   ├── build-deb.sh               # DEB build script
│   └── generate-changelog.sh      # Changelog generation utility
└── output/
    ├── rocky8/                    # Rocky Linux 8 RPM output
    ├── rocky9/                    # Rocky Linux 9 RPM output
    ├── rocky10/                   # Rocky Linux 10 RPM output
    ├── ubuntu20/                  # Ubuntu 20.04 DEB output
    ├── ubuntu22/                  # Ubuntu 22.04 DEB output
    └── ubuntu24/                  # Ubuntu 24.04 DEB output
```

## How the Build Works

### Build Process Overview

For each distribution, the build process follows the official OpenZFS build methodology:

1. **Distribution Validation**: Validates distribution name against supported list
2. **Version Validation**: Validates semantic versioning format
3. **Podman Image Building**: Builds distribution-specific container image with dependencies per [OpenZFS official documentation](https://openzfs.github.io/openzfs-docs/Developer%20Resources/Building%20ZFS.html#installing-dependencies)
4. **Source Download**: Downloads OpenZFS source tarball from GitHub releases
5. **Source Extraction**: Extracts tarball and prepares build environment
6. **Configure**: Runs `./configure` with OpenZFS standard options
7. **Package Building**: Uses standard OpenZFS build methods:
   - `make rpm` for Rocky Linux RPM packages
   - `make native-deb` or `make deb` for Ubuntu DEB packages
   - Falls back to `rpmbuild`/`dpkg-buildpackage` if standard methods unavailable
8. **Changelog Customization**: Injects 45Drives attribution in changelog
9. **Output Collection**: Copies built packages to distribution-specific output directory

### Dependencies

All Containerfiles include complete dependencies as documented in the [OpenZFS Building Guide](https://openzfs.github.io/openzfs-docs/Developer%20Resources/Building%20ZFS.html):

**Rocky 8/9/10 (per OpenZFS docs):**
- `libtirpc-devel` - TI-RPC library development files
- `zlib-devel` - Compression library
- `libaio-devel` - Asynchronous I/O library
- `libcurl-devel` - URL transfer library
- Plus additional packages: gcc, make, autoconf, automake, kernel-devel, python3, dkms, etc.

**Ubuntu 20.04/22.04/24.04 (per OpenZFS docs):**
- `libaio-dev` - Asynchronous I/O library
- `libcurl4-openssl-dev` - URL transfer library
- `libpam0g-dev` - PAM library
- `libtirpc-dev` - TI-RPC library
- Plus additional packages: debhelper, dh-dkms, dh-autoreconf, python3, git, etc.

### Multi-Distribution Build

When using `./build.sh all <version>`, all distributions are built sequentially:

```
./build.sh all 2.4.1
    ├─ Rocky 8 build (RPM)
    ├─ Rocky 9 build (RPM)
    ├─ Rocky 10 build (RPM)
    ├─ Ubuntu 20 build (DEB)
    ├─ Ubuntu 22 build (DEB)
    └─ Ubuntu 24 build (DEB)
```

### Single Distribution Build Example (Rocky 9)

```
build.sh rocky9 2.4.1
    ↓
Build Podman image (Containerfile.rocky9)
    ↓ (includes all deps per OpenZFS official docs)
podman run zfs-builder-rocky9:latest
    ↓
build-rpm.sh 2.4.1
    ├─ Download tarball from GitHub
    ├─ Extract tarball
    ├─ Run ./configure with standard options
    ├─ Execute: make rpm (or rpmbuild as fallback)
    └─ Copy RPMs to output/rocky9/
```

### Single Distribution Build Example (Ubuntu 22)

```
build.sh ubuntu22 2.4.1
    ↓
Build Podman image (Containerfile.ubuntu22)
    ↓ (includes all deps per OpenZFS official docs)
podman run zfs-builder-ubuntu22:latest
    ↓
build-deb.sh 2.4.1
    ├─ Download tarball from GitHub
    ├─ Extract tarball
    ├─ Run ./configure with standard options
    ├─ Execute: make native-deb or make deb (or dpkg-buildpackage as fallback)
    └─ Copy DEBs to output/ubuntu22/
```

## Contributing & Development

### Modify Build Scripts

Edit scripts in `scripts/` to customize the build process:
- `build-rpm.sh` - RPM build logic (used by all Rocky distributions)
- `build-deb.sh` - DEB build logic (used by all Ubuntu distributions)
- `generate-changelog.sh` - Changelog generation

### Modify Container Images

Edit Containerfiles to add/remove dependencies:
- `podman/Containerfile.rocky8` - Rocky Linux 8 container
- `podman/Containerfile.rocky9` - Rocky Linux 9 container
- `podman/Containerfile.rocky10` - Rocky Linux 10 container
- `podman/Containerfile.ubuntu20` - Ubuntu 20.04 container
- `podman/Containerfile.ubuntu22` - Ubuntu 22.04 container
- `podman/Containerfile.ubuntu24` - Ubuntu 24.04 container

### Test Changes

```bash
# Test with a specific distribution
./build.sh rocky9 2.4.1

# Verify output
ls -la output/rocky9/

# Test all distributions
./build.sh all 2.4.1

# Inspect packages
rpm -q --changelog output/rocky9/zfs-utils-*.rpm
```

## License

This build tooling is maintained by 45Drives. See LICENSE file for details.

## OpenZFS Documentation Compliance

This builder follows best practices from the official [OpenZFS Developer Resources](https://openzfs.github.io/openzfs-docs/Developer%20Resources/index.html):

- **Building Dependencies**: All Containerfiles install the complete dependency list as documented in [Building ZFS](https://openzfs.github.io/openzfs-docs/Developer%20Resources/Building%20ZFS.html#installing-dependencies)
- **Build Methods**: Uses standard OpenZFS package building methods (`make rpm`, `make deb`, `make native-deb`)
- **Distribution-Specific Optimizations**: Respects distribution-specific best practices (e.g., no path overrides for native Debian packages)
- **DKMS Integration**: Includes DKMS support for dynamic kernel module compilation as recommended

For more information about building OpenZFS, see:
- [OpenZFS Building Guide](https://openzfs.github.io/openzfs-docs/Developer%20Resources/Building%20ZFS.html)
- [Custom Packages](https://openzfs.github.io/openzfs-docs/Developer%20Resources/Custom%20Packages.html)
- [GitHub OpenZFS Repository](https://github.com/openzfs/zfs)

## Support

For issues or questions:
- Check the Troubleshooting section above
- Review Podman documentation: https://docs.podman.io/
- Check OpenZFS releases: https://github.com/openzfs/zfs/releases
- Review OpenZFS documentation: https://openzfs.github.io/openzfs-docs/ds (`make rpm`, `make deb`, `make native-deb`)
- **Distribution-Specific Optimizations**: Respects distribution-specific best practices (e.g., no path overrides for native Debian packages)
- **DKMS Integration**: Includes DKMS support for dynamic kernel module compilation as recommended

For more information about building OpenZFS, see:
- [OpenZFS Building Guide](https://openzfs.github.io/openzfs-docs/Developer%20Resources/Building%20ZFS.html)
- [Custom Packages](https://openzfs.github.io/openzfs-docs/Developer%20Resources/Custom%20Packages.html)
- [GitHub OpenZFS Repository](https://github.com/openzfs/zfs)

## Support

For issues or questions:
- Check the Troubleshooting section above
- Review Podman documentation: https://docs.podman.io/
- Check OpenZFS releases: https://github.com/openzfs/zfs/releases
- Review OpenZFS documentation: https://openzfs.github.io/openzfs-docs/