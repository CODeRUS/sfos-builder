keyboard us
user --name nemo --groups audio,input,video --password nemo
timezone --utc UTC
lang en_US.UTF-8

part / --fstype="btrfs" --ondisk=mmcblk0p --size=2200 --label=sailfish
btrfs / --label=root --subvol --name=@ --parent=sailfish --quota /
btrfs /home --label=/home --subvol --name=@home --parent=sailfish --quota /
btrfs /swap --label=/swap --subvol --name=@swap --parent=sailfish --quota /
btrfs  --parent=sailfish --snapshot --name=factory-@ --base=@
btrfs  --parent=sailfish --snapshot --name=factory-@home --base=@home

repo --name="adaptation0-@RELEASE@-@DEVICE_VENDOR@-@DEVICE@-@ARCH@" --baseurl=https://store-repository.jolla.com/releases/@RELEASE@/jolla-hw/adaptation-@DEVICE_VENDOR@-@DEVICE@/@ARCH@/ --ssl_verify=yes
repo --name="aliendalvik-@RELEASE@-@DEVICE@" --baseurl=https://store-repository.jolla.com/releases/@RELEASE@/aliendalvik/@PATTERN@/ --ssl_verify=yes
repo --name="apps-@RELEASE@-@ARCH@" --baseurl=https://releases.jolla.com/jolla-apps/@RELEASE@/@ARCH@/ --ssl_verify=yes
repo --name="customer-jolla-@RELEASE@-@ARCH@" --baseurl=https://releases.jolla.com/features/@RELEASE@/customers/jolla/@ARCH@/ --ssl_verify=yes
repo --name="hotfixes-@RELEASE@-@ARCH@" --baseurl=https://releases.jolla.com/releases/@RELEASE@/hotfixes/@ARCH@/ --ssl_verify=yes
repo --name="jolla-@RELEASE@-@ARCH@" --baseurl=https://releases.jolla.com/releases/@RELEASE@/jolla/@ARCH@/ --ssl_verify=yes
repo --name="sailfish-eas-@RELEASE@-@ARCH@" --baseurl=https://store-repository.jolla.com/features/@RELEASE@/sailfish-eas/@ARCH@/ --ssl_verify=yes
repo --name="xt9-@RELEASE@-@ARCH@" --baseurl=https://store-repository.jolla.com/features/@RELEASE@/xt9/@ARCH@/ --ssl_verify=yes

%packages
@Jolla Configuration @PATTERN@
feature-jolla
feature-sailfish-eas
patterns-sailfish-store-applications
qmf-eas-plugin
feature-xt9
jolla-xt9
jolla-xt9-cp
feature-alien
jolla-developer-mode
%end

%attachment
### Commands from /tmp/sandbox/usr/share/ssu/kickstart/attachment/f5121
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
if [ "armv7hl" == armv7hl ] || [ "armv7hl" == armv7tnhl ]; then
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
  DEVICE=$ID
  DEVICE_VERSION=-$VERSION_ID
fi

source ./sailfish-release
if [ "$SSU_RELEASE_TYPE" = "rnd" ]; then
  RELEASENAME=SailfishOS-${EXTRA_NAME// /_}$SAILFISH_FLAVOUR-$VERSION_ID-$DEVICE$DEVICE_VERSION
else
  RELEASENAME=SailfishOS-${EXTRA_NAME// /_}$VERSION_ID-$DEVICE$DEVICE_VERSION
fi

# Setup btrfs image
pushd $IMG_OUT_DIR

IMGNAME=sailfish.img
MD5SUMFILE=md5.lst

DEVICE=sbj

# If there is tarball then use that for the packaging, otherwise
# set default tarball name.
TARBALL=$(find *.tar.bz2 2> /dev/null)

if [[ -n "$TARBALL" ]]; then
  tar --no-same-owner -xf "$TARBALL"
  rm -f "$TARBALL"
fi

if [[ -z $(ls -1 ${IMGNAME} 2> /dev/null) ]]; then
  echo "No loop image called '${IMGNAME}' found."
  exit 1
fi

/usr/bin/img2simg_jolla -C 688M ${IMGNAME}

# Remove so that this doesn't end up to the tarball with wildcards
rm ${IMGNAME}

rm -f @EXTRA_NAME@*
FILES=$(find -type f -name "*.*")

# Calculate md5sums of files included to the tarball
md5sum $FILES > $MD5SUMFILE
FILES="$FILES $MD5SUMFILE"

mkdir -p ${RELEASENAME}
mv ${FILES} ${RELEASENAME}/

# Package stuff back to tarball
tar -cjf ${RELEASENAME}.tar.bz2 $RELEASENAME

# Remove the files from the output directory
rm -r ${RELEASENAME}

popd
### end hybris

mv $IMG_OUT_DIR/${RELEASENAME}* .
%end
