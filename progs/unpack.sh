#!/bin/bash

IMAGE="$1"
NAME="${IMAGE%.*}"

mkdir -p "$NAME/ramdisk"
unpackbootimg -i "$IMAGE" -o "$NAME"

gunzip "$NAME/$IMAGE-ramdisk.gz"

pushd "$NAME/ramdisk"
cpio -idm --no-absolute-filenames < "../$IMAGE-ramdisk"
for f in $(find . -type l)
do
  ln -sf "/$(readlink $f)" $f
done
popd

