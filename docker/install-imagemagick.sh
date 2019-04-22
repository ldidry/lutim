#!/usr/bin/env sh

# Instructions from https://imagemagick.org/script/perl-magick.php

set -eu

IM_VERSION=7.0.8-41
SHA256_DIGEST=93f73a245c25194f757c075df9f2ec40010376200cc664c21646565b8690112c

IM_DIR="ImageMagick-$IM_VERSION"
TARBALL="$IM_DIR.tar.gz"

ORIG_DIR="$(pwd)"

apk add libgomp libgcc libmagic \
        libjpeg libjpeg-turbo-dev \
        libpng libpng-dev \
        tiff tiff-dev \
        libwebp libwebp-dev

mkdir -p /tmp/im-build
cd /tmp/im-build

echo "$SHA256_DIGEST *$TARBALL" > SHA256SUM

wget https://imagemagick.org/download/$TARBALL -O $TARBALL
sha256sum -c SHA256SUM

tar xvf $TARBALL
cd $IM_DIR
./configure --with-perl --with-jpeg --with-png --with-tiff --with-webp
make -j$(nproc)
make install

ldconfig /usr/local/lib
perl -MImage::Magick -le 'print Image::Magick->QuantumDepth'

cd "$ORIG_DIR"
apk del libjpeg-turbo-dev libpng-dev tiff-dev libwebp-dev
rm -rf /tmp/im-build