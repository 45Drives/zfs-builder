#!/usr/bin/env bash

# ZFS building packages

build_zfs() {

	#Retrieve OS variables
	source /etc/os-release

	#Choose release version - 2.3.5
	#echo "ZFS Version 2.3.5"
	curl -LO https://github.com/openzfs/zfs/releases/download/zfs-2.3.5/zfs-2.3.5.tar.gz && tar -zxvf zfs-2.3.5.tar.gz
	cd zfs-2.3.5

	#Update debian packaging files
	echo "Updating preneded debian package names and content"
	for d in debian contrib/debian; do
                sed -i 's/\bopenzfs-linux\b/zfs-linux/g; s/\bopenzfs-/zfs-/g' "$d"/* || true
                for f in "$d"/openzfs-*; do [ -e "$f" ] && mv "$f" "${f/openzfs-/zfs-}"; done
        done

	#Distro check
	if [[ "$VERSION_CODENAME" == "focal" ]]; then
		sed -i 's/openzfs-linux (@VERSION@-1) unstable; urgency=low/zfs-linux (@VERSION@-1focal) focal; urgency=medium/' contrib/debian/changelog.in
	elif [[ "$VERSION_CODENAME" == "jammy" ]]; then
		sed -i 's/openzfs-linux (@VERSION@-1) unstable; urgency=low/zfs-linux (@VERSION@-1jammy) jammy; urgency=medium/' contrib/debian/changelog.in
	else
		sed -i 's/openzfs-linux (@VERSION@-1) unstable; urgency=low/zfs-linux (@VERSION@-1) unstable; urgency=low/' contrib/debian/changelog.in
	fi

	#Change remaining line to same source name
	sed -i 's/^openzfs-linux /zfs-linux /' contrib/debian/changelog.in

	#sed -i 's/openzfs-linux/zfs-linux/g' debian/control debian/control.modules.in debian/changelog

	#Installing dependencies
	echo "Installing dependencies"
	apt install -y po-debconf debhelper-compat automake libtool zlib1g-dev uuid-dev libblkid-dev libssl-dev dh-python dkms libaio-dev libcurl4-openssl-dev libelf-dev libpam0g-dev libudev-dev python3-all-dev python3-cffi python3-sphinx

	#Run autogen script
	sh autogen.sh

	#Configure
	./configure

	#Build Deb packages
	make native-deb
}
build_zfs
