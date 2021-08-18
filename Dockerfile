FROM debian:10.10

RUN apt-get update && apt-get install -y adduser \
autoconf \
build-essential \
bzip2 \
curl \
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
RUN echo "dash dash/sh boolean false" | debconf-set-selections
RUN DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash

WORKDIR /xtc68
RUN git clone https://github.com/stronnag/xtc68 &&\
git clone https://github.com/xXorAa/c68-support &&\
cd xtc68 &&\
cp ../c68-support/INCLUDE_* ../c68-support/LIB_* support/ &&\
make &&\
bash install.sh

WORKDIR /bison
COPY bison-fseterr.patch .
RUN curl -O http://ftp.gnu.org/gnu/bison/bison-2.7.1.tar.xz &&\
tar xvf bison-2.7.1.tar.xz &&\
cd bison-2.7.1 &&\
patch -p1 <../bison-fseterr.patch &&\
./configure --prefix=/opt/bison/ &&\
make &&\
make install

WORKDIR /gcc-tools
COPY qdos-gcc-utils-v2.tar.bz2 .
COPY 0001-slb-Makefile-std-gnu89-for-old-style-C.patch .
COPY 0002-as68-Makefile-std-gnu89-for-old-style-C.patch .
COPY 0003-ld-Makefile-std-gnu89-for-old-style-C.patch .
COPY 0004-ld-ldold.c-check-for-libs-in-usr-local-qdos-gcc-lib.patch .
COPY 0005-scripts-as-fix-qdos-gcc-path-and-shift-issue.patch .
COPY 0006-scripts-post-gcc-install-fix-qdos-gcc-path.patch .
COPY 0007-scripts-qdos-ar-fix-qdos-gcc-path.patch .
COPY 0008-scripts-qdos-ranlib-fix-qdos-gcc-path.patch .
COPY 0009-scripts-qdos-utils-install-fix-qdos-gcc-path.patch .
COPY 0010-slb-slbanal.c-fix-incorrect-static-which-upsets-mode.patch .
RUN tar xvf qdos-gcc-utils-v2.tar.bz2 &&\
cd qdos-gcc-utils &&\
cat ../*.patch | patch -p1 &&\
make &&\
make install

WORKDIR /libc
COPY libc-4.24.5.tar.bz2 .
COPY libc.patch .
RUN tar xvf libc-4.24.5.tar.bz2 &&\
cd libc-4.24.5 &&\
patch -p1 < ../libc.patch &&\
export PATH=/usr/local/qdos-gcc/bin:$PATH &&\
make install-includes

WORKDIR /gcc
ARG TARGETARCH
COPY gcc-core-2.95.3.tar.bz2 .
COPY gcc-2.95.3-bufixes.patch.bz2 .
COPY 0001-import-qdos-gcc-patch.patch .
COPY 0002-configure-alter-usr-local-qdos-to-qdos-gcc.patch .
COPY 0003-texinfo-a-kludge-for-modern-gcc-and-strcpy-issue.patch .
RUN tar xvf gcc-core-2.95.3.tar.bz2 &&\
cd gcc-2.95.3 &&\
bzcat ../gcc-2.95.3-bufixes.patch.bz2 | patch -p1 &&\
patch -p1 < ../0001-import-qdos-gcc-patch.patch &&\
patch -p1 < ../0002-configure-alter-usr-local-qdos-to-qdos-gcc.patch &&\
patch -p1 < ../0003-texinfo-a-kludge-for-modern-gcc-and-strcpy-issue.patch &&\
case $TARGETARCH in 386) HOSTTARGET=i386-linux;; arm) HOSTTARGET=armv7l-unknown-linux-gnu;; esac &&\
CFLAGS="-std=gnu89" ./configure --target=qdos --host=$HOSTTARGET &&\
make &&\
make install

WORKDIR /gcc-tools
RUN qdos-gcc-utils/scripts/post-gcc-install

WORKDIR /libc
RUN cd libc-4.24.5 &&\
export PATH=/usr/local/qdos-gcc/bin:$PATH &&\
make &&\
make install

WORKDIR /qlzip
RUN git clone https://github.com/xXorAa/qlzip.git &&\
cd qlzip &&\
make -f qdos/Makefile.qlzip &&\
make -f qdos/Makefile.qlzip install

WORKDIR /
RUN rm -rf /bison /xtc68 /gcc /gcc-tools /qlzip /libc

RUN yes | adduser --home /qdos --shell /bin/bash --disabled-password qdos

USER qdos:qdos
WORKDIR /qdos

