#!/bin/bash

NAME="$1"
BASENAME=$(ls "$NAME"/*-base)
IMAGE=$(basename ${BASENAME%-*})

pushd "$NAME/ramdisk"
find . | cpio -o -H newc | gzip > "../$IMAGE-ramdisk.gz"
popd

CMDLINE=$(cat "$NAME/$IMAGE-cmdline")
BASE=$(cat "$NAME/$IMAGE-base")
PAGESIZE=$(cat "$NAME/$IMAGE-pagesize")
KERNELOFF=$(cat "$NAME/$IMAGE-kerneloff")
RAMDISKOFF=$(cat "$NAME/$IMAGE-ramdiskoff")
SECONDOFF=$(cat "$NAME/$IMAGE-secondoff")
TAGSOFF=$(cat "$NAME/$IMAGE-tagsoff")

mkbootimg \
    --kernel "$NAME/$IMAGE-zImage" \
    --ramdisk "$NAME/$IMAGE-ramdisk.gz" \
    --cmdline "$CMDLINE" \
    --base "$BASE" \
    --pagesize "$PAGESIZE" \
    --kernel_offset "$KERNELOFF" \
    --ramdisk_offset "$RAMDISKOFF" \
    --second_offset "$SECONDOFF" \
    --tags_offset "$TAGSOFF" \
    --output "repack-$NAME.img"

