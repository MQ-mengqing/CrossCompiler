#!/bin/bash

function init() {
  echo "Clean cross-tools and builddir"
  rm ${CROSS_TOOLS} -rf
  rm ${BUILDDIR} -rf
  install -d ${CROSS_TOOLS}

  echo "Copy src to builddir"
  mkdir -p ${BUILDDIR}
  cp -r ${SRC_PATH_GCC} ${MK_PATH_GCC}
  cp -r ${SRC_PATH_BINUTILS} ${MK_PATH_BINUTILS}
  cp -r ${SRC_PATH_GLIBC} ${MK_PATH_GLIBC}

  tar -zxf ${GZ_SRC_PATH_LINUX} -C ${BUILDDIR}
  tar -zxf ${GZ_SRC_PATH_GMP} -C ${BUILDDIR}
  tar -zxf ${GZ_SRC_PATH_MPFR} -C ${BUILDDIR}
  tar -zxf ${GZ_SRC_PATH_MPC} -C ${BUILDDIR}
  tar -zxf ${GZ_SRC_PATH_ISL} -C ${BUILDDIR}
}

function final() {
  echo "Make cross-tools success!"
  echo "Cross-tools: "${CROSS_TOOLS}
  rm ${LOGFILE}
}

function mk_linux_headers() {
  echo "Linux Headers"

  pushd ${MK_PATH_LINUX} > /dev/null 2>&1
    make mrproper > /dev/null 2>&1
    make ARCH=loongarch INSTALL_HDR_PATH=dest headers_install >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Cannot make linux headers!";
      return 1;
    fi;
    find dest/include -name '.*' -delete
    mkdir -p ${SYSROOT}/usr/include
    cp -r dest/include/* ${SYSROOT}/usr/include
  popd > /dev/null 2>&1

  return 0
}

function mk_binutils() {
  echo "Binutils"

  pushd ${MK_PATH_BINUTILS} > /dev/null 2>&1
    mkdir -p build
    cd build
    rm ./* -rf
    CC=gcc AR=ar AS=as ../configure \
      --prefix=${CROSS_TOOLS} \
      --build=${CROSS_HOST} \
      --host=${CROSS_HOST} \
      --target=${CROSS_TARGET} \
      --with-sysroot=${SYSROOT} \
      --disable-nls \
      --disable-static \
      --disable-werror \
      --enable-64-bit-bfd \
      --disable-gdb \
      --disable-gdbserver \
      >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Cannot configure binutils!";
      return 1;
    fi;
    make configure-host >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Cannot make configure host binutils!";
      return 1;
    fi;
    make -j${NRJOBS} >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Make binutils failed!";
      return 1;
    fi;

    make install-strip >> ${LOGFILE} 2>&1
    cp ../include/libiberty.h ${SYSROOT}/usr/include
  popd > /dev/null 2>&1

  return 0
}

function mk_gmp_mpfr_mpc_isl() {
  echo "Gmp"

  pushd ${MK_PATH_GMP} > /dev/null 2>&1
    make clean > /dev/null 2>&1
    ./configure \
      --prefix=${CROSS_TOOLS} \
      --enable-cxx --disable-static \
      >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Cannot configure gmp!";
      return 1;
    fi;
    make -j${NRJOBS} >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Make gmp failed!!";
      return 1;
    fi;
    make install >> ${LOGFILE} 2>&1
  popd > /dev/null 2>&1

  echo "Mpfr"

  pushd ${MK_PATH_MPFR} > /dev/null 2>&1
    make clean > /dev/null 2>&1
    ./configure \
      --prefix=${CROSS_TOOLS} \
      --disable-static \
      --with-gmp=${CROSS_TOOLS} \
      >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Cannot configure mpfr!";
      return 1;
    fi;
    make -j${NRJOBS} >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Make mpfr failed!";
      return 1;
    fi;
    make install >> ${LOGFILE} 2>&1
  popd > /dev/null 2>&1

  echo "Mpc"

  pushd ${MK_PATH_MPC} > /dev/null 2>&1
    make clean > /dev/null 2>&1
    ./configure \
      --prefix=${CROSS_TOOLS} \
      --disable-static \
      --with-gmp=${CROSS_TOOLS} \
      >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Cannot configure mpc!";
      return 1;
    fi;
    make -j${NRJOBS} >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Make mpc failed!";
      return 1;
    fi;
    make install >> ${LOGFILE} 2>&1
  popd > /dev/null 2>&1

  echo "Isl"

  pushd ${MK_PATH_ISL} > /dev/null 2>&1
    make clean > /dev/null 2>&1
    ./configure \
      --prefix=${CROSS_TOOLS} \
      --disable-static \
      --with-gmp=${CROSS_TOOLS} \
      >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Cannot configure isl!";
      return 1;
    fi;
    make -j${NRJOBS} >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Make isl failed!";
      return 1;
    fi;
    make install >> ${LOGFILE} 2>&1
  popd > /dev/null 2>&1

  return 0
}

function mk_simple_gcc() {
  echo "Gcc(Simple)"

  pushd ${MK_PATH_GCC} > /dev/null 2>&1
    # cd src
    mkdir -p build
    cd build
    rm ./* -rf
    AR=ar LDFLAGS="-Wl,-rpath,${CROSS_TOOLS}/lib" ../configure \
      --prefix=${CROSS_TOOLS} \
      --build=${CROSS_HOST} \
      --host=${CROSS_HOST} \
      --target=${CROSS_TARGET} \
      --disable-nls \
      --with-mpfr=${CROSS_TOOLS} \
      --with-gmp=${CROSS_TOOLS} \
      --with-mpc=${CROSS_TOOLS} \
      --with-isl=${CROSS_TOOLS} \
      --with-newlib \
      --disable-shared \
      --with-sysroot=${SYSROOT} \
      --disable-decimal-float \
      --disable-libgomp \
      --disable-libitm \
      --disable-libsanitizer \
      --disable-libquadmath \
      --disable-threads \
      --disable-target-zlib \
      --with-system-zlib \
      --enable-checking=release \
      --enable-default-pie \
      --enable-languages=c \
      >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Cannot configure gcc(simple)!";
      return 1;
    fi;
    make all-gcc all-target-libgcc -j${NRJOBS} >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Make all-gcc all-target-libgcc failed!";
      return 1;
    fi;
    make install-strip-gcc install-strip-target-libgcc >> ${LOGFILE} 2>&1
  popd > /dev/null 2>&1

  return 0
}

function mk_glibc() {
  echo "Glibc"

  pushd ${MK_PATH_GLIBC} > /dev/null 2>&1
    mkdir -p build
    cd build
    rm ./* -rf
    BUILD_CC="gcc" \
      CC="${CROSS_TOOLS}/bin/${CROSS_TARGET}-gcc ${BUILD64}" \
      CXX="${CROSS_TOOLS}/bin/${CROSS_TARGET}-gcc ${BUILD64}" \
      AR="${CROSS_TOOLS}/bin/${CROSS_TARGET}-ar" \
      RANLIB="${CROSS_TARGET}-ranlib" \
    ../configure \
      --prefix=/usr \
      --host=${CROSS_TARGET} \
      --build=${CROSS_HOST} \
      --libdir=/usr/lib64 \
      --libexecdir=/usr/lib64/glibc \
      --with-binutils=${CROSS_TOOLS}/bin \
      --with-headers=${SYSROOT}/usr/include \
      --enable-stack-protector=strong \
      --enable-add-ons \
      --disable-werror \
      libc_cv_slibdir=/usr/lib64 \
      --enable-kernel=4.15 \
      >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Cannot configure glibc!";
      return 1;
    fi;
    make -j${NRJOBS} >> ${LOGFILE} >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Make glibc failed!";
      return 1;
    fi;
    make DESTDIR=${SYSROOT} install >> ${LOGFILE} 2>&1
    cp ../nscd/nscd.conf ${SYSROOT}/etc/nscd.conf
    mkdir -p ${SYSROOT}/var/cache/nscd
    install -Dm644 ../nscd/nscd.tmpfiles \
      ${SYSROOT}/usr/lib/tmpfiles.d/nscd.conf
    install -Dm644 ../nscd/nscd.service \
      ${SYSROOT}/usr/lib/systemd/system/nscd.service
  popd > /dev/null 2>&1

  return 0
}

function mk_gcc() {
  echo "Gcc"

  pushd ${MK_PATH_GCC} > /dev/null 2>&1
    # cd src
    mkdir -p build-all
    cd build-all
    rm ./* -rf
    AR=ar LDFLAGS="-Wl,-rpath,${CROSS_TOOLS}/lib" ../configure \
      --prefix=${CROSS_TOOLS} \
      --build=${CROSS_HOST} \
      --host=${CROSS_HOST} \
      --target=${CROSS_TARGET} \
      --with-sysroot=${SYSROOT} \
      --with-mpfr=${CROSS_TOOLS} \
      --with-gmp=${CROSS_TOOLS} \
      --with-mpc=${CROSS_TOOLS} \
      --with-isl=${CROSS_TOOLS} \
      --enable-__cxa_atexit \
      --disable-libsanitizer \
      --enable-threads=posix \
      --with-system-zlib \
      --enable-libstdcxx-time \
      --enable-checking=release \
      --enable-default-pie \
      --enable-languages=c,c++,fortran,objc,obj-c++,lto \
      >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Cannot configure gcc(all)!";
      return 1;
    fi;
    make -j${NRJOBS} >> ${LOGFILE} 2>&1
    if [ $? != 0 ]; then
      echo "[Error] Make gcc(all) failed!";
      return 1;
    fi;
    make install-strip >> ${LOGFILE} 2>&1
  popd > /dev/null 2>&1

  return 0
}

NRJOBS=16
TIME=$(date "+%Y%m%d%H%M%S")
TMP="/tmp"
SYSDIR=`pwd`
CROSS_TOOLS=${SYSDIR}/cross-tools
SYSROOT=${CROSS_TOOLS}/sysroot
BUILDDIR=${SYSDIR}/build
SRCDIR=${SYSDIR}/downloads
SRC_PATH_GCC=${SRCDIR}/gcc
SRC_PATH_BINUTILS=${SRCDIR}/binutils-gdb
SRC_PATH_GLIBC=${SRCDIR}/glibc
GZ_SRC_PATH_LINUX=${SRCDIR}/linux.tar.gz
GZ_SRC_PATH_GMP=${SRCDIR}/gmp-6.3.0.tar.gz
GZ_SRC_PATH_MPFR=${SRCDIR}/mpfr-4.2.1.tar.gz
GZ_SRC_PATH_MPC=${SRCDIR}/mpc-1.3.1.tar.gz
GZ_SRC_PATH_ISL=${SRCDIR}/isl-0.24.tar.gz
MK_PATH_LINUX=${BUILDDIR}/linux
MK_PATH_GCC=${BUILDDIR}/gcc
MK_PATH_BINUTILS=${BUILDDIR}/binutils-gdb
MK_PATH_GLIBC=${BUILDDIR}/glibc
MK_PATH_GMP=${BUILDDIR}/gmp-6.3.0
MK_PATH_MPFR=${BUILDDIR}/mpfr-4.2.1
MK_PATH_MPC=${BUILDDIR}/mpc-1.3.1
MK_PATH_ISL=${BUILDDIR}/isl-0.24

LOGFILE=${TMP}"/cross-tools."${TIME}".log"

touch ${LOGFILE}
install -d ${CROSS_TOOLS}
install -d ${SYSROOT}

LC_ALL=POSIX
CROSS_HOST="$(echo $MACHTYPE | sed "s/$(echo $MACHTYPE | cut -d- -f2)/cross/")"
CROSS_TARGET="loongarch64-unknown-linux-gnu"
MABI="lp64d"
BUILD64="-mabi=lp64d"
PATH=${SYSDIR}/cross-tools/bin:${PATH}

unset CFLAGS
unset CXXFLAGS

init
mk_linux_headers || exit
mk_binutils || exit
mk_gmp_mpfr_mpc_isl || exit
mk_simple_gcc || exit
mk_glibc || exit
mk_gcc || exit
final
