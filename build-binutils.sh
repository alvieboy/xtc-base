#!/bin/sh

if [ -d binutils ]; then
	echo "'binutils' folder already exists, remove it first"
        exit -1;
fi

mkdir -p binutils
mkdir -p install
cd binutils

../binutils-2.23.1/configure \
	--target xtc-elf 
        --prefix=$(pwd)/../install/
