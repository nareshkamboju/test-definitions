#!/bin/bash

set -x
set -e

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"

DOWNLOAD_KERNEL="https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.7.tar.xz"
TEST_PROGRAM=rteval
TEST_PROG_VERSION=
TEST_GIT_URL=https://kernel.googlesource.com/pub/scm/utils/rteval/rteval.git
TEST_DIR="$(pwd)/${TEST_PROGRAM}"
SKIP_INSTALL="false"

usage() {
	echo "\
	Usage: [sudo] ./rteval.sh [-v <TEST_PROG_VERSION>] [-u <S_URL>] [-p <S_PATH>] [-s <true|false>]

	<TEST_PROG_VERSION>:
	If this parameter is set, then the ${TEST_PROGRAM} is cloned. In
	particular, the version of the suite is set to the commit
	pointed to by the parameter. A simple choice for the value of
	the parameter is, e.g., HEAD. If, instead, the parameter is
	not set, then the suite present in TEST_DIR is used.

	<TEST_PROG_URL>:
	If this parameter is set, then the ${TEST_PROGRAM} is cloned
	from the URL in TEST_PROG_URL. Otherwise it is cloned from the
	standard repository for the suite. Note that cloning is done
	only if TEST_PROG_VERSION is not empty

	<TEST_DIR>:
	If this parameter is set, then the S suite is cloned to or
	looked for in TEST_DIR. Otherwise it is cloned to $(pwd)/${TEST_PROGRAM}

	<SKIP_INSTALL>:
	If you already have it installed into the rootfs.
	default: false"
}

while getopts "h:k:p:u:s:v:" opt; do
	case $opt in
		k)
			DOWNLOAD_KERNEL="$OPTARG"
			;;
		u)
			TEST_GIT_URL="$OPTARG"
			;;
		p)
			if [[ "$OPTARG" != '' ]]; then
				TEST_DIR="$OPTARG"
			fi
			;;
		s)
			SKIP_INSTALL="${OPTARG}"
			;;
		v)
			TEST_PROG_VERSION="$OPTARG"
			;;
		h)
			usage
			exit 0
			;;
		*)
			usage
			exit 1
			;;
	esac
done

install() {
	dist=
	dist_name
	case "${dist}" in
		debian|ubuntu)
			pkgs="curl git python3-schedutils python3-pip python3-lxml python3-libxml2 python3-ethtool python3-dmidecode"
			install_deps "${pkgs}" "${SKIP_INSTALL}"
			;;
		fedora|centos)
			pkgs="curl git-core python3-schedutils python3-pip python3-lxml"
			install_deps "${pkgs}" "${SKIP_INSTALL}"
			;;
		# When build do not have package manager
		# Assume dependencies pre-installed
		*)
			echo "Unsupported distro: ${dist}! Package installation skipped!"
			;;
	esac
	pip3 install ethtools dmidecode
}

install_rt_tests() {
	dist=
	dist_name
	case "${dist}" in
		debian|ubuntu)
			pkgs="git build-essential libnuma-dev"
			install_deps "${pkgs}" "${SKIP_INSTALL}"
			;;
		fedora|centos)
			pkgs="git-core make automake gcc gcc-c++ kernel-devel numactl-devel"
			install_deps "${pkgs}" "${SKIP_INSTALL}"
			;;
		# When build do not have package manager
		# Assume dependencies pre-installed
		*)
			echo "Unsupported distro: ${dist}! Package installation skipped!"
			;;
	esac
	git clone https://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git
	pushd rt-tests
	git checkout v1.8
	make && make install
	popd
	rm -rf rt-tests
}

get_test_program() {
	if [[ "$TEST_PROG_VERSION" != "" && ( ! -d "$TEST_DIR" || -d "$TEST_DIR"/.git ) ]];
	then
		if [[ -d "$TEST_DIR"/.git ]]; then
			echo Using repository "$PATH"
		else
			git clone "$TEST_GIT_URL" "$TEST_DIR"
		fi

		cd "$TEST_DIR" || exit 1
		if [[ "$TEST_PROG_VERSION" != "" ]]; then
			if ! git reset --hard "$TEST_PROG_VERSION"; then
				echo Failed to set ${TEST_PROGRAM} to commit "$TEST_PROG_VERSION", sorry
				exit 1
			fi
		else
			echo Using "$PATH"
		fi

	else
		if [[ ! -d "$TEST_DIR" ]]; then
			echo No ${TEST_PROGRAM} suite in "$TEST_DIR", sorry
			exit 1
		fi
		echo Assuming ${TEST_PROGRAM} is pre-installed in "$TEST_DIR"
		cd "$TEST_DIR" || exit 1
	fi
}

run_test() {

	pushd "$TEST_DIR" || exit 1
	pushd loadsource || exit 1
	curl -sSOL ${DOWNLOAD_KERNEL}
	ls
	popd
	sed -ie "s|linux-.*|$(basename ${DOWNLOAD_KERNEL})|" Makefile
	make install
	make runit EXTRA="-q"
}

! check_root && error_msg "This script must be run as root"

# Install and run test

if ! command -v cyclictest > /dev/null; then
	install_rt_tests
fi

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
	info_msg "ssuite installation skipped altogether"
else
	install
fi

get_test_program
create_out_dir "${OUTPUT}"
run_test
