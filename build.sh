#!/bin/bash

# DEVICE=l801em DEVICE_VENDOR=mediatek ./build.sh l801em-lvm.ks
# DEVICE=p4903 ./build.sh p4903-lvm.ks
# DEVICE=l500d ./build.sh l500d-eu-lvm.ks
# DEVICE=l500d ./build.sh l500d-in-lvm.ks
# DEVICE=sbj PATTERN=SbJ ./build.sh sbj-btrfs.ks
# ARCH=i486 DEVICE=tbj DEVICE_VENDOR=intel ./build.sh tbj-lvm.ks

ARCH=${ARCH:-armv7hl}
DEVICE_VENDOR=${DEVICE_VENDOR:-qualcomm}
DEVICE=${DEVICE:-l500d}
PATTERN=${PATTERN:-${DEVICE}}
RELEASE=${RELEASE:-4.3.0.15}

FNAME="${1%.*}"
NAME="$DEVICE-$RELEASE-$FNAME"

echo "machine store-repository.jolla.com login $USERNAME password $PASSWORD" > /root/.netrc

mic -v -d \
	create loop \
	--arch=$ARCH \
	--outdir=build-$NAME \
	--tokenmap=DEVICE_VENDOR:$DEVICE_VENDOR,DEVICE:$DEVICE,PATTERN:$PATTERN,RELEASE:$RELEASE,ARCH:$ARCH,EXTRA_NAME:$FNAME \
	$1
