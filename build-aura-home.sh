#!/bin/sh

#board=nanopineo
board=zeropi
#board=nanopineo2
#board=orangepipc2
image_size=14384

./compile.sh docker BOARD=${board} BRANCH=current RELEASE=buster BUILD_MINIMAL=yes BUILD_DESKTOP=no KERNEL_ONLY=no KERNEL_CONFIGURE=no FIXED_IMAGE_SIZE=${image_size}
