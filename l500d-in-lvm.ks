timezone --utc UTC

part / --fstype="ext4" --size=2200 --label=root
part /home --fstype="ext4" --size=800 --label=home
part /fimage --fstype="ext4" --size=10 --label=fimage

repo --name="adaptation0-@RELEASE@-@DEVICE_VENDOR@-@DEVICE@-@ARCH@" --baseurl=https://store-repository.jolla.com/releases/@RELEASE@/jolla-hw/adaptation-@DEVICE_VENDOR@-@DEVICE@/@ARCH@/ --ssl_verify=yes
repo --name="adaptation1-@RELEASE@-@DEVICE_VENDOR@-@DEVICE@-@ARCH@" --baseurl=https://releases.jolla.com/releases/@RELEASE@/jolla-hw/adaptation-common/@ARCH@/ --ssl_verify=yes
repo --name="aliendalvik-@RELEASE@-@DEVICE@" --baseurl=https://store-repository.jolla.com/releases/@RELEASE@/aliendalvik/@DEVICE@/ --ssl_verify=yes
repo --name="apps-@RELEASE@-@ARCH@" --baseurl=https://releases.jolla.com/jolla-apps/@RELEASE@/@ARCH@/ --ssl_verify=yes
repo --name="customer-jolla-@RELEASE@-@ARCH@" --baseurl=https://releases.jolla.com/features/@RELEASE@/customers/jolla/@ARCH@/ --ssl_verify=yes
repo --name="hotfixes-@RELEASE@-@ARCH@" --baseurl=https://releases.jolla.com/releases/@RELEASE@/hotfixes/@ARCH@/ --ssl_verify=yes
repo --name="jolla-@RELEASE@-@ARCH@" --baseurl=https://releases.jolla.com/releases/@RELEASE@/jolla/@ARCH@/ --ssl_verify=yes
repo --name="sailfish-eas-@RELEASE@-@ARCH@" --baseurl=https://store-repository.jolla.com/features/@RELEASE@/sailfish-eas/@ARCH@/ --ssl_verify=yes
repo --name="xt9-@RELEASE@-@ARCH@" --baseurl=https://store-repository.jolla.com/features/@RELEASE@/xt9/@ARCH@/ --ssl_verify=yes

%packages
patterns-sailfish-device-configuration-@PATTERN@
feature-jolla
feature-sailfish-eas
patterns-sailfish-store-applications
qmf-eas-plugin
feature-xt9
jolla-xt9
jolla-xt9-cp
feature-alien
droid-modem-l500d-in
%end

%attachment
/boot/*
/etc/hw-release
/etc/sailfish-release
%end

%pre
export SSU_RELEASE_TYPE=release
### begin 01_init
touch $INSTALL_ROOT/.bootstrap
### end 01_init
%end

%post
export SSU_RELEASE_TYPE=release
### begin 01_arch-hack
if [ "@ARCH@" == armv7hl ] || [ "armv7hl" == armv7tnhl ]; then
    # Without this line the rpm does not get the architecture right.
    echo -n "armv7hl-meego-linux" > /etc/rpm/platform

    # Also libzypp has problems in autodetecting the architecture so we force tha as well.
    # https://bugs.meego.com/show_bug.cgi?id=11484
    echo "arch = armv7hl" >> /etc/zypp/zypp.conf
fi
### end 01_arch-hack
### begin 01_rpm-rebuilddb
# Rebuild db using target's rpm
echo -n "Rebuilding db using target rpm.."
rm -f /var/lib/rpm/__db*
rpm --rebuilddb
echo "done"
### end 01_rpm-rebuilddb
### begin 50_oneshot
# exit boostrap mode
rm -f /.bootstrap

# export some important variables until there's a better solution
export LANG=en_US.UTF-8
export LC_COLLATE=en_US.UTF-8
export GSETTINGS_BACKEND=gconf

# run the oneshot triggers for root and first user uid
UID_MIN=$(grep "^UID_MIN" /etc/login.defs |  tr -s " " | cut -d " " -f2)
DEVICEUSER=`getent passwd $UID_MIN | sed 's/:.*//'`

if [ -x /usr/bin/oneshot ]; then
   /usr/bin/oneshot --mic
   su -c "/usr/bin/oneshot --mic" $DEVICEUSER
