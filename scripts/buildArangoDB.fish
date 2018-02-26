#!/usr/bin/env fish
cd $INNERWORKDIR
mkdir -p .ccache.ubuntu
set -x CCACHE_DIR $INNERWORKDIR/.ccache.ubuntu
if test "$CCACHEBINPATH" = ""
  set -xg CCACHEBINPATH /usr/lib/ccache
end
ccache -M 30G
cd $INNERWORKDIR/ArangoDB

rm -rf
rm -rf build
mkdir -p build
cd build

set -l GOLD
if test "$PLATFORM" = "linux"
  set GOLD = -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=gold  -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=gold
end

cmake $argv \
      -DCMAKE_BUILD_TYPE=$BUILDTYPE \
      -DCMAKE_CXX_COMPILER=$CCACHEBINPATH/g++ \
      -DCMAKE_C_COMPILER=$CCACHEBINPATH/gcc \
      -DUSE_MAINTAINER_MODE=$MAINTAINER \
      -DUSE_ENTERPRISE=$ENTERPRISEEDITION \
      -DUSE_JEMALLOC=On \
      $GOLD \
      ..
and nice make -j$PARALLELISM
