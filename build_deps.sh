#!/usr/bin/env bash

DEPS_LOCATION=_build/deps
DESTINATION=libphonenumber

if [ -f "$DEPS_LOCATION/$DESTINATION/cpp/build/libphonenumber.a" ]; then
    echo "libphonenumber fork already exist. delete $DEPS_LOCATION/$DESTINATION for a fresh checkout."
    exit 0
fi

LIB_PHONE_NUMBER_REPO=https://github.com/googlei18n/libphonenumber.git
LIB_PHONE_NUMBER_REV=$1
OS=$(uname -s)
KERNEL=$(echo $(lsb_release -ds 2>/dev/null || cat /etc/system-release 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1 | awk '{print $1;}') | awk '{print $1;}')

echo "Use repo ${LIB_PHONE_NUMBER_REPO} and revision ${LIB_PHONE_NUMBER_REV}"
echo "OS detected: ${OS} ${KERNEL}"

function fail_check
{
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "error with $1" >&2
        exit 1
    fi
}

qmake_unix()
{
	fail_check cmake -DCMAKE_INSTALL_PREFIX:PATH=install \
                     -DUSE_BOOST=OFF \
                     -DUSE_RE2=OFF \
                     -DUSE_ICU_REGEXP=ON \
                     ..
}

qmake_darwin()
{
    ICU_PATH=/usr/local/Cellar/icu4c
    CMD_VERSION=`ls ${ICU_PATH}`
    ICU_VERSION=`echo $CMD_VERSION | awk '{print $0}'`

    echo "ICU_PATH=${ICU_PATH}"
    echo "ICU_VERSION=${ICU_VERSION}"

	fail_check cmake -DCMAKE_INSTALL_PREFIX:PATH=install \
	      -DUSE_BOOST=OFF \
	      -DUSE_RE2=OFF \
	      -DUSE_ICU_REGEXP=ON \
          -DICU_UC_INCLUDE_DIR=${ICU_PATH}/${ICU_VERSION}/include/ \
          -DICU_UC_LIB=${ICU_PATH}/${ICU_VERSION}/lib/libicuuc.dylib \
          -DICU_I18N_INCLUDE_DIR=${ICU_PATH}/${ICU_VERSION}/include/ \
          -DICU_I18N_LIB=${ICU_PATH}/${ICU_VERSION}/lib/libicui18n.dylib \
          -DGTEST_SOURCE_DIR=../../../googletest/googletest/ \
          -DGTEST_INCLUDE_DIR=../../../googletest/googletest/include/ \
    ..
}

install_libphonenumber()
{
	git clone ${LIB_PHONE_NUMBER_REPO} ${DESTINATION}
	pushd ${DESTINATION}
	fail_check git checkout ${LIB_PHONE_NUMBER_REV}
	popd

	mkdir -p ${DESTINATION}/cpp/build
	pushd ${DESTINATION}/cpp/build

    export CFLAGS="-fPIC -Wno-deprecated-declarations"
    export CXXFLAGS="-fPIC -Wno-deprecated-declarations -std=c++11"

	case $OS in
        Linux)
            qmake_unix
        ;;

        Darwin)
            qmake_darwin
        ;;

        *)
            echo "Your system $OS is not supported"
            exit 1
    esac

	fail_check make -j 8
	fail_check make install
	popd
}

copy_resources()
{
    rm -rf priv
    fail_check mkdir priv
    fail_check cp -R $DEPS_LOCATION/$DESTINATION/resources/carrier priv/carrier
}

run_installation()
{
	mkdir -p $DEPS_LOCATION
	pushd $DEPS_LOCATION

    case $OS in
      Linux)
         case $KERNEL in
            Ubuntu|Debian)
                echo "Check Dependecies for $KERNEL"
                fail_check dpkg -s  cmake cmake-curses-gui libgtest-dev libicu-dev protobuf-compiler libprotobuf-dev
                install_libphonenumber
                ;;
            CentOS|Amazon)
                echo "Check Dependecies for $KERNEL"
                fail_check rpm -q --dump cmake gtest-devel libicu-devel protobuf-compiler protobuf-devel
                install_libphonenumber
                ;;
            *)
                echo "Your system $KERNEL is not supported"
         esac
            ;;
      Darwin)
            brew install cmake pkg-config icu4c protobuf
            git clone https://github.com/google/googletest.git
            install_libphonenumber
            pushd ${DESTINATION}/cpp/build
            rm -rf *.dylib
            popd
            ;;
      *)
            echo "Your system $OS is not supported"
            exit 1
    esac

    popd
}

run_installation
copy_resources
