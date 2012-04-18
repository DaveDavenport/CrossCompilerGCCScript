#!/bin/bash

##
# Script to build GCC for microblaze.
# Written by Martijn Koedam (m.l.p.j.koedam@tue.nl)
#
# Current version is testing on ubuntu 11.04, 11.10 and 12.04
##

TARGET=microblaze-xilinx-elf
PROGRAM_PREFIX=mb-

BUILD_DIR=build
INSTALL_DIR=$PWD/install 

CORES=8

GCC_URL=ftp://ftp.nluug.nl/mirror/languages/gcc/releases/gcc-4.7.0/gcc-4.7.0.tar.bz2
NEWLIB_URL=ftp://sources.redhat.com/pub/newlib/newlib-1.20.0.tar.gz
BINUTILS_URL=http://ftp.gnu.org/gnu/binutils/binutils-2.22.tar.bz2

GCC_FILE=$(basename $GCC_URL)
NEWLIB_FILE=$(basename $NEWLIB_URL)
BINUTILS_FILE=$(basename $BINUTILS_URL)

GCC=${GCC_FILE%.tar.*}
BINUTILS=${BINUTILS_FILE%.tar.*}
NEWLIB=${NEWLIB_FILE%.tar.*}



# target
# needed for newlib, because of non-standard PROGRAM_PREFIX.
export CC_FOR_TARGET="$PROGRAM_PREFIX"gcc
export CXX_FOR_TARGET="$PROGRAM_PREFIX"g++
export GCC_FOR_TARGET="$PROGRAM_PREFIX"gcc
export AR_FOR_TARGET="$PROGRAM_PREFIX"ar
export AS_FOR_TARGET="$PROGRAM_PREFIX"as
export LD_FOR_TARGET="$PROGRAM_PREFIX"ld
export NM_FOR_TARGET="$PROGRAM_PREFIX"nm
export RANLIB_FOR_TARGET="$PROGRAM_PREFIX"ranlib
export STRIP_FOR_TARGET="$PROGRAM_PREFIX"strip


function download()
{
	if [ ! -f $1 ]
	then
		wget -O $1 $2
	else
		echo "$1 exists"
	fi
}

function extract()
{
	if [ ! -d "$BUILD_DIR/$2" ]
	then
		tar  xf $1 -C $BUILD_DIR
	fi

	if [ ! -d "$BUILD_DIR/$2" ]
	then
		echo "Failed to extract $2 to $1"
		exit 1
	fi
}

function build()
{
	pushd $BUILD_DIR
	pushd $1

	if [ ! -d "build" ]
	then
		mkdir "build"
		pushd "build"
	else
		pushd "build"
		make distclean
	fi

	../configure --target=$TARGET  --prefix=/opt/mb-gcc/ --program-prefix=$PROGRAM_PREFIX --prefix=$INSTALL_DIR $2
	if [ $? != 0 ]
	then
		echo "Failed to configure"
		exit 1;
	fi
	env 
	make -j"$CORES" all$3
	if [ $? != 0 ]
	then
		echo "Failed to build"
		exit 1;
	fi
	make install$3
	if [ $? != 0 ]
	then
		echo "Failed to install"
		exit 1;
	fi

	popd
	popd
	popd
}

function gcc_dependencies()
{

	pushd $BUILD_DIR
	pushd $1
	./contrib/download_prerequisites
	popd
	popd
}

if [ ! -d $BUILD_DIR ]
then
	mkdir $BUILD_DIR
fi

if [ ! -d $INSTALL_DIR ]
then
	mkdir $INSTALL_DIR
fi


#download files.
echo "Downloading"
download "$GCC_FILE" "$GCC_URL"
download "$NEWLIB_FILE" "$NEWLIB_URL"
download "$BINUTILS_FILE" "$BINUTILS_URL"

echo "Building binutils"
extract "$BINUTILS_FILE" "$BINUTILS"
build $BINUTILS "" ""

# put results into PATH.
export PATH=$PATH:$INSTALL_DIR/bin/

echo "Building gcc-stage1"
extract "$GCC_FILE" "$GCC"
gcc_dependencies "$GCC"
build $GCC "--enable-languages=c --disable-nls --without-headers --disable-multilib --disable-libssp --with-newlib" "-host"

echo "Building newlib"
extract "$NEWLIB_FILE" "$NEWLIB"
build $NEWLIB "" ""


echo "Building gcc,g++ stage2"
extract "$GCC_FILE" "$GCC"
build $GCC "--enable-languages=c,c++ --disable-nls --without-headers --disable-multilib --disable-libssp --with-newlib" ""
