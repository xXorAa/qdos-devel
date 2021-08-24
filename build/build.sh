#! /bin/sh

# install needed packages

BUILD_USER=`whoami`
if [ "$BUILD_USER" == "root" ]; then
	echo inside docker building as root
	USE_SUDO=""
else
	echo outside docker building is $BUILD_USER
	USE_SUDO="sudo"
fi

if [ "$BUILD_USER" == "root" ]; then
	apt-get update 
	apt-get install -y \
		adduser \
		autoconf \
		build-essential \
		bzip2 \
		curl \
		file \
		less \
		libbz2-dev \
		make \
		nano \
		flex \
		gawk \
		git-core \
		unzip \
		vim

	# switch to bash as default shell otherwise we have issues later
	echo "dash dash/sh boolean false" | debconf-set-selections
	DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash
fi

# build and install xtc68
mkdir xtc68
cd xtc68
git clone https://github.com/stronnag/xtc68
git clone https://github.com/xXorAa/c68-support
cd xtc68
cp ../c68-support/INCLUDE_* ../c68-support/LIB_* support/
make
$USE_SUDO bash install.sh

# apply patch to change path to qdos-gcc and install there too
patch -p1 <../../xtc68-gcc-hack.patch
make

$USE_SUDO mkdir -p /usr/local/qdos-gcc/bin

for B in as68/as68 c68/c68 cc/qcc cpp/qcpp ld/qld slb/slb slb/qdos-ar
do
	  $USE_SUDO cp -v $B /usr/local/qdos-gcc/bin/
done

$USE_SUDO mv -v /usr/local/bin/qdos-ranlib /usr/local/bin/qdos-ranlib2
$USE_SUDO cp -v ../../scripts/as /usr/local/qdos-gcc/bin/
$USE_SUDO cp -v ../../scripts/qdos-ranlib /usr/local/qdos-gcc/bin/
$USE_SUDO cp -v ../../qdos-ranlib /usr/local/bin/
$USE_SUDO mv -v /usr/local/qdos-gcc/bin/qld /usr/local/qdos-gcc/bin/ld

cd ..
cd ..
rm -rf xtc68

# create qdos-gcc directories
$USE_SUDO mkdir -p /usr/local/qdos-gcc/include
$USE_SUDO mkdir -p /usr/local/qdos-gcc/lib

# install libc headers
mkdir libc
cd libc
tar xf ../libc-4.24.5.tar.bz2
cd libc-4.24.5
patch -p1 < ../../libc.patch
$USE_SUDO make install-includes
cd ..
cd ..

mkdir gcc
cd gcc
tar xf ../gcc-core-2.95.3.tar.bz2
cd gcc-2.95.3
bzcat ../../gcc-2.95.3-bufixes.patch.bz2 | patch -p1
patch -p1 <../../gcc-patches/0001-import-qdos-gcc-patch.patch
patch -p1 <../../gcc-patches/0002-configure-alter-usr-local-qdos-to-qdos-gcc.patch
patch -p1 <../../gcc-patches/0003-texinfo-a-kludge-for-modern-gcc-and-strcpy-issue.patch

if [ "$TARGETARCH" != "" ]; then
	case $TARGETARCH in
		386)
			CFLAGS_MACH=""
			HOSTTARGET=i386-pc-linux-gnu;;
		arm)
			CFLAGS_MACH=""
			HOSTTARGET=armv7l-unknown-linux-gnu;;
		amd64)
			apt install -y gcc-multilib
			CFLAGS_MACH="-fno-builtin"
			HOSTTARGET=i386-pc-linux-gnu
			patch -p1 <../../gcc-patches/0001-Makefile.in-m32-to-build-32bit-on-x86_64.patch;;
	esac

	CFLAGS="-std=gnu89 $CFLAGS_MACH" ./configure --target=qdos --host=$HOSTTARGET
else
	BUILD_ARCH=`arch`
	CFLAGS_MACH=""
	case $BUILD_ARCH in
		x86_64)
			CFLAGS_MACH="-fno-builtin"
			HOSTTARGET="--host=i686-pc-linux-gnu"
			patch -p1 <../../gcc-patches/0001-Makefile.in-m32-to-build-32bit-on-x86_64.patch;;
	esac;

	CFLAGS="-std=gnu89 $CFLAGS_MACH" ./configure --target=qdos $HOSTTARGET
fi

# hack so we don't need ancient bison
touch gcc/c-parse.c

make
$USE_SUDO make install

cd ..
cd ..
$USE_SUDO rm -rf gcc

# run the post gcc install script
$USE_SUDO bash ./post-gcc-install

cd libc
cd libc-4.24.5
PATH=/usr/local/qdos-gcc/bin:$PATH make
$USE_SUDO make install

cd ..
cd ..
rm -rf libc

# qlzip so we can create zip files with QDOS headers

mkdir qlzip
cd qlzip
git clone https://github.com/xXorAa/qlzip.git
cd qlzip
make -f qdos/Makefile.qlzip
$USE_SUDO make -f qdos/Makefile.qlzip install

cd ..
cd ..
rm -rf qlzip

# qltools so we can create disk images
mkdir qltools
cd qltools
git clone https://github.com/SinclairQL/qltools
cd qltools/Unix
make
$USE_SUDO cp -v qltools /usr/local/bin/

cd ..
cd ..
cd ..
rm -rf qltools

