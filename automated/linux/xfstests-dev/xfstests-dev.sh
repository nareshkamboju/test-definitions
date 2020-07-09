#!/bin/bash

set -x

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
# Absolute path to this script. /home/user/bin/foo.sh
SCRIPT="$(readlink -f "${0}")"
# Absolute path this script is in. /home/user/bin
SCRIPTPATH="$(dirname "${SCRIPT}")"
echo "Script path is: ${SCRIPTPATH}"
# List of test cases
TST_CMDFILES=""
# List of test cases to be skipped
SKIPFILE=""

usage() {
    echo "Usage: ${0} [-T ext4]
                      [-S skipfile-lkft]
                      [-s True|False]" 1>&2
    exit 0
}

while getopts "T:S:s:" arg; do
   case "$arg" in
     T)
        TST_CMDFILES="${OPTARG}"
        # shellcheck disable=SC2001
        LOG_FILE=$(echo "${OPTARG}"| sed 's,\/,_,')
        ;;
     S)
        if [ -z "${OPTARG##*http*}" ]; then
          # Download XFSTESTS skipfile from specified URL
          if ! wget "${OPTARG}" -O "${SKIPFILE_TMP}"; then
            error_msg "Failed to fetch ${OPTARG}"
          fi
        else
          # Regular XFSTESTS skipfile
          SKIPFILE="-S ${SCRIPTPATH}/${OPTARG}"
        fi
        ;;
     # SKIP_INSTALL is true in case of Open Embedded builds
     # SKIP_INSTALL is flase in case of Debian builds
     s) SKIP_INSTALL="${OPTARG}";;
     *)
        usage
        error_msg "No flag ${OPTARG}"
        ;;
  esac
done

# Install xfstests
install_xfstests() {
# TODO
#    rm -rf /opt/xfstests-dev
    mkdir -p /opt/xfstests-dev
    # shellcheck disable=SC2164
    cd /opt/xfstests-dev
    # shellcheck disable=SC2140
    git clone --depth 1 https://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git
    # shellcheck disable=SC2164
    cd xfstests-dev
    cp ${SCRIPTPATH}/local.config .
    make
    make install
}

# Parse xfstests output
parse_xfstests_output() {
    grep -E "PASS|FAIL|CONF"  "$1" \
        | awk '{print $1" "$2}' \
        | sed 's/PASS/pass/; s/FAIL/fail/; s/CONF/skip/'  >> "${RESULT_FILE}"
}

# Run xfstests-dev test suite
run_xfstests() {
    # shellcheck disable=SC2164
    cd "${XFSTESTS_PATH}"
    # shellcheck disable=SC2174
#    mkdir -m 777 -p "${XFSTESTS_TMPDIR}"

    pipe0_status "./check -d -b -g ${TST_CMDFILES}" "tee ${OUTPUT}/XFSTESTS_${LOG_FILE}.out"
#    check_return "xfstest_check_${LOG_FILE}"

    parse_xfstests_output "${OUTPUT}/XFSTESTS_${LOG_FILE}.log"
    # Cleanup
    # don't fail the whole test job if rm fails
    rm -rf "${XFSTESTS_TMPDIR}" || true
}

# Prepare system
prep_system() {
    # Stop systemd-timesyncd if running
    if systemctl is-active systemd-timesyncd 2>/dev/null; then
        info_msg "Stopping systemd-timesyncd"
        systemctl stop systemd-timesyncd
    fi
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

info_msg "About to run XFSTESTS test..."
info_msg "Output directory: ${OUTPUT}"

###### Remove ######
ls /opt/* || true
ls /opt/xfstests-dev || true
###### End ######

if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    info_msg "install_XFSTESTS skipped"
else
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu)
        pkgs="git xfslibs-dev uuid-dev libtool-bin e2fsprogs automake gcc libuuid1 quota attr libattr1-dev make libacl1-dev libaio-dev xfsprogs libgdbm-dev gawk fio dbench uuid-runtime python sqlite3"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      centos|fedora)
        pkgs="git acl attr automake bc dbench dump e2fsprogs fio gawk gcc indent libtool lvm2 make psmisc quota sed xfsdump xfsprogs libacl-devel libattr-devel libaio-devel libuuid-devel xfsprogs-devel btrfs-progs-devel python sqlite"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      *)
        warn_msg "Unsupported distribution: package install skipped"
    esac
fi

info_msg "Run install_xfstests"
install_xfstests
info_msg "Running prep_system"
prep_system
info_msg "Running run_xfstests"
run_xfstests
