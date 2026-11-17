# OpenZFS RPM & DEB Builder

Build OpenZFS packages for Rocky Linux and Ubuntu using Podman containers. The tool downloads an official OpenZFS release tarball, verifies its GPG signature, and builds the source **unmodified** with the upstream packaging targets. Packages are named the way each distribution names its ZFS packages (`zfs-2.4.1-1.el9` on EL, `zfsutils-linux_2.4.1-1jammy` on Ubuntu), so they install as a drop-in upgrade for the ZFS packages already on a system.

## Features

- **Podman-based builds**: isolated container builds, no daemon required
- **Six distributions**:
  - **Rocky Linux** 8, 9, 10 (RPM)
  - **Ubuntu** 20.04, 22.04, 24.04 LTS (DEB)
- **Distribution-native package names**: no source changes; the release tag identifies the target (`el9`, `jammy`, ...)
- **Verified source**: the release tarball is checked against the OpenZFS release signing keys before anything is built
- **Parallel builds**: build several distributions at once with `--jobs`
- **Safe output handling**: `latest/` is only replaced by a successful build; the previous build is archived
- **DKMS packages**: the kernel module is built on the target system at install time

## Prerequisites

- **Podman** 4.0 or newer
- **curl**, **gpg** and **sha256sum** on the host (gpg is only needed for signature verification)
- **Disk space**: roughly 3-5 GB per distribution for images and build artifacts
- **Network access** to GitHub (source tarball) and the distribution mirrors (build dependencies)

## Quick Start

```bash
# One distribution
./build.sh rocky9 2.4.1
./build.sh ubuntu24 2.4.1

# Everything, three distributions at a time
./build.sh all 2.4.1 --jobs 3
```

Or with Make:

```bash
make build-rocky9 VERSION=2.4.1
make build-all VERSION=2.4.1 JOBS=3

make clean          # remove output/
make podman-clean   # remove the build images
```

## Usage

```
./build.sh <distribution|all> <version> [options]
```

| Distribution | Target | Packages |
|---|---|---|
| `rocky8` | Rocky Linux / EL 8 | RPM |
| `rocky9` | Rocky Linux / EL 9 | RPM |
| `rocky10` | Rocky Linux / EL 10 | RPM |
| `ubuntu20` | Ubuntu 20.04 LTS | DEB |
| `ubuntu22` | Ubuntu 22.04 LTS | DEB |
| `ubuntu24` | Ubuntu 24.04 LTS | DEB |
| `all` | all of the above | |

The version is an OpenZFS release such as `2.4.1` (`zfs-2.4.1` is also accepted).

| Option | Meaning |
|---|---|
| `--output-dir <dir>` | Where packages are written (default `./output`, or `$ZFS_OUTPUT_DIR`) |
| `--cache-dir <dir>` | Where verified source tarballs are kept (default `~/.cache/zfs-builder`, or `$ZFS_CACHE_DIR`) |
| `--jobs <n>` | Build up to `n` distributions at once (default 1) |
| `--no-cache` | Rebuild the container images from scratch |
| `--no-verify` | Skip GPG verification of the source tarball |
| `--help` | Show help |

With `--jobs 1` the build output streams to the terminal. With more than one job, each build writes only to its log file and the terminal shows start/finish lines plus a summary.

When several distributions are built, every one is attempted even if another fails. The exit status is non-zero if any build failed, and the summary lists which.

## Output

```
output/
└── rocky9/
    ├── latest/                    # last successful build
    │   ├── build.log
    │   ├── zfs-2.4.1-1.el9.x86_64.rpm
    │   ├── zfs-dkms-2.4.1-1.el9.noarch.rpm
    │   └── ...
    ├── archive/
    │   └── 20261116-221910/       # previous successful builds
    └── failed-build.log           # only present if the most recent build failed
```

A build runs in a staging directory. Only when it succeeds is the existing `latest/` moved to `archive/<timestamp>/` and the new build promoted to `latest/`. A failed build leaves `latest/` untouched and writes `failed-build.log`.