fi
### end 50_oneshot
### begin 60_ssu
if [ "$SSU_RELEASE_TYPE" = "rnd" ]; then
    [ -n "@RNDRELEASE@" ] && ssu release -r @RNDRELEASE@
    [ -n "@RNDFLAVOUR@" ] && ssu flavour @RNDFLAVOUR@
    # RELEASE is reused in RND setups with parallel release structures
    # this makes sure that an image created from such a structure updates from there
    [ -n "@RELEASE@" ] && ssu set update-version @RELEASE@
    ssu mode 2
else
    [ -n "@RELEASE@" ] && ssu release @RELEASE@
    ssu mode 4
fi
### end 60_ssu
%end

%post --nochroot
export SSU_RELEASE_TYPE=release
### begin 50_os-release
(
CUSTOMERS=$(find $INSTALL_ROOT/usr/share/ssu/features.d -name 'customer-*.ini' \
    |xargs --no-run-if-empty sed -n 's/^name[[:space:]]*=[[:space:]]*//p')

cat $INSTALL_ROOT/etc/os-release
echo "SAILFISH_CUSTOMER=\"${CUSTOMERS//$'\n'/ }\""
) > $IMG_OUT_DIR/os-release
### end 50_os-release
### begin f5121
cp $INSTALL_ROOT/etc/sailfish-release $IMG_OUT_DIR
### end f5121
%end

%pack
export SSU_RELEASE_TYPE=release
### begin hybris
pushd $IMG_OUT_DIR

MD5SUMFILE=md5.lst

DEVICE_VERSION_FILE=./hw-release

EXTRA_NAME=""

if [ -n "@EXTRA_NAME@" ] && [ "@EXTRA_NAME@" != @"EXTRA_NAME"@ ]; then
  EXTRA_NAME="@EXTRA_NAME@-"
fi

DEVICE=""
DEVICE_VERSION=""

if [[ -a $DEVICE_VERSION_FILE ]]; then
  source $DEVICE_VERSION_FILE
  DEVICE=$MER_HA_DEVICE
  DEVICE_VERSION=-$VERSION_ID
fi

