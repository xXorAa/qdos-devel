# syntax=docker/dockerfile:1.6

FROM debian:12.4
ARG TARGETARCH

WORKDIR build
COPY build .

# Setup the base image
RUN <<EOF
    set -e

    apt-get update
    apt-get install -y \
        adduser \
        autoconf \
        build-essential \
        bzip2 \
        ca-certificates \
        curl \
        file \
        flex \
        gawk \
        git-core \
        gnupg \
        less \
        libbz2-dev \
        make \
        meson \
        nano \
        sed \
        unzip \
        vim

    # switch to bash as default shell otherwise we have issues later
    echo "dash dash/sh boolean false" | debconf-set-selections
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash
EOF

RUN <<EOF
    curl -fsSL "https://keys.openpgp.org/vks/v1/by-fingerprint/B42F6819007F00F88E364FD4036A9C25BF357DD4" | gpg --import
    curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.17/gosu-$(dpkg --print-architecture)"
    curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.17/gosu-$(dpkg --print-architecture).asc"
    gpg --verify /usr/local/bin/gosu.asc
    rm /usr/local/bin/gosu.asc
    chmod +x /usr/local/bin/gosu
EOF

# build base xtc68
RUN <<EOF
    set -e

    # build and install xtc68
    mkdir xtc68
    cd xtc68
    git clone https://github.com/stronnag/xtc68
    git clone https://github.com/xXorAa/c68-support
    cd xtc68
    cp ../c68-support/INCLUDE_* ../c68-support/LIB_* support/

    meson build --strip
    ninja install -C build

    bash ./sdk-install.sh

    rm -r build
EOF

# build modified xtc68 for qdos-gcc
RUN <<EOF
    set -e

    cd xtc68/xtc68

    # Patch for gcc and install again
    patch -p1 <../../0001-ldold-hack-to-not-use-xtc68-install-inside-gcc-build.patch
    meson build --prefix=/usr/local/qdos-gcc --strip
    ninja install -C build

    rm -r build

    mv -v /usr/local/qdos-gcc/bin/qdos-ranlib /usr/local/qdos-gcc/bin/qdos-ranlib2
    cp -v ../../scripts/as /usr/local/qdos-gcc/bin/
    cp -v ../../scripts/qdos-ranlib /usr/local/qdos-gcc/bin/
    mv -v /usr/local/qdos-gcc/bin/qld /usr/local/qdos-gcc/bin/ld

    cd ..
    cd ..
    rm -r xtc68
EOF

# Now start gcc compile
RUN <<EOF
    set -e

    # create qdos-gcc directories
    mkdir -p /usr/local/qdos-gcc/include
    mkdir -p /usr/local/qdos-gcc/lib

    # install libc headers
    mkdir libc
    cd libc
    tar xf ../libc-4.24.5.tar.bz2
    cd libc-4.24.5
    patch -p1 < ../../libc.patch
    patch -p1 < ../../0001-include-netinet-tcp.h-fix-bitfield-definitions.patch
    make install-includes
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

    echo "TARGETARCH: $TARGETARCH"

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
                HOSTTARGET=i686-pc-linux-gnu
                patch -p1 <../../gcc-patches/0001-Makefile.in-m32-to-build-32bit-on-x86_64.patch;;
        esac

        CFLAGS="-std=gnu89 $CFLAGS_MACH" ./configure --target=qdos --build=$HOSTTARGET --host=$HOSTTARGET
    fi

    # hack so we don't need ancient bison
    touch gcc/c-parse.c

    echo "Making gcc"
    make
    make install

    cd ..
    cd ..
    rm -r gcc

    # run the post gcc install script
    bash ./post-gcc-install

    cd libc
    cd libc-4.24.5
    PATH=/usr/local/qdos-gcc/bin:$PATH make
    make install

    cd ..
    cd ..
    rm -r libc
EOF

# qlzip so we can create zip files with QDOS headers
RUN <<EOF
    set -e

    mkdir qlzip
    cd qlzip
    git clone https://github.com/xXorAa/qlzip.git
    cd qlzip
    make -f qdos/Makefile.qlzip
    make -f qdos/Makefile.qlzip install

    cd ..
    cd ..
    rm -rf qlzip
EOF

# qltools so we can create disk images
RUN <<EOF
    set -e

    mkdir qltools
    cd qltools
    git clone https://github.com/SinclairQL/qltools
    cd qltools/Unix
    make
    cp -v qltools /usr/local/bin/

    cd ..
    cd ..
    cd ..
    rm -rf qltools
EOF

WORKDIR /home/user/

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