### Packages produced

**Rocky Linux** (`make rpm-utils rpm-dkms`), named as in the official OpenZFS EL repository, e.g. `zfs-2.4.1-1.el9.x86_64.rpm`:

- `zfs` - command-line utilities and services
- `zfs-dkms` - kernel module source, built by DKMS at install time
- `libzfs7`, `libzpool7`, `libnvpair3`, `libuutil3` - shared libraries
- `libzfs7-devel` - development headers
- `zfs-dracut`, `python3-pyzfs`, `zfs-test`
- matching `-debuginfo` / `-debugsource` packages

Source RPMs are not copied to the output directory.

**Ubuntu** (`make native-deb-utils`), using the upstream native Debian packaging with Ubuntu's package names, e.g. `zfsutils-linux_2.4.1-1jammy_amd64.deb`:

- `zfsutils-linux` - command-line utilities
- `zfs-zed` - event daemon
- `zfs-dkms` - kernel module source, built by DKMS at install time
- `libzfs7linux`, `libzpool7linux`, `libnvpair3linux`, `libuutil3linux`, `libzfsbootenv1linux` - shared libraries
- `libzfslinux-dev` - development headers
- `zfs-initramfs`, `libpam-zfs`, `python3-pyzfs`, `pyzfs-doc`, `zfs-test`

The version carries the Ubuntu codename: `2.4.1-1focal` (20.04), `2.4.1-1jammy` (22.04), `2.4.1-1noble` (24.04). The build fails if any package is missing the codename or still has an upstream `openzfs-*` name.

The dracut package is dropped on Ubuntu, which uses initramfs-tools.

Library package names contain the library ABI version (`libzfs7`, `libzpool7`, ...), which changes between OpenZFS release series.

### Replacing the distribution's ZFS packages

- **Rocky Linux**: the packages have the same names as the official OpenZFS repository packages, so they upgrade an existing installation in place (`dnf install ./*.rpm`). `zfs-dkms` needs `dkms` from EPEL.
- **Ubuntu**: the packages have Ubuntu's own names and a higher version than the stock ones, so they upgrade in place with `apt install ./*.deb`, or through a normal `apt upgrade` when served from an apt repository. Packages that depend on `zfsutils-linux` keep working.

**Install `zfs-dkms` on Ubuntu.** Ubuntu kernels ship their own, older ZFS kernel module. Upgrading only the userland packages leaves that module in place, so the tools and the module would be different ZFS versions. Installing `zfs-dkms` builds the matching module.

#### How the Ubuntu names are applied

Upstream's Debian packaging names its packages `openzfs-*` (`openzfs-zfsutils`, `openzfs-libzfs7`, ...). After `./configure`, `scripts/ubuntu-package-names.py` rewrites the packaging metadata in `contrib/debian` only:

- packages are renamed (`openzfs-zfsutils` → `zfsutils-linux`, `openzfs-libzfs7` → `libzfs7linux`, `openzfs-zfs-dkms` → `zfs-dkms`, and so on; library ABI numbers are carried over automatically)
- each package declares `Conflicts`/`Replaces` on its upstream `openzfs-*` name, so a system with upstream-named packages can switch
- the changelog version and distribution get the Ubuntu codename

## Source verification

The source tarball and its detached signature are downloaded once per version into the cache directory and reused by every distribution build. Before building, the signature is verified against the OpenZFS release keys shipped in `keys/openzfs-release-keys.asc`, and the signing key's fingerprint must be one of those pinned in `build.sh`:

| Key | Fingerprint |
|---|---|
| Brian Behlendorf | `C33DF142657ED1F7C328A2960AB9E991C6AF658B` |
| Tony Hutter | `4F3BA9AB6D1F8D683DC2DFB56AD860EED4598027` |

