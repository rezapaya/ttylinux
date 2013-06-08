#!/bin/bash


# This file is NOT part of the kegel-initiated cross-tools software.
# This file is NOT part of the crosstool-NG software.
# This file IS part of the ttylinux xbuildtool software.
# The license which this software falls under is GPLv2 as follows:
#
# Copyright (C) 2011-2013 Douglas Jerome <douglas@ttylinux.org>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA


# *****************************************************************************
#
# PROGRAM INFORMATION
#
#	Developed by:	xbuildtool project
#	Developer:	Douglas Jerome, drj, <douglas@ttylinux.org>
#
# FILE DESCRIPTION
#
#	This shell script builds a cross-development tool chain comprised of
#	Binutils, GCC, Linux kernel header files and either GLIBC or uClibc.
#
#	User configuration parameters are in the separate configuration file
#	named "xbt-build-config.sh"; this configuration file must be in the
#	top-level xbuildtool directory when building a cross-development tool
#	chain.
#
#	The proper environment needed to run this script should be acquired by
#	sourcing a correct "xbt-build-env.sh" script.  The "xbt-build-env.sh"
#	script should be in the top-level xbuildtool directory.
#
#	EXTERNAL ENVIRONMENTAL VARIABLES
#
#		The configurations files "xbt-build-config.sh" and
#		"xbt-build-env.sh" supply the external environmental variables
#		needed to run this script.  These variables are no longer
#		listed here.
#
# CHANGE LOG
#
#	03jun13	drj	Reorganize xbuildtool files.  Scrub architecture.
#	07dec12	drj	Added cloog and ppl support.
#	05dec12	drj	Tarball file name extension (e.g. ".gz") is explicit.
#	31mar12	drj	xbt_src_get gives the actual file name.
#	27mar12	drj	Take away ".install" files from host/usr/include/.
#	27mar12	drj	Merged host lib, lib32 and lib64 directories.
#	27mar12	drj	Added continuation.
#	26mar12	drj	Added to "g" (go) and "s" (skip) xbt_debug_break.
#	25mar12	drj	Added ability to skip an md5sum check.
#	25mar12	drj	Added xbt_debug_break() for stepping through a build.
#	24mar12	drj	Before building, remove anything in the build directory.
#	18mar12	drj	Track the failed package downloads and report on them.
#	14mar12	drj	Made a better ncpus setting.
#	24feb12	drj	Remove <path>/.. from CROSS_TOOL_DIR.
#	19feb12	drj	Added text manifest of tool chain components.
#	10feb12	drj	Added the making of GCC libraries.
#	09feb12	drj	Added XBT_XSRC_DIR.
#	31jan11	drj	Moved libgcc_s.* from usr/lib to lib.
#	01jan11	drj	Re-wrote ttylinux cross-tools "generic-linux-gnu.sh".
#
# *****************************************************************************


# *************************************************************************** #
#                                                                             #
# G L O B A L   D A T A                                                       #
#                                                                             #
# *************************************************************************** #

A_ARG1=""

declare -a G_MISSED_PKG # declare indexed array
declare -a G_MISSED_URL # declare indexed array
declare -i G_NMISSING=0 # declare integer

declare -r K_BLD_CFG_FILE=xbt-build-config.sh # declare read-only
declare -r K_BLD_ENV_FILE=xbt-build-env.sh    # declare read-only
declare -r K_CACHEDIR=~/Download              # declare read-only
declare -i K_CONSOLE_FD=1                     # declare integer
declare -i K_ERR=0                            # declare integer

declare -r K_TEXT_BRED="\E[1;31m"    # bold+red    ; declare read-only
declare -r K_TEXT_BGREEN="\E[1;32m"  # bold+green  ; declare read-only
declare -r K_TEXT_BYELLOW="\E[1;33m" # bold+yellow ; declare read-only
declare -r K_TEXT_BBLUE="\E[1;34m"   # bold+blue   ; declare read-only
declare -r K_TEXT_BPURPLE="\E[1;35m" # bold+purple ; declare read-only
declare -r K_TEXT_BCYAN="\E[1;36m"   # bold+cyan   ; declare read-only
declare -r K_TEXT_BOLD="\E[1;37m"    # bold+white  ; declare read-only
declare -r K_TEXT_RED="\E[0;31m"     # red         ; declare read-only
declare -r K_TEXT_GREEN="\E[0;32m"   # green       ; declare read-only
declare -r K_TEXT_YELLOW="\E[0;33m"  # yellow      ; declare read-only
declare -r K_TEXT_BLUE="\E[0;34m"    # blue        ; declare read-only
declare -r K_TEXT_PURPLE="\E[0;35m"  # purple      ; declare read-only
declare -r K_TEXT_CYAN="\E[0;36m"    # cyan        ; declare read-only
declare -r K_TEXT_NORM="\E[0;39m"    # normal      ; declare read-only


# *************************************************************************** #
#                                                                             #
# P R O C E D U R E S                                                         #
#                                                                             #
# *************************************************************************** #


# *****************************************************************************
# build_get_file
# *****************************************************************************

# Usage: build_get_file <file_root_name> <file_name_extension> <url> [url ...]