source ./sailfish-release
if [ "$SSU_RELEASE_TYPE" = "rnd" ]; then
  RELEASENAME=SailfishOS-${EXTRA_NAME// /_}$SAILFISH_FLAVOUR-$VERSION_ID-$DEVICE$DEVICE_VERSION
else
  RELEASENAME=SailfishOS-${EXTRA_NAME// /_}$VERSION_ID-$DEVICE$DEVICE_VERSION
fi

# Setup LVM image

IMGSECTORS=0
IMGBLOCKS=0
IMGSIZE=0
BLOCKSIZE=0

resizeloop() {
  local IMG=$1
  local LOOP=$(/sbin/losetup -f)
  /sbin/losetup $LOOP $IMG
  /sbin/e2fsck -f -y $LOOP

  # Get image blocks and free blocks
  local BLOCKCOUNT=$(/sbin/dumpe2fs -h $LOOP 2>&1 | grep "Block count:" | grep -o -E '[0-9]+')
  local FREEBLOCKS=$(/sbin/dumpe2fs -h $LOOP 2>&1 | grep "Free blocks:" | grep -o -E '[0-9]+')
  BLOCKSIZE=$(/sbin/dumpe2fs -h $LOOP 2>&1 | grep "Block size:" | grep -o -E '[0-9]+')
  echo "$IMG total block count: $BLOCKCOUNT - Free blocks: $FREEBLOCKS"

  local IMAGEBLOCKS=$(/usr/bin/expr $BLOCKCOUNT - $FREEBLOCKS)
  local IMAGESECTORS=$(/usr/bin/expr $IMAGEBLOCKS \* $BLOCKSIZE / 512 )

  # Shrink to minimum
  echo "Shrink $IMG to $IMAGESECTORS"
  /sbin/resize2fs $LOOP ${IMAGESECTORS}s -f

  # Get the size after resize.
  IMGBLOCKS=$(/sbin/dumpe2fs -h $LOOP 2>&1 | grep "Block count:" | grep -o -E '[0-9]+')
  IMGSIZE=$(/usr/bin/expr $IMGBLOCKS \* $BLOCKSIZE)
  IMGSECTORS=$(/usr/bin/expr $IMGBLOCKS \* $BLOCKSIZE / 512)
  echo "$IMG resized block count: $IMGBLOCKS - Block size: $BLOCKSIZE - Sectors: $IMGSECTORS - Total size: $IMGSIZE"

  /sbin/losetup -d $LOOP
}

echo "Resize root and home"

# Resize root and home to minimum
resizeloop root.img

ROOTSIZE=$IMGSIZE
ROOTBLOCKS=$IMGBLOCKS
ROOTSECTORS=$IMGSECTORS

resizeloop home.img

HOMESIZE=$IMGSIZE
HOMEBLOCKS=$IMGBLOCKS
HOMESECTORS=$IMGSECTORS

# We will add some (100M) extra to temp image.
TEMPIMGSECTORS=$(/usr/bin/expr $ROOTSECTORS + $HOMESECTORS + 200000 )

dd if=/dev/zero bs=512 count=0 of=temp.img seek=$TEMPIMGSECTORS

LVM_LOOP=$(/sbin/losetup -f)
/sbin/losetup $LVM_LOOP temp.img
/usr/sbin/pvcreate $LVM_LOOP
/usr/sbin/vgcreate sailfish $LVM_LOOP

echo "Create logical volume ROOT size: $ROOTSIZE"
/usr/sbin/lvcreate -L ${ROOTSIZE}B --name root sailfish

echo "Create logical volume HOME size: $HOMESIZE"
/usr/sbin/lvcreate -L ${HOMESIZE}B --name home sailfish

/bin/sync
/usr/sbin/vgchange -a y sailfish

dd if=root.img bs=$BLOCKSIZE count=$ROOTBLOCKS of=/dev/sailfish/root

dd if=home.img bs=$BLOCKSIZE count=$HOMEBLOCKS of=/dev/sailfish/home

/usr/sbin/vgchange -a n sailfish

pigz -7 root.img && md5sum -b root.img.gz > root.img.gz.md5&
pigz -7 home.img && md5sum -b home.img.gz > home.img.gz.md5&
wait

ROOTSIZE=$(/bin/ls -l root.img.gz | cut -d ' ' -f5)
HOMESIZE=$(/bin/ls -l home.img.gz | cut -d ' ' -f5)

# Temporary dir for making factory image backups.
FIMAGE_TEMP=$(mktemp -d -p $(pwd))

# For some reason loop files created by imager don't shrink properly when
# running resize2fs -M on them. Hence manually growing the loop file here
# to make the shrinking work once we have the image populated.
dd if=/dev/zero bs=512 seek=$(/usr/bin/expr \( $ROOTSIZE + $HOMESIZE + 100000000 \) / 512) count=1 of=fimage.img
/sbin/e2fsck -f -y fimage.img
/sbin/resize2fs -f fimage.img

mount -o loop fimage.img $FIMAGE_TEMP
mkdir -p $FIMAGE_TEMP/${RELEASENAME}
mv root.img.gz* $FIMAGE_TEMP/${RELEASENAME}
mv home.img.gz* $FIMAGE_TEMP/${RELEASENAME}
umount $FIMAGE_TEMP
rmdir $FIMAGE_TEMP

/sbin/e2fsck -f -y fimage.img
/sbin/resize2fs -f -M fimage.img

# To make the file magic right lets convert to single file sparse image.
/usr/bin/img2simg_android fimage.img fimage.img001
rm fimage.img

/sbin/losetup -d $LVM_LOOP

mv temp.img sailfish.img

/usr/bin/atruncate sailfish.img
# To make the file magic right lets convert to single file sparse image.
/usr/bin/img2simg_android sailfish.img sailfish.img001
rm sailfish.img


pigz -d *.gz
rm -f @EXTRA_NAME@*
FILES=$(find -type f -name "*.*")
md5sum $FILES > ${RELEASENAME}.md5

# Package stuff to archive
tar -cjf ${RELEASENAME}.tar.bz2 $FILES

popd
### end hybris

mv $IMG_OUT_DIR/${RELEASENAME}* .
%end
