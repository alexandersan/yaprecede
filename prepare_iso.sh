#!/bin/bash
set -e

[ "$EUID" -ne 0 ] && echo "Please run as root or use sudo" && exit 1

BUILD="/tmp/_iso_"
CUSTOM_IMAGE="./ubuntu-custom.iso"
IMAGE=""
PRESEDE="pre.seed"
PUBLIC_KEY=""

for i in `seq 1 2 ${#@}`; do
  key=${!i}
  echo $key
  j=$((i+1))
  [ ${#@} -ge $j ] && value=${!j}
  case $key in
    -i|--image)
        IMAGE=$value
        ;;
    -b|--build-dir)
        BUILD=$value
        ;;
    -s|--seed)
        PRESEDE=$value
        ;;
    -o|--out-file)
        CUSTOM_IMAGE=$value
        ;;
    -k|--public-key)
        [ -f $value ] && PUBLIC_KEY=$(cat $value) || PUBLC_KEY=$value
        ;;
    *)
        cat << eof
This script was tested with Ubuntu 12.04 and 14.04 only.

Please specify settings:
-i|--image            Original ISO file name with path
-b|--build-dir        Temporary directory for unpacked files (default /tmp/_iso_)
-s|--seed             Seed file with path
-k|--public-key       Public SSH key for image (can be path to file or string)
-o|--out-file         File name and path for result ISO
Current settings:
Image:                $IMAGE
Custom image:         $CUSTOM_IMAGE
Build directory:      $BUILD
Presede file:         $PRESEDE
Public key:           $PUBLIC_KEY
eof
        exit 1
        ;;
  esac
done

[ ! -f $IMAGE ] && echo "ERROR No image found! Please check image path and image file name" && exit 1

# Unpack ISO
rm -rf $BUILD
mkdir -p $BUILD
echo "** Mounting image..."
mount -o loop $IMAGE_PATH/$IMAGE /mnt/
echo "** Syncing..."
rsync -av /mnt/ $BUILD/ > /dev/null 2>&1
chmod -R u+w $BUILD/

# Prepare data
echo "Fixing Language..."
echo "en" > $BUILD/isolinux/langlist
echo "Removing defaut preseed files..."
rm -f $BUILD/preseed/*
echo "Adding custom preseed file $PRESEDE ..."
cp $PRESEDE $BUILD/preseed/
echo "Adding custom root authorized_keys file..."
mkdir -p $BUILD/ssh
echo $PUBLIC_KEY > $BUILD/ssh/authorized_keys
echo "Set single default menu option for OS installation... "
cat << EOF > $BUILD/isolinux/txt.cfg
default install
label install
  menu label ^Install Ubuntu Server
  kernel /install/vmlinuz
  append  file=/cdrom/preseed/$PRESEDE initrd=/install/initrd.gz auto=true priority=critical --
EOF

echo "Set 2sec timeout for default option"
sed -i 's/timeout 0/timeout 20/' $BUILD/isolinux/isolinux.cfg

echo ">>> Calculating MD5 sums..."
rm $BUILD/md5sum.txt
(cd $BUILD/ && sudo find . -type f -print0 | xargs -0 md5sum | grep -v "boot.cat" | grep -v "md5sum.txt" > md5sum.txt)
echo ">>> Building iso image..."

mkisofs -r -V "Ubuntu OEM install" \
            -cache-inodes \
            -J -l -b isolinux/isolinux.bin \
            -c isolinux/boot.cat -no-emul-boot \
            -boot-load-size 4 -boot-info-table \
            -o $CUSTOM_IMAGE $BUILD/

umount /mnt
rm -rf $BUILD
