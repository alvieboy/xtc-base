#!/bin/sh

if [ -d binutils ]; then
	echo "'binutils' folder already exists, remove it first"
        exit 255
fi

mkdir -p binutils
mkdir -p install
(
cd binutils;

../binutils-2.23.1/configure \
	--target xtc-elf \
        --prefix=$(pwd)/../install/
)
echo "Now, type 'make' inside binutils folder"
