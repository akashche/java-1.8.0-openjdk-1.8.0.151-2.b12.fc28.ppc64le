#!/bin/sh

  RPM_SOURCE_DIR="/home/frh/rpmbuild/SOURCES"
  RPM_BUILD_DIR="/home/frh/rpmbuild/BUILD"
  RPM_OPT_FLAGS="-O2 -g -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -specs=/usr/lib/rpm/redhat/redhat-annobin-cc1 -m64 -mcpu=power8 -mtune=power8"
  RPM_LD_FLAGS="-Wl,-z,relro -specs=/usr/lib/rpm/redhat/redhat-hardened-ld"
  RPM_ARCH="ppc64le"
  RPM_OS="linux"
  export RPM_SOURCE_DIR RPM_BUILD_DIR RPM_OPT_FLAGS RPM_LD_FLAGS RPM_ARCH RPM_OS
  RPM_DOC_DIR="/usr/share/doc"
  export RPM_DOC_DIR
  RPM_PACKAGE_NAME="java-1.8.0-openjdk"
  RPM_PACKAGE_VERSION="1.8.0.151"
  RPM_PACKAGE_RELEASE="2.b12.fc28"
  export RPM_PACKAGE_NAME RPM_PACKAGE_VERSION RPM_PACKAGE_RELEASE
  LANG=C
  export LANG
  unset CDPATH DISPLAY ||:
  RPM_BUILD_ROOT="/home/frh/rpmbuild/BUILDROOT/java-1.8.0-openjdk-1.8.0.151-2.b12.fc28.ppc64le"
  export RPM_BUILD_ROOT
  
  PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/lib64/pkgconfig:/usr/share/pkgconfig"
  export PKG_CONFIG_PATH
  CONFIG_SITE=${CONFIG_SITE:-NONE}
  export CONFIG_SITE
  
  set -x
  umask 022
  cd "/home/frh/rpmbuild/BUILD"
cd 'java-1.8.0-openjdk-1.8.0.151-2.b12.fc28.ppc64le'
# How many cpu's do we have?
export NUM_PROC=8
export NUM_PROC=${NUM_PROC:-1}

# Build IcedTea and OpenJDK.
export ARCH_DATA_MODEL=64

# We use ourcppflags because the OpenJDK build seems to
# pass EXTRA_CFLAGS to the HotSpot C++ compiler...
# Explicitly set the C++ standard as the default has changed on GCC >= 6
EXTRA_CFLAGS=""" -std=gnu++98 -Wno-error -fno-delete-null-pointer-checks -fno-lifetime-dse"
EXTRA_CPP_FLAGS=""" -std=gnu++98 -fno-delete-null-pointer-checks -fno-lifetime-dse"
# fix rpmlint warnings
EXTRA_CFLAGS="$EXTRA_CFLAGS -fno-strict-aliasing"
export EXTRA_CFLAGS

(cd openjdk/common/autoconf
 bash ./autogen.sh
)

for suffix in "" "-debug" ; do
if [ "$suffix" = ""-debug"" ] ; then
debugbuild=slowdebug
else
debugbuild=release
fi

mkdir -p openjdk/build/jdk8.build$suffix
pushd openjdk/build/jdk8.build$suffix

if [ "x$CROSSBUILD_ARCH" == "x" ] ; then exit 1; fi
set -e

NSS_LIBS=" -lfreebl" \
NSS_CFLAGS="" \
bash ../../configure \
    --openjdk-target="$CROSSBUILD_ARCH" \
    --disable-zip-debug-info \
    --with-milestone="fcs" \
    --with-update-version=151 \
    --with-build-number=b12 \
    --with-boot-jdk=/usr/lib/jvm/java-8-openjdk-amd64 \
    --with-debug-level=$debugbuild \
    --enable-unlimited-crypto \
    --disable-system-nss \
    --with-zlib=system \
    --with-libjpeg=system \
    --with-giflib=system \
    --with-libpng=system \
    --with-lcms=bundled \
    --with-stdc++lib=dynamic \
    --with-extra-cxxflags="$EXTRA_CPP_FLAGS" \
    --with-extra-cflags="$EXTRA_CFLAGS" \
    --with-extra-ldflags="""" \
    --with-num-cores=1

cat spec.gmk
cat hotspot-spec.gmk

# The combination of FULL_DEBUG_SYMBOLS=0 and ALT_OBJCOPY=/does_not_exist
# disables FDS for all build configs and reverts to pre-FDS make logic.
# STRIP_POLICY=none says don't do any stripping. DEBUG_BINARIES=true says
# ignore all the other logic about which debug options and just do '-g'.

make \
    DEBUG_BINARIES=true \
    JAVAC_FLAGS=-g \
    STRIP_POLICY=no_strip \
    POST_STRIP_CMD="" \
    LOG=trace \
    SCTP_WERROR= \
    all

#make zip-docs

# the build (erroneously) removes read permissions from some jars
# this is a regression in OpenJDK 7 (our compiler):
# http://icedtea.classpath.org/bugzilla/show_bug.cgi?id=1437
find images/j2sdk-image -iname '*.jar' -exec chmod ugo+r {} \;
chmod ugo+r images/j2sdk-image/lib/ct.sym

# remove redundant *diz and *debuginfo files
find images/j2sdk-image -iname '*.diz' -exec rm {} \;
find images/j2sdk-image -iname '*.debuginfo' -exec rm {} \;

popd >& /dev/null

# Install nss.cfg right away as we will be using the JRE above
export JAVA_HOME=$(pwd)/openjdk/build/jdk8.build$suffix/images/j2sdk-image

# Install nss.cfg right away as we will be using the JRE above
install -m 644 nss.cfg $JAVA_HOME/jre/lib/security/

# Use system-wide tzdata
#rm $JAVA_HOME/jre/lib/tzdb.dat
#ln -s /usr/share/javazi-1.8/tzdb.dat $JAVA_HOME/jre/lib/tzdb.dat

#build cycles
done

exit $?