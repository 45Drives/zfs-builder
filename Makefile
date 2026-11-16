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

DISTROS := rocky8 rocky9 rocky10 ubuntu20 ubuntu22 ubuntu24

# Per-distribution builds (build-rocky8, build-ubuntu22, ...) and build-all
$(addprefix build-,$(DISTROS) all): build-%:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required"; \
		echo "Usage: make $@ VERSION=2.4.1"; \
		exit 1; \
	fi
	@./build.sh $* $(VERSION)

# Remove all output packages (latest builds and archives)
clean:
	@echo "Removing output packages..."
	@rm -rf $(foreach d,$(DISTROS),output/$(d)/latest output/$(d)/archive)
	@echo "✓ Cleaned output directories"

# Remove all Podman images
podman-clean:
	@echo "Removing Podman images..."
	@for d in $(DISTROS); do \
		podman image rm zfs-builder-$$d:latest 2>/dev/null || echo "  (zfs-builder-$$d:latest not found)"; \
	done
	@echo "✓ Podman images removed"