These are the keys listed on the [OpenZFS signing keys page](https://openzfs.github.io/openzfs-docs/Project%20and%20Community/Signing%20Keys.html). A tarball that fails verification is deleted from the cache and the run stops before any build starts. The tarball's SHA256 is printed on every run.

If a future release is signed with a new key, add the key to `keys/openzfs-release-keys.asc` and its fingerprint to `TRUSTED_FINGERPRINTS` in `build.sh`.

## How the build works

```
build.sh all 2.4.1 --jobs 3
  ├─ download zfs-2.4.1.tar.gz + .asc into the cache (once)
  ├─ verify the GPG signature
  └─ for each distribution (up to 3 at a time):
       ├─ podman build   podman/Containerfile.rpm or .deb, with the base image release as a build arg
       ├─ podman run     scripts/build-rpm.sh or build-deb.sh, source tarball mounted read-only
       │    ├─ extract, ./configure
       │    ├─ (DEB only) apply Ubuntu package names and codename
       │    └─ make rpm-utils rpm-dkms   |   make native-deb-utils
       └─ on success: archive latest/, promote the new build
```

- There is one Containerfile per package type. `Containerfile.rpm` is used for all Rocky releases and `Containerfile.deb` for all Ubuntu releases; the release is selected with `--build-arg RELEASE=...`. Images are tagged `zfs-builder-<distro>:latest`.
- Base images are refreshed when a newer one is available (`--pull=newer`). Dependency layers are cached; use `--no-cache` to pick up updated build dependencies.
- Build dependencies follow the OpenZFS [Building ZFS](https://openzfs.github.io/openzfs-docs/Developer%20Resources/Building%20ZFS.html) and [Custom Packages](https://openzfs.github.io/openzfs-docs/Developer%20Resources/Custom%20Packages.html) documentation.
- For RPMs the top-level `./configure` runs with `--with-config=srpm`, since `rpmbuild` runs the full configure itself.

## Inspecting packages

```bash
rpm -qip output/rocky9/latest/zfs-2*.rpm
dpkg-deb -I output/ubuntu24/latest/zfsutils-linux_*.deb
```

## Troubleshooting

**A build failed.** The full log is in `output/<distro>/failed-build.log`. The previous successful build is still in `latest/`.

**"GPG signature verification FAILED".** The cached tarball was removed. Re-run to download it again. If it still fails, check whether the release was signed with a key that is not yet in `keys/` (see [Source verification](#source-verification)).

**"Failed to download".** Check network access to GitHub and that the version exists at <https://github.com/openzfs/zfs/releases>. Use `2.4.1`, not `v2.4.1`.

**Image build fails on a dependency error.** Distribution mirrors are occasionally out of sync. Retry later, or with `--no-cache` if a cached layer is stale.

**Out of disk space.** Check `df -h` for the output directory and for Podman's storage (`podman system df`). `make podman-clean` and `podman image prune` free image space.

**SELinux denials on the output or cache directory.** The output staging directory is mounted with `:Z` and the cache directory with `:z`, which relabel them for container access. Avoid pointing `--output-dir` or `--cache-dir` at a directory that other services rely on having its original label.

## Project structure

```
zfs-builder/
├── build.sh                      # Orchestrator: fetch, verify, build, promote
├── Makefile                      # Convenience targets
├── keys/
│   └── openzfs-release-keys.asc  # OpenZFS release signing keys
├── podman/
│   ├── Containerfile.rpm         # Rocky Linux build image (RELEASE=8|9|10)
│   └── Containerfile.deb         # Ubuntu build image (RELEASE=20.04|22.04|24.04)
└── scripts/
    ├── build-rpm.sh              # Runs inside the RPM build container
    ├── build-deb.sh              # Runs inside the DEB build container
    └── ubuntu-package-names.py   # Renames upstream DEB packages to Ubuntu's names
```

To add a distribution release, add a line to `DISTRO_INFO` and `DISTROS` in `build.sh` and to `DISTROS` in the `Makefile`.

## License

This build tooling is maintained by 45Drives. OpenZFS itself is licensed under the CDDL; see <https://github.com/openzfs/zfs>.
