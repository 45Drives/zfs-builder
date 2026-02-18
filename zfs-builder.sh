#!/bin/bash

# ZFS building packages

build_zfs() {

	local err

	#Retrieve OS variables
	source /etc/os-release

	#Clone ZFS repo
	echo "Cloning ZFS repo"
	git clone https://github.com/openzfs/zfs.git

	#Switch to release branch to build (2.3.5)
	cd ./zfs && git checkout zfs-2.3-5

	#Install dependencies
	echo "Installing dependencies"
	dnf install --skip-broken epel-release gcc make autoconf automake libtool rpm-build libtirpc-devel libblkid-devel libuuid-devel libudev-devel openssl-devel zlib-devel libaio-devel libattr-devel elfutils-libelf-devel kernel-devel-$(uname -r) python3 python3-devel python3-setuptools python3-cffi libffi-devel git ncompress libcurl-devel
	err=$?
        if [[ $err != 0 ]]; then
                echo "Installing dependencies failed"
                exit $err
        fi
	#Check for EL8 or EL9
	if [[ "$ID" == "rocky" ]]; then
		version=${VERSION_ID%%.*}

		if [[ "$version" == "8" ]]; then
			echo "Installing packages for EL8 Rocky"
			dnf install --skip-broken --enablerepo=epel --enablerepo=powertools python3-packaging dkms
			err=$?
        		if [[ $err != 0 ]]; then
                		echo "Installing ZFS repo failed"
                		exit $err
        		fi

		elif [[ "$version" == "9" ]]; then
			echo "Installing packages for EL9 Rocky"
			dnf config-manager --enable crb
			dnf install --skip-broken --enablerepo=epel python3-packaging dkms
			err=$?
        		if [[ $err != 0 ]]; then
		                echo "Installing ZFS repo failed"
                		exit $err
		        fi

		else
			echo "Unsupported version"
			return 1
		fi

	#Different OS
	else
		echo "Not Rocky, exiting..."
		return 1
	fi

	#Run autogen script
	sh autogen.sh

	#Configure
	./configure

	#Build packages
	make rpm
}

# Call function
build_zfs
