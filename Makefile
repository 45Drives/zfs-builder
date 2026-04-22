.PHONY: help build-rocky8 build-rocky9 build-rocky10 build-ubuntu20 build-ubuntu22 build-ubuntu24 build-all clean podman-clean

# Default target
help:
	@echo "OpenZFS RPM/DEB Builder - Makefile targets"
	@echo ""
	@echo "Usage: make TARGET [VERSION=X.Y.Z]"
	@echo ""
	@echo "Rocky Linux targets:"
	@echo "  build-rocky8        Build RPM for Rocky Linux 8 (requires VERSION)"
	@echo "  build-rocky9        Build RPM for Rocky Linux 9 (requires VERSION)"
	@echo "  build-rocky10       Build RPM for Rocky Linux 10 (requires VERSION)"
	@echo ""
	@echo "Ubuntu targets:"
	@echo "  build-ubuntu20      Build DEB for Ubuntu 20.04 LTS (requires VERSION)"
	@echo "  build-ubuntu22      Build DEB for Ubuntu 22.04 LTS (requires VERSION)"
	@echo "  build-ubuntu24      Build DEB for Ubuntu 24.04 LTS (requires VERSION)"
	@echo ""
	@echo "Multi-target:"
	@echo "  build-all           Build for all supported distributions (requires VERSION)"
	@echo ""
	@echo "Maintenance:"
	@echo "  clean               Remove all output packages"
	@echo "  podman-clean        Remove all built Podman images"
	@echo ""
	@echo "Examples:"
	@echo "  make build-rocky9 VERSION=2.4.1"
	@echo "  make build-ubuntu22 VERSION=2.4.1"
	@echo "  make build-all VERSION=2.4.1"
	@echo "  make clean"
	@echo ""

# Rocky 8
build-rocky8:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required"; \
		echo "Usage: make build-rocky8 VERSION=2.4.1"; \
		exit 1; \
	fi
	@./build.sh rocky8 $(VERSION)

# Rocky 9
build-rocky9:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required"; \
		echo "Usage: make build-rocky9 VERSION=2.4.1"; \
		exit 1; \
	fi
	@./build.sh rocky9 $(VERSION)

# Rocky 10
build-rocky10:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required"; \
		echo "Usage: make build-rocky10 VERSION=2.4.1"; \
		exit 1; \
	fi
	@./build.sh rocky10 $(VERSION)

# Ubuntu 20
build-ubuntu20:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required"; \
		echo "Usage: make build-ubuntu20 VERSION=2.4.1"; \
		exit 1; \
	fi
	@./build.sh ubuntu20 $(VERSION)

# Ubuntu 22
build-ubuntu22:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required"; \
		echo "Usage: make build-ubuntu22 VERSION=2.4.1"; \
		exit 1; \
	fi
	@./build.sh ubuntu22 $(VERSION)

# Ubuntu 24
build-ubuntu24:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required"; \
		echo "Usage: make build-ubuntu24 VERSION=2.4.1"; \
		exit 1; \
	fi
	@./build.sh ubuntu24 $(VERSION)

# Build all distributions
build-all:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required"; \
		echo "Usage: make build-all VERSION=2.4.1"; \
		exit 1; \
	fi
	@./build.sh all $(VERSION)

# Remove all output packages
clean:
	@echo "Removing output packages..."
	@rm -rf output/rocky8/*.rpm output/rocky8/*.deb
	@rm -rf output/rocky9/*.rpm output/rocky9/*.deb
	@rm -rf output/rocky10/*.rpm output/rocky10/*.deb
	@rm -rf output/ubuntu20/*.rpm output/ubuntu20/*.deb
	@rm -rf output/ubuntu22/*.rpm output/ubuntu22/*.deb
	@rm -rf output/ubuntu24/*.rpm output/ubuntu24/*.deb
	@echo "✓ Cleaned output directories"

# Remove all Podman images
podman-clean:
	@echo "Removing Podman images..."
	@podman image rm zfs-builder-rocky8:latest 2>/dev/null || echo "  (zfs-builder-rocky8:latest not found)"
	@podman image rm zfs-builder-rocky9:latest 2>/dev/null || echo "  (zfs-builder-rocky9:latest not found)"
	@podman image rm zfs-builder-rocky10:latest 2>/dev/null || echo "  (zfs-builder-rocky10:latest not found)"
	@podman image rm zfs-builder-ubuntu20:latest 2>/dev/null || echo "  (zfs-builder-ubuntu20:latest not found)"
	@podman image rm zfs-builder-ubuntu22:latest 2>/dev/null || echo "  (zfs-builder-ubuntu22:latest not found)"
	@podman image rm zfs-builder-ubuntu24:latest 2>/dev/null || echo "  (zfs-builder-ubuntu24:latest not found)"
	@echo "✓ Podman images removed"
