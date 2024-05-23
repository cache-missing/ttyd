#!/bin/bash

set -euxo pipefail

CROSS_ROOT="${CROSS_ROOT:-/opt/cross}"
STAGE_ROOT="${STAGE_ROOT:-/opt/stage}"
BUILD_ROOT="${BUILD_ROOT:-/opt/build}"
TARGET="x86_64"
BUILD_DIR="${BUILD_ROOT}"
STAGE_DIR=${STAGE_ROOT}/${TARGET}

ZLIB_VERSION="1.3.1"
JSON_C_VERSION="${JSON_C_VERSION:-0.16}"
MBEDTLS_VERSION="${MBEDTLS_VERSION:-2.28.1}"
LIBUV_VERSION="${LIBUV_VERSION:-1.44.2}"
LIBWEBSOCKETS_VERSION="${LIBWEBSOCKETS_VERSION:-4.3.2}"

mkdir -p "${BUILD_ROOT}" || true

build_zlib() {
  echo "=== Building zlib-${ZLIB_VERSION} (${TARGET})..."
  curl -fSsLo- "https://www.zlib.net/zlib-${ZLIB_VERSION}.tar.gz" | tar xz -C "${BUILD_DIR}"
  pushd "${BUILD_DIR}"/zlib-"${ZLIB_VERSION}"
  env CHOST="${TARGET}" CFLAGS="-O3 -fPIC" ./configure --static --archs="-fPIC" --prefix="${STAGE_DIR}"
  make -j"$(nproc)" install
  popd
}

build_json-c() {
  echo "=== Building json-c-${JSON_C_VERSION} (${TARGET})..."
  curl -fSsLo- "https://s3.amazonaws.com/json-c_releases/releases/json-c-${JSON_C_VERSION}.tar.gz" | tar xz -C "${BUILD_DIR}"
  pushd "${BUILD_DIR}/json-c-${JSON_C_VERSION}"
  rm -rf build && mkdir -p build && cd build
  cmake -DCMAKE_BUILD_TYPE=RELEASE \
    -DCMAKE_INSTALL_PREFIX="${STAGE_DIR}" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_TESTING=OFF \
    -DDISABLE_THREAD_LOCAL_STORAGE=ON \
    ..
  make -j"$(nproc)" install
  popd
}

build_mbedtls() {
  echo "=== Building mbedtls-${MBEDTLS_VERSION} (${TARGET})..."
  curl -fSsLo- "https://github.com/ARMmbed/mbedtls/archive/v${MBEDTLS_VERSION}.tar.gz" | tar xz -C "${BUILD_DIR}"
  pushd "${BUILD_DIR}/mbedtls-${MBEDTLS_VERSION}"
  rm -rf build && mkdir -p build && cd build
  cmake -DCMAKE_BUILD_TYPE=RELEASE \
    -DCMAKE_INSTALL_PREFIX="${STAGE_DIR}" \
    -DENABLE_TESTING=OFF \
    -DCMAKE_C_FLAGS="-fPIC" \
    ..
  make -j"$(nproc)" install
  popd
}

build_libuv() {
  echo "=== Building libuv-${LIBUV_VERSION} (${TARGET})..."
  curl -fSsLo- "https://dist.libuv.org/dist/v${LIBUV_VERSION}/libuv-v${LIBUV_VERSION}.tar.gz" | tar xz -C "${BUILD_DIR}"
  pushd "${BUILD_DIR}/libuv-v${LIBUV_VERSION}"
  ./autogen.sh
  env CFLAGS=-fPIC ./configure --disable-shared --enable-static --prefix="${STAGE_DIR}"
  make -j"$(nproc)" install
  # cp include/uv/linux.h ${STAGE_DIR}/include/uv/
  popd
}

build_libwebsockets() {
  echo "=== Building libwebsockets-${LIBWEBSOCKETS_VERSION} (${TARGET})..."
  curl -fSsLo- "https://github.com/warmcat/libwebsockets/archive/v${LIBWEBSOCKETS_VERSION}.tar.gz" | tar xz -C "${BUILD_DIR}"
  pushd "${BUILD_DIR}/libwebsockets-${LIBWEBSOCKETS_VERSION}"
  sed -i 's/ websockets_shared//g' cmake/libwebsockets-config.cmake.in
  sed -i '/PC_OPENSSL/d' lib/tls/CMakeLists.txt
  rm -rf build && mkdir -p build && cd build
  cmake -DCMAKE_BUILD_TYPE=RELEASE \
    -DCMAKE_INSTALL_PREFIX="${STAGE_DIR}" \
    -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
    -DCMAKE_EXE_LINKER_FLAGS="-static" \
    -DLWS_WITHOUT_TESTAPPS=ON \
    -DLWS_WITH_MBEDTLS=ON \
    -DLWS_WITH_LIBUV=ON \
    -DLWS_STATIC_PIC=ON \
    -DLWS_WITH_SHARED=OFF \
    -DLWS_UNIX_SOCK=ON \
    -DLWS_IPV6=ON \
    -DLWS_ROLE_RAW_FILE=OFF \
    -DLWS_WITH_HTTP2=OFF \
    -DLWS_WITH_HTTP_BASIC_AUTH=OFF \
    -DLWS_WITH_UDP=OFF \
    -DLWS_WITHOUT_CLIENT=ON \
    -DLWS_WITH_LEJP=OFF \
    -DLWS_WITH_LEJP_CONF=OFF \
    -DLWS_WITH_LWSAC=OFF \
    -DLWS_WITH_SEQUENCER=OFF \
    ..
  make -j"$(nproc)" install
  popd
}

build_ttyd() {
  echo "=== Building ttyd (${TARGET})..."
  rm -rf build && mkdir -p build && cd build
  cmake -DCMAKE_INSTALL_PREFIX="${STAGE_DIR}" \
    -DCMAKE_PREFIX_PATH=/opt/stage \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=on \
    -DCMAKE_C_FLAGS="-Os -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables -flto" \
    -DCMAKE_EXE_LINKER_FLAGS="-no-pie -Wl,-s -Wl,-Bsymbolic -Wl,--gc-sections" \
    -DCMAKE_BUILD_TYPE=RELEASE \
    ..
  make -j$(nproc)
  make install
}

function main() {
  if [[ $# -eq 0 ]]; then
    build_zlib
    build_json-c
    build_mbedtls
    build_libuv
    build_libwebsockets
    build_ttyd
  else
    "$@"
  fi
}

main "$@"