build_get_file() {

[[ -z "${1}" ]] && return 0 || true # must have file_root_name
[[ -z "${2}" ]] && return 0 || true # must have file_name_extension
[[ -z "${3}" ]] && return 0 || true # must have url

local fileName="$1"
local fileExtn="$2"
local haveFile="no"
local loadedDn="no"
local url

# Go to the urls.
#
shift
shift

pushd "${XBT_SOURCE_DIR}" >/dev/null 2>&1

echo -n "i> Checking ${fileName} "
for ((i=(22-${#fileName}) ; i > 0 ; i--)); do echo -n "."; done

rm -f "${fileName}.download.log"

# If the file is already in ${XBT_SOURCE_DIR} then return.
#
[[ -f "${fileName}${fileExtn}" ]] && haveFile="yes" || true
if [[ "${haveFile}" == "yes" ]]; then
	echo " have it"
	popd >/dev/null 2>&1
	return 0
fi

echo -n " downloading ..... "

# See if there is a local copy of the file.
#
if [[ -f ${K_CACHEDIR}/${fileName}${fileExtn} ]]; then
	cp ${K_CACHEDIR}/${fileName}${fileExtn} .
	[[ -f "${fileName}${fileExtn}" ]] && loadedDn="yes" || true
fi
if [[ "${loadedDn}" == "yes" ]]; then
	echo "(got from local cache)"
	popd >/dev/null 2>&1
	return 0
fi

# Check if download should be skipped.  This is because it is expected to be
# in the local cache.
#
if [[ x"${1}" == x"(skip)" ]]; then
	echo "(custom: not downloadable)"
	popd >/dev/null 2>&1
	return 0
fi

# See if there is a program to use to download the file.
#
_wget=$(which wget 2>/dev/null || true)
if [[ -z "${_wget}" ]]; then
	echo "cannot find wget-- no download."
	popd >/dev/null 2>&1
	unset _wget
	return 0
fi
_wget="${_wget} -T 10 -nc --progress=dot:binary --tries=3"
_file=""

# Try to download the file from the urls.
#
rm -f "${fileName}.download.log"
>"${fileName}.download.log"
for url in "$@"; do
	_file="${url}/${fileName}${fileExtn}"
	if [[ "${loadedDn}" == "no" ]]; then
		(${_wget} --passive-ftp "${_file}" \
		|| ${_wget} "${_file}" \
		|| true) >>"${fileName}.download.log" 2>&1
		[[ -f "${fileName}${fileExtn}" ]] && loadedDn="yes" || true
	fi
done
unset _wget
unset _file

if [[ "${loadedDn}" == "yes" ]]; then
	echo "done."
	rm -f "${fileName}.download.log"
else
echo "FAILED."
	G_MISSED_PKG[${G_NMISSING}]="${fileName}${fileExtn}"
	G_MISSED_URL[${G_NMISSING}]="${url}"
	G_NMISSING=$((${G_NMISSING} + 1))
fi

popd >/dev/null 2>&1
return 0

}


# *****************************************************************************
# build_check_file
# *****************************************************************************

# Usage: build_check_file <file_root_name> <file_name_extension> <md5sum>

build_check_file() {

[[ -z "${1}" ]] && return 0 || true # must have file_root_name
[[ -z "${2}" ]] && return 0 || true # must have file_name_extension
[[ -z "${3}" ]] && return 0 || true # must have md5sum

local fileName="$1"
local fileExtn="$2"
local fileCsum="$3"
local loadedDn="no"
local chksum

pushd "${XBT_SOURCE_DIR}" >/dev/null 2>&1

# If the file is missing then report and quit. The found file name is
# stored in ${loadedDn}
#
[[ -f "${fileName}${fileExtn}" ]] && loadedDn="${fileName}${fileExtn}" || true
if [[ "${loadedDn}" == "no" ]]; then
	echo "E> Missing ${fileName} file."
	popd >/dev/null 2>&1
	return 1 # error stops the script
fi

# See if there is an expected md5sum to check against.
#
if [[ -z "${fileCsum}" ]]; then
	echo "w> No expected md5sum for ${fileName} file."
	popd >/dev/null 2>&1
	return 0
fi

# Check the md5sum and report.
#
echo -n "=> md5sum ${loadedDn} "
for ((i=(28-${#loadedDn}) ; i > 0 ; i--)); do echo -n "."; done
if [[ "${fileCsum}" == "(skip)" ]]; then
	echo " not checked"
else
	chksum=$(md5sum ${loadedDn} | awk '{print $1;}')
	if [[ "${chksum}" == "${fileCsum}" ]]; then
		echo " OK (${chksum})"
	else
		echo " MISMATCH"
		echo "=> expected ..... ${fileCsum}"
		echo "=> calculated ... ${chksum}"
		K_ERR=1
	fi
fi

popd >/dev/null 2>&1
return 0

}


# *****************************************************************************
# Copy GCC target components into the target directory.
# *****************************************************************************

build_target_adjust() {

echo "=> Adjusting cross-tool chain." >&${CONSOLE_FD}

# Setup source and destination directory paths variables.
#
src="${XBT_XHOST_DIR}/usr/${XBT_TARGET}"
dst="${XBT_XTARG_DIR}"

# Copy the GCC target libraries.
#
if [[ -d "${src}/lib" && -d "${dst}/lib" && -d "${dst}/usr/lib" ]]; then
	cp -av ${src}/lib/libgcc_s.*  ${dst}/lib
	chmod 755 ${dst}/lib/libgcc_s.so.1
	if [[ "${XBT_C_PLUS_PLUS}" == "yes" ]]; then
		cp -av ${src}/lib/libstdc++.* ${dst}/usr/lib
		cp -av ${src}/lib/libsupc++.* ${dst}/usr/lib
	fi
	rm -fv ${dst}/usr/lib/*.la
else
	_msg="Missing ${XBT_TARGET} cross-tool host/target directory(s)."
	echo "***** ${_msg}"
	echo "E> ${_msg}" >&${CONSOLE_FD}
	unset _msg
fi

# Clean the target includes
#
if [[ -d "${src}/usr/include" ]]; then
	find "${dst}/usr/include" -name "\.\.install\.cmd" -exec rm {} \;
	find "${dst}/usr/include" -name "\.install"        -exec rm {} \;
fi

# Cleanup source and destination directory paths variables.
#
unset src
unset dst

echo "=> Completed cross-tools adjustments." >&${CONSOLE_FD}

}


# *****************************************************************************
# Cross-tool User Environment Setup
# *****************************************************************************

build_usr_env_set() {

echo "#!/bin/sh"
echo ""
echo "export AR=\"\""
echo "export AS=\"\""
echo "export CC=\"\""
echo "export CPP=\"\""
echo "export CXX=\"\""
echo "export LD=\"\""
echo "export MAKE=\"make \${MAKEFLAGS}\""
echo "export NM=\"\""
echo "export OBJCOPY=\"\""
echo "export RANLIB=\"\""
echo "export SIZE=\"\""
echo "export STRIP=\"\""
echo ""
echo "export ARFLAGS=\"\""
echo "export ASFLAGS=\"\""
echo "export CFLAGS=\"\""
echo "export CPPFLAGS=\"\""
echo "export CXXFLAGS=\"\""
echo "export LDFLAGS=\"\""
echo "export MAKEFLAGS=\"\""
echo ""
echo "XBT_HOST=\"${XBT_HOST}\""
echo "XBT_TARGET=\"${XBT_TARGET}\""
echo ""
echo "XBT_AR=\"${XBT_TARGET_DIR}/host/usr/bin/${XBT_TARGET}-ar\""
echo "XBT_AS=\"${XBT_TARGET_DIR}/host/usr/bin/${XBT_TARGET}-as\""
echo "XBT_CC=\"${XBT_TARGET_DIR}/host/usr/bin/${XBT_TARGET}-gcc\""
echo "XBT_CPP=\"${XBT_TARGET_DIR}/host/usr/bin/${XBT_TARGET}-cpp\""
echo "XBT_CXX=\"${XBT_TARGET_DIR}/host/usr/bin/${XBT_TARGET}-g++\""
echo "XBT_LD=\"${XBT_TARGET_DIR}/host/usr/bin/${XBT_TARGET}-ld\""
echo "XBT_NM=\"${XBT_TARGET_DIR}/host/usr/bin/${XBT_TARGET}-nm\""
echo "XBT_OBJCOPY=\"${XBT_TARGET_DIR}/host/usr/bin/${XBT_TARGET}-objcopy\""
echo "XBT_RANLIB=\"${XBT_TARGET_DIR}/host/usr/bin/${XBT_TARGET}-ranlib\""
echo "XBT_SIZE=\"${XBT_TARGET_DIR}/host/usr/bin/${XBT_TARGET}-size\""
echo "XBT_STRIP=\"${XBT_TARGET_DIR}/host/usr/bin/${XBT_TARGET}-strip\""
echo ""
echo "XBT_BIN_PATH=\"${XBT_TARGET_DIR}/host/usr/bin\""
echo ""
echo "XBT_CFLAGS=\"${XBT_CFLAGS}\""
echo "XBT_C_PLUS_PLUS=\"${XBT_C_PLUS_PLUS}\""
echo "XBT_THREAD_MODEL=\"${XBT_THREAD_MODEL}\""

}


# *****************************************************************************
# Cross-tool User Environment Clear
# *****************************************************************************

build_usr_env_clr() {

echo "#!/bin/sh"
echo ""
echo "export AR=\"\""
echo "export AS=\"\""
echo "export CC=\"\""
echo "export CPP=\"\""
echo "export CXX=\"\""
echo "export LD=\"\""
echo "export MAKE=\"make \${MAKEFLAGS}\""
echo "export NM=\"\""
echo "export OBJCOPY=\"\""
echo "export RANLIB=\"\""
echo "export SIZE=\"\""
echo "export STRIP=\"\""
echo ""
echo "export ARFLAGS=\"\""
echo "export ASFLAGS=\"\""
echo "export CFLAGS=\"\""
echo "export CPPFLAGS=\"\""
echo "export CXXFLAGS=\"\""
echo "export LDFLAGS=\"\""
echo "export MAKEFLAGS=\"\""

}


# *************************************************************************** #
#                                                                             #
# M A I N   P R O G R A M                                                     #
#                                                                             #
# *************************************************************************** #


# *****************************************************************************
# Setup Constants and Environment
# *****************************************************************************

if [[ $# -gt 0 ]]; then A_ARG1="$1"; fi

_TB=$'\t'
_NL=$'\n'
_SP=$' '

export IFS="${_SP}${_TB}${_NL}"
export LC_ALL=POSIX
export PATH=/bin:/usr/bin:/usr/sbin

unset _TB
unset _NL
unset _SP

set -o allexport ; # Created or modified variables are exported (for subshells).
set -o errexit   ; # Exit immediately if a command exits with a non-zero status.
set -o nounset   ; # Treat unset variables as an error when substituting.

umask 022

if [ $(id -u) -eq 0 ]; then
	echo "E> Do NOT do this as root."
	exit 1
fi

set +o nounset ; # These might check an unset variable.
if [[ -n "${LD_LIBRARY_PATH}" ]]; then
	echo "E> Cannot have LD_LIBRARY_PATH set.  Unset it."
	echo "   Currently => ${LD_LIBRARY_PATH}."
	exit 1
fi
if [[ -n "${LIBRARY_PATH}" ]]; then
	echo "E> Cannot have LIBRARY_PATH set.  Unset it."
	echo "   Currently => ${LIBRARY_PATH}."
	exit 1
fi
if [[ -n "${LPATH}" ]]; then
	echo "E> Cannot have LPATH set.  Unset it."
	echo "   Currently => ${LPATH}."
	exit 1
fi
set -o nounset ; # Treat unset variables as an error when substituting.


# *****************************************************************************
# Get the Cross-tools Configuration
# *****************************************************************************

# Load the host configuration.
#
if [[ ! -f ${K_BLD_ENV_FILE} ]]; then
	echo "E> Cannot find build environment file."
	echo "   => ${K_BLD_ENV_FILE}."
	echo "E> Make sure you are in the cross-tools top-level directory."
	exit 1
fi
source ${K_BLD_ENV_FILE}

# Load the build configuration.
#
if [[ ! -f ${K_BLD_CFG_FILE} ]]; then
	echo "E> Cannot find build configuration file."
	echo "   => ${K_BLD_CFG_FILE}."
	echo "E> Make sure you are in the cross-tools top-level directory."
	exit 1
fi
source ${K_BLD_CFG_FILE}

# Get the common bash procedures.
#
source ${XBT_SCRIPT_DIR}/_functions.sh

# The K_BLD_CFG_FILE file sets these four user-specified build components:
#      1) BINUTILS
#      2) GCC
#      3) LIBC
#      4) KERNEL
# These need to be checked and "resolved" to see if the specified values are
# appropriate package versions for this cross-tool builder.  They need to be
# resolved into new variable names with associated packages and md5sum and URL
# information.  The original four variables are unset: BINUTILS, GCC, LIBC and
# KERNEL, as they are not needed after resolving to new variables.

# Resolve: BINUTILS
# Getting: XBT_BINUTILS  XBT_BINUTILS_EXT  XBT_BINUTILS_MD5SUM  XBT_BINUTILS_URL
#
source ${XBT_SCRIPT_DIR}/binutils/binutils-methods.sh
binutils_resolve_name ${BINUTILS}
unset BINUTILS

# Resolve: GCC
# Getting: XBT_GCC_LIBS  XBT_GCC_LIBS_EXT  XBT_GCC_LIBS_MD5SUM  XBT_GCC_LIBS_URL
# Getting: XBT_GCC       XBT_GCC_EXT       XBT_GCC_MD5SUM       XBT_GCC_URL
#
# The XBT_GCC_LIBS* are indexed arrays.
#
source ${XBT_SCRIPT_DIR}/gcc/gcc-methods.sh
gcc_resolve_name ${GCC}
unset GCC

# Resolve: LIBC
# Getting: XBT_LIBC ("glibc" or "uClibc")
# Getting: XBT_LIBC    XBT_LIBC_EXT    XBT_LIBC_MD5SUM    XBT_LIBC_URL
# Getting: XBT_LIBC_P  XBT_LIBC_P_EXT  XBT_LIBC_P_MD5SUM  XBT_LIBC_P_URL
#
[[ "${LIBC:0:5}" == "glibc"  ]] && _LIBC="glibc"  || true
[[ "${LIBC:0:6}" == "uClibc" ]] && _LIBC="uClibc" || true
source ${XBT_SCRIPT_DIR}/${_LIBC}/${_LIBC}-methods.sh
libc_resolve_name ${LIBC}
unset LIBC
unset _LIBC

# Resolve: LINUX
# Getting: XBT_LINUX  XBT_LINUX_EXT  XBT_LINUX_MD5SUM  XBT_LINUX_URL
#
source ${XBT_SCRIPT_DIR}/linux/linux-methods.sh
linux_resolve_name ${LINUX}
unset LINUX

# The K_BLD_CFG_FILE file sets these three user-specified target parameters:
#      1) TARGET ... Target Cross-tool Chain Name
#      2) ARCH ..... Linux Kernel Architecture
#      3) CFLAGS ... Used to Cross-compile Libc
#
# GNU uses a triplet name to specify a host or target.  The GNU triplet is the
# basis of the name a compiler tool chain.  The GNU triplet is one of these
# forms (notice the third form is a quadruplet!):
#      cpu-vendor-os
#      cpu-vendor-system
#      cpu-vendor-kernel-system
#
# xbuildtool uses the "cpu-vendor-kernel-system" form, with "-vendor-kernel-"
# always set to "-generic-linux-".  The TARGET variable below specifies the cpu
# and system part of the cpu-vendor-kernel-system e.g., TARGET=i486-gnu
# specifies the tool-chain triplet name of i486-generic-linux-gnu.
#
# These TARGET is expanded to a proper tool chain name, and new variables names
# are created; the original three variables are unset: TARGET, ARCH and CFLAGS,
# as they are not needed after resolving to new variables.

XBT_TARGET="${TARGET%-*}-generic-linux-${TARGET#*-}"
XBT_LINUX_ARCH=${ARCH}
XBT_CFLAGS=${CFLAGS}
unset TARGET
unset ARCH
unset CFLAGS

# The K_BLD_CFG_FILE file sets these user-specified cross-tool chain parameters:
#     1) C_PLUS_PLUS
#     2) THREAD_MODEL

XBT_C_PLUS_PLUS="no"
[[ "${C_PLUS_PLUS}" == "yes" ]] && XBT_C_PLUS_PLUS="yes" || true
[[ "${C_PLUS_PLUS}" == "y"   ]] && XBT_C_PLUS_PLUS="yes" || true
unset C_PLUS_PLUS

XBT_THREAD_MODEL="none"
[[ "${THREAD_MODEL}" == "nptl" ]] && XBT_THREAD_MODEL="nptl" || true
unset THREAD_MODEL

# XBT_LIBC_P may be set because GLIBC Ports is available, but it is not used
# for all architectures.
#
[[ "${XBT_LINUX_ARCH}" == "powerpc" ]] && XBT_LIBC_P="" || true
[[ "${XBT_LINUX_ARCH}" == "i386"    ]] && XBT_LIBC_P="" || true
[[ "${XBT_LINUX_ARCH}" == "x86_64"  ]] && XBT_LIBC_P="" || true

# Report on what we think we are doing.
#
_gccLibs="${XBT_GCC_LIBS[@]}"
_libc_p="${XBT_LIBC_P:-}"
echo ""
echo "xbuildtool configured for cross-development tool chain:"
echo ""
echo "  Host: ${XBT_HOST}"
echo "Target: ${XBT_TARGET}"
echo " Tools: ${XBT_BINUTILS} ${XBT_GCC}"
echo " Tools: [${_gccLibs// /, }]"
echo "  Libc: ${XBT_LIBC} ${_libc_p}"
echo " Linux: ${XBT_LINUX_ARCH} ${XBT_LINUX}"
echo ""
echo "=> build gcc with c++: ${XBT_C_PLUS_PLUS}"
echo "=>   use thread model: ${XBT_THREAD_MODEL}"
echo ""
unset _gccLibs
unset _libc_p


# *****************************************************************************
# Check for the "clean" Option
# *****************************************************************************

# The K_BLD_CFG_FILE file sets this cross-tool chain parameter: CROSS_TOOL_DIR
#
# CROSS_TOOL_DIR is a directory path; it is relative to the current directory,
# the top-level cross-tools directory.  The resulting directory path is where
# the new directory for the cross-development tool chain is or was created.

if [[ x"${A_ARG1}" == x"clean" ]]; then
	read -p "Remove ${XBT_TARGET} cross-tool chain. (y|n) [n]>"
	if [[ x"${REPLY:0:1}" == x"y" ]]; then
		echo -n "Removing ... "
		rm -rf "${XBT_DIR}/${CROSS_TOOL_DIR}/${XBT_TARGET}"
		echo "done"
	else
		echo "Nothing removed."
	fi
	echo ""
	exit 0
fi


# *****************************************************************************
# Get and Check the Packages
# *****************************************************************************

echo "i> Getting source code packages [be patient, this will not lock up]."
echo "i> Local cache directory: ${K_CACHEDIR}"

build_get_file "${XBT_BINUTILS}" "${XBT_BINUTILS_EXT}" ${XBT_BINUTILS_URL}
for ((_i=0 ; _i < ${#XBT_GCC_LIBS[@]} ; _i++)); do
	build_get_file				\
		"${XBT_GCC_LIBS[$_i]}"		\
		"${XBT_GCC_LIBS_EXT[$_i]}"	\
		${XBT_GCC_LIBS_URL[$_i]}
done; unset _i
build_get_file "${XBT_GCC}"    "${XBT_GCC_EXT}"    ${XBT_GCC_URL}
build_get_file "${XBT_LIBC}"   "${XBT_LIBC_EXT}"   ${XBT_LIBC_URL}
build_get_file "${XBT_LIBC_P}" "${XBT_LIBC_P_EXT}" ${XBT_LIBC_P_URL}
build_get_file "${XBT_LINUX}"  "${XBT_LINUX_EXT}"  ${XBT_LINUX_URL}

if [[ ${G_NMISSING} != 0 ]]; then
	echo "Oops -- missing ${G_NMISSING} packages."
	echo ""
	echo -e "${K_TEXT_BRED}Error${K_TEXT_NORM}:"
	echo "At least one source package failed to download.  If all source   "
	echo "packages failed to download then check your Internet access.     "
	echo "Listed below are the missing source package name(s) and the last "
	echo "URL used to find the package.  Likely failure possibilities are: "
	echo "=> The URL is wrong, maybe it has changed.                       "
	echo "=> The source package name is no longer at the URL, maybe the    "
	echo "   version name has changed at the URL.                          "
	echo ""
	echo "You can use your web browser to look for the package, and maybe  "
	echo "use Google to look for an alternate site hosting the source,     "
	echo "package, or you can download a ttylinux source distribution ISO  "
	echo "that has the relevant source packages from http://ttylinux.net/  "
	echo "-- remember, the architecture or CPU in the ttylinux source ISO  "
	echo "   name does not matter, as the source packages are just source  "
	echo "   code for any supported architecture."
	echo ""
	while [[ ${G_NMISSING} > 0 ]]; do
		G_NMISSING=$((${G_NMISSING} - 1))
		echo ${G_MISSED_PKG[${G_NMISSING}]}
		echo ${G_MISSED_URL[${G_NMISSING}]}
		unset G_MISSED_PKG[${G_NMISSING}]
		unset G_MISSED_URL[${G_NMISSING}]
		if [[ ${G_NMISSING} != 0 ]]; then
			echo -e "${K_TEXT_BBLUE}-----${K_TEXT_NORM}"
		fi
	done
	unset G_NMISSING
	echo ""
fi

K_ERR=0 # Expect build_check_file() to set K_ERR=1 on error.

build_check_file "${XBT_BINUTILS}" ${XBT_BINUTILS_EXT} ${XBT_BINUTILS_MD5SUM}
for ((_i=0 ; _i < ${#XBT_GCC_LIBS[@]} ; _i++)); do
	build_check_file				\
		${XBT_GCC_LIBS[$_i]}		\
		${XBT_GCC_LIBS_EXT[$_i]}	\
		${XBT_GCC_LIBS_MD5SUM[$_i]}
done; unset _i
build_check_file "${XBT_GCC}"    "${XBT_GCC_EXT}"    ${XBT_GCC_MD5SUM}
build_check_file "${XBT_LIBC}"   "${XBT_LIBC_EXT}"   ${XBT_LIBC_MD5SUM}
build_check_file "${XBT_LIBC_P}" "${XBT_LIBC_P_EXT}" ${XBT_LIBC_P_MD5SUM}
build_check_file "${XBT_LINUX}"  "${XBT_LINUX_EXT}"  ${XBT_LINUX_MD5SUM}

if [[ ${K_ERR} -eq 1 ]]; then
	_dir=$(basename ${XBT_SOURCE_DIR})
	echo "E> File md5sum error."
	echo "E> Remove the bad file(s) from the ${_dir} directory."
	unset _dir
	exit 1
fi

if [[ x"${A_ARG1}" == x"download" ]]; then
	echo ""
	exit 0
fi


# *****************************************************************************
# Miscellaneous Setup for Building a Cross-development Tool Chain
# *****************************************************************************

# Cross-toolset Directory
# This directory will be created under the cross-tools top-level directory.
#
XBT_TOOL_DIR="${XBT_TARGET}" # Make this directory be the name of the target
                             # type e.g., "i486-generic-linux-gnu".

# Avoid inheriting build tool baggage.  Allow no inadvertent host-oriented
# commands or flags.
#
export GREP_OPTIONS="" # Something in some package build doesn'tlike this set.
#
export ARFLAGS=""
export ASFLAGS=""
export CFLAGS=""
export CPPFLAGS=""
export CXXFLAGS=""
export LDFLAGS=""
export MAKEFLAGS=""
#
export AR=""
export AS=""
export CC=""
export CPP=""
export CXX=""
export LD=""
export MAKE="make ${MAKEFLAGS}"
export RANLIB=""
export SIZE=""
export STRIP=""

# Set ${ncpus} to 1 if it is undefined. Check for non-digits in ${ncpus}; if
# any are found then use the number 1.
#
ncpus=${ncpus:-1}
[[ -z "${ncpus//[0-9]}" ]] && ncpus=1

# Setup the bin-link in PATH
#
export PATH=${XBT_BINLINK_DIR}:/bin:/usr/bin:/sbin:/usr/sbin

# The K_BLD_CFG_FILE file sets this cross-tool chain parameter: CROSS_TOOL_DIR
#
# CROSS_TOOL_DIR is a directory path; it is relative to the current directory,
# the top-level cross-tools directory.  The resulting directory path is where
# the new directory for the cross-development tool chain is created; the new
# cross-development tool chain directory is set in the XBT_TARGET_DIR variable.

XBT_TARGET_DIR="${XBT_DIR}/${CROSS_TOOL_DIR}/${XBT_TOOL_DIR}"
unset CROSS_TOOL_DIR # All done with this variable.

# Scrub any <dir>/.. from the XBT_TARGET_DIR path:
_pathParts=(${XBT_TARGET_DIR//\// })
_newTargetPath=""
for ((_i=1 ; _i < ${#_pathParts[@]} ; _i++)); do
	_l=$_i
	if [[ "${_pathParts[$_i]}" == ".." ]]; then
		_i=$(($_i + 1))
	else
		_j=$(($_i - 1))
		_newTargetPath=${_newTargetPath}/${_pathParts[$_j]}
	fi
done
XBT_TARGET_DIR="${_newTargetPath}/${_pathParts[$_l]}"
unset _pathParts
unset _newTargetPath
unset _i
unset _j
unset _l

XBT_XSRC_DIR="${XBT_TARGET_DIR}/_pkg-src"
XBT_TARGET_MANIFEST="${XBT_TARGET_DIR}/_pkg-src/_manifest.txt"
XBT_TOOLCHAIN_MANIFEST="${XBT_TARGET_DIR}/_manifest.txt"
XBT_XHOST_DIR="${XBT_TARGET_DIR}/host"
XBT_XTARG_DIR="${XBT_TARGET_DIR}/target"

if [[ -d "${XBT_TARGET_DIR}" && x"${A_ARG1}" != x"continue" ]]; then
	echo ""
	echo "E> The ${XBT_TOOL_DIR} cross-tool directory already exists."
	echo "=> \${XBT_DIR}/\${CROSS_TOOL_DIR}/${XBT_TOOL_DIR}"
	echo "E> Cowardly quiting."
	exit 1
fi

# That was the last chance to stop before actually making anything.
#
# All OK, so begin assaulting the file system with a new cross-development tool
# chain directory and begin building it.


# *****************************************************************************
# Setup New Cross-development Tool Chain Directory
# *****************************************************************************

# Setup the cross-tool chain directory structure.
#
if [[ ! -d "${XBT_TARGET_DIR}" || x"${A_ARG1}" != x"continue" ]]; then

	echo ""
	echo -n "Making toolchain directory structure ... "

	# Make the directories and empty manifest files.

	mkdir -p "${XBT_TARGET_DIR}"
	mkdir -p "${XBT_XSRC_DIR}"
	mkdir -p "${XBT_XHOST_DIR}"
	mkdir -p "${XBT_XTARG_DIR}"
	>"${XBT_TARGET_MANIFEST}"
	>"${XBT_TOOLCHAIN_MANIFEST}"

	mkdir -p "${XBT_XHOST_DIR}/usr/lib"
	mkdir -p "${XBT_XHOST_DIR}/usr/${XBT_TARGET}/lib"
	ln -sf lib "${XBT_XHOST_DIR}/usr/lib32"
	ln -sf lib "${XBT_XHOST_DIR}/usr/lib64"
	ln -sf lib "${XBT_XHOST_DIR}/usr/${XBT_TARGET}/lib32"
	ln -sf lib "${XBT_XHOST_DIR}/usr/${XBT_TARGET}/lib64"

	rm --force "${XBT_TARGET_DIR}"/.done.*

	# Make the cross-build environment definition files for the cross
	# toolchain users.

	_versFile="${XBT_TARGET_DIR}/_versions"
	rm -f "${_versFile}"
	echo "#!/bin/sh"                             >>"${_versFile}"
	echo "XBT_LINUX_ARCH=\"${XBT_LINUX_ARCH}\""  >>"${_versFile}"
	echo "XBT_LINUX_VER=\"${XBT_LINUX}\""        >>"${_versFile}"
	echo "XBT_LIBC_VER=\"${XBT_LIBC}\""          >>"${_versFile}"
	echo "XBT_XBINUTILS_VER=\"${XBT_BINUTILS}\"" >>"${_versFile}"
	echo "XBT_XGCC_VER=\"${XBT_GCC}\""           >>"${_versFile}"
	chmod 755 "${_versFile}"
	unset _versFile

	rm -f "${XBT_TARGET_DIR}/_xbt_env_set"
	build_usr_env_set >>${XBT_TARGET_DIR}/_xbt_env_set
	chmod 755 "${XBT_TARGET_DIR}/_xbt_env_set"

	rm -f "${XBT_TARGET_DIR}/_xbt_env_clr"
	build_usr_env_clr >>${XBT_TARGET_DIR}/_xbt_env_clr
	chmod 755 "${XBT_TARGET_DIR}/_xbt_env_clr"

	echo "done."
	echo "=> ${XBT_TARGET_DIR}"
	echo ""
	if $(tree pkg-src >/dev/null) ; then
		_treeCmd="tree -ACF ${XBT_TARGET_DIR}"
		${_treeCmd} | sed -e "s|${XBT_TARGET_DIR}|${XBT_TARGET}|"
		unset _treeCmd
	fi

fi

echo ""


# *****************************************************************************
# Build New Cross-development Tool Chain
# *****************************************************************************

t1=${SECONDS}

exec 4>&1    # Save stdout at fd 4.
CONSOLE_FD=4 #

set +o errexit ; # Let a build step fail without exiting this script.

# Use a subshell so the current working directory can be changed and shell
# variables can be assaulted without affecting this script.

(
cd ${XBT_BUILD_DIR}
rm --force --recursive *

# Build continuation is made by using the ${XBT_TARGET_DIR}/.done.* files; this
# needs to be done here and not in the build procedures in order to avoid
# whacking the log files.

# Get the Linux kernel headers.
#
if [[ ! -f "${XBT_TARGET_DIR}/.done.kernel_headers" ]]; then
	linux_headers_export >${XBT_TARGET_DIR}/_log.0.kernel_headers 2>&1
	touch "${XBT_TARGET_DIR}/.done.kernel_headers"
else
	_msg="Getting ${XBT_LINUX} Headers "
	echo -n "${_msg}"          >&${CONSOLE_FD}
	xbt_print_dots_40 ${#_msg} >&${CONSOLE_FD}
	echo    " already done"    >&${CONSOLE_FD}
	unset _msg
fi

# Build binutils.
#
if [[ ! -f "${XBT_TARGET_DIR}/.done.binutils" ]]; then
	binutils_build >${XBT_TARGET_DIR}/_log.2.binutils 2>&1
	touch "${XBT_TARGET_DIR}/.done.binutils"
else
	_msg="Building ${XBT_BINUTILS} "
	echo -n "${_msg}"          >&${CONSOLE_FD}
	xbt_print_dots_40 ${#_msg} >&${CONSOLE_FD}
	echo    " already done"    >&${CONSOLE_FD}
	unset _msg
fi

# Build the host libraries that gcc needs.
#
# Some of these libraries have dependencies upon the others.  They are built in
# the order in which they are found in the XBT_GCC_LIBS indexed array.
#
_i=0; for _lib in ${XBT_GCC_LIBS[@]}; do
	_lib=${_lib%-*} # strip version: make "name-d.d.d" be "name"
	if [[ ! -f "${XBT_TARGET_DIR}/.done.gcc_lib_${_lib}" ]]; then
		gcc_lib_${_lib}_build ${_i} \
				>${XBT_TARGET_DIR}/_log.3.gcc_lib_${_lib} 2>&1
		touch "${XBT_TARGET_DIR}/.done.gcc_lib_${_lib}"
	else
		_msg="Building ${XBT_GCC_LIBS[$_i]} "
		echo -n "${_msg}"          >&${CONSOLE_FD}
		xbt_print_dots_40 ${#_msg} >&${CONSOLE_FD}
		echo    " already done"    >&${CONSOLE_FD}
		unset _msg
	fi
	_i=$(($_i + 1))
done; unset _i; unset _lib

if [[ ! -f "${XBT_TARGET_DIR}/.done.gcc_stage1" ]]; then
	gcc_stage1_build >${XBT_TARGET_DIR}/_log.4.gcc_stage1 2>&1
	touch "${XBT_TARGET_DIR}/.done.gcc_stage1"
else
	_msg="Building ${XBT_GCC} Stage 1 "
	echo -n "${_msg}"          >&${CONSOLE_FD}
	xbt_print_dots_40 ${#_msg} >&${CONSOLE_FD}
	echo    " already done"    >&${CONSOLE_FD}
	unset _msg
fi

if [[ ! -f "${XBT_TARGET_DIR}/.done.libc_stage1" ]]; then
        libc_stage1_build >${XBT_TARGET_DIR}/_log.5.libc_stage1 2>&1
        touch "${XBT_TARGET_DIR}/.done.libc_stage1"
else
	_msg="Building ${XBT_LIBC} Stage 1 "
	echo -n "${_msg}"          >&${CONSOLE_FD}
	xbt_print_dots_40 ${#_msg} >&${CONSOLE_FD}
	echo    " already done"    >&${CONSOLE_FD}
	unset _msg
fi

if [[ ! -f "${XBT_TARGET_DIR}/.done.gcc_stage2" ]]; then
        gcc_stage2_build >${XBT_TARGET_DIR}/_log.6.gcc_stage2 2>&1
        touch "${XBT_TARGET_DIR}/.done.gcc_stage2"
else
	_msg="Building ${XBT_GCC} Stage 2 "
	echo -n "${_msg}"          >&${CONSOLE_FD}
	xbt_print_dots_40 ${#_msg} >&${CONSOLE_FD}
	echo    " already done"    >&${CONSOLE_FD}
	unset _msg
fi

if [[ ! -f "${XBT_TARGET_DIR}/.done.libc_stage2" ]]; then
        libc_stage2_build >${XBT_TARGET_DIR}/_log.7.libc_stage2 2>&1
        touch "${XBT_TARGET_DIR}/.done.libc_stage2"
else
	_msg="Building ${XBT_LIBC} Stage 2 "
	echo -n "${_msg}"          >&${CONSOLE_FD}
	xbt_print_dots_40 ${#_msg} >&${CONSOLE_FD}
	echo    " already done"    >&${CONSOLE_FD}
	unset _msg
fi

if [[ ! -f "${XBT_TARGET_DIR}/.done.gcc_stage3" ]]; then
        gcc_stage3_build >${XBT_TARGET_DIR}/_log.8.gcc_stage3 2>&1
        touch "${XBT_TARGET_DIR}/.done.gcc_stage3"
else
	_msg="Building ${XBT_GCC} Stage 3 "
	echo -n "${_msg}"          >&${CONSOLE_FD}
	xbt_print_dots_40 ${#_msg} >&${CONSOLE_FD}
	echo    " already done"    >&${CONSOLE_FD}
	unset _msg
fi

if [[ ! -f "${XBT_TARGET_DIR}/.done.libc_stage3" ]]; then
        libc_stage3_build >${XBT_TARGET_DIR}/_log.9.libc_stage3 2>&1
        touch "${XBT_TARGET_DIR}/.done.libc_stage3"
else
	_msg="Building ${XBT_LIBC} Stage 3 "
	echo -n "${_msg}"          >&${CONSOLE_FD}
	xbt_print_dots_40 ${#_msg} >&${CONSOLE_FD}
	echo    " already done"    >&${CONSOLE_FD}
	unset _msg
fi

if [[ ! -f "${XBT_TARGET_DIR}/.done.target_adjust" ]]; then
        build_target_adjust >${XBT_TARGET_DIR}/_log.A.target_adjust 2>&1
        touch "${XBT_TARGET_DIR}/.done.target_adjust"
else
	_msg="Target Sysroot Adjustment "
	echo -n "${_msg}"          >&${CONSOLE_FD}
	xbt_print_dots_40 ${#_msg} >&${CONSOLE_FD}
	echo    " already done"    >&${CONSOLE_FD}
	unset _msg
fi

)

if [[ $? -ne 0 ]]; then
	echo -e "${K_TEXT_BRED}ERROR${K_TEXT_NORM}"
	echo "Check the build log files.  Probably check:"
	if [[ -f "${XBT_TARGET_DIR}/_log.A.target_adjust" ]]; then
		echo "=> ${XBT_TARGET_DIR}/_log.A.target_adjust"
	elif [[ -f "${XBT_TARGET_DIR}/_log.9.libc_stage3" ]]; then
		echo "=> ${XBT_TARGET_DIR}/_log.9.libc_stage3"
	elif [[ -f "${XBT_TARGET_DIR}/_log.8.gcc_stage3" ]]; then
		echo "=> ${XBT_TARGET_DIR}/_log.8.gcc_stage3"
	elif [[ -f "${XBT_TARGET_DIR}/_log.7.libc_stage2" ]]; then
		echo "=> ${XBT_TARGET_DIR}/_log.7.libc_stage2"
	elif [[ -f "${XBT_TARGET_DIR}/_log.6.gcc_stage2" ]]; then
		echo "=> ${XBT_TARGET_DIR}/_log.6.gcc_stage2"
	elif [[ -f "${XBT_TARGET_DIR}/_log.5.libc_stage1" ]]; then
		echo "=> ${XBT_TARGET_DIR}/_log.5.libc_stage1"
	elif [[ -f "${XBT_TARGET_DIR}/_log.4.gcc_stage1" ]]; then
		echo "=> ${XBT_TARGET_DIR}/_log.4.gcc_stage1"
	else
		# This is annoying: need to check, in reverse order, for the
		# log files from building the host libs that gcc uses.
		declare -i _found=0               # declare integer
		declare -i _i=${#XBT_GCC_LIBS[@]} # declare integer
		while [[ $_i -gt 0 && ${_found} -eq 0 ]]; do
			_i=$(($_i - 1))
			_name="gcc_lib_${XBT_GCC_LIBS[$_i]%-*}"
			if [[ -f "${XBT_TARGET_DIR}/_log.3.${_name}" ]]; then
				_found=1
				echo "=> ${XBT_TARGET_DIR}/_log.3.${_name}"
			fi
		done
		# The if-elif-elif... chain above is broken; start a new one.
		if [[ ${_found} -eq 1 ]]; then
			:
		elif [[ -f "${XBT_TARGET_DIR}/_log.2.binutils" ]]; then
			echo "=> ${XBT_TARGET_DIR}/_log.2.binutils"
		elif [[ -f "${XBT_TARGET_DIR}/_log.0.kernel_headers" ]]; then
			echo "=> ${XBT_TARGET_DIR}/_log.0.kernel_headers"
		fi
		unset _found
		unset _i
		unset _name
	fi
	exit 1
fi

set -o errexit ; # Exit immediately if a command exits with a non-zero status.

exec >&4     # Set fd 1 back to stdout.
CONSOLE_FD=1 #

t2=${SECONDS}

echo ""
echo -e "${XBT_TARGET} cross-tool is ${K_TEXT_GREEN}complete${K_TEXT_NORM}."
echo "=> $(((${t2}-${t1})/60)) minutes $(((${t2}-${t1})%60)) seconds"


# *****************************************************************************
# Exit OK
# *****************************************************************************

exit 0


# end of file
