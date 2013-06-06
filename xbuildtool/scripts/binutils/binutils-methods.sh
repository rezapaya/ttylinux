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
#	This script builds the cross-development binutils.
#
# CHANGE LOG
#
#	03jun13	drj	Reorganize xbuildtool files.  Scrub architecture.
#	05dec12	drj	Added XBT_BINUTILS_EXT
#	19feb12	drj	Added text manifest of tool chain components.
#	10feb12	drj	Added debug breaks.
#	01jan11	drj	Initial version from ttylinux cross-tools.
#
# *****************************************************************************


# *****************************************************************************
# binutils_resolve_name
# *****************************************************************************

# Usage: binutils_resolve_name <string>
#
# Uses:
#      XBT_SCRIPT_DIR
#      binutils-versions.sh
#
# Sets:
#     XBT_BINUTILS_LIBS[]
#     XBT_BINUTILS_LIBS_EXT[]
#     XBT_BINUTILS_LIBS_MD5SUM[]
#     XBT_BINUTILS_LIBS_URL[]
#     XBT_BINUTILS
#     XBT_BINUTILS_EXT
#     XBT_BINUTILS_MD5SUM
#     XBT_BINUTILS_URL

# declare -a XBT_BINUTILS_LIBS        # declare indexed array
# declare -a XBT_BINUTILS_LIBS_EXT    # declare indexed array
# declare -a XBT_BINUTILS_LIBS_MD5SUM # declare indexed array
# declare -a XBT_BINUTILS_LIBS_URL    # declare indexed array

declare XBT_BINUTILS=""
declare XBT_BINUTILS_EXT=""
declare XBT_BINUTILS_MD5SUM=""
declare XBT_BINUTILS_URL=""

binutils_resolve_name() {

source ${XBT_SCRIPT_DIR}/binutils/binutils-versions.sh

local -r  binutilsNameVer=${1}    # delare read-only
local -ir rcount=${#_BINUTILS[@]} # delare integer, read-only
local -i  i=0                     # delare integer

for (( i=0 ; i<${rcount} ; i++ )); do
	if [[ "${binutilsNameVer}" == "${_BINUTILS[$i]}" ]]; then
		XBT_BINUTILS="${_BINUTILS[$i]}"
		XBT_BINUTILS_EXT="${_BINUTILS_EXT[$i]}"
		XBT_BINUTILS_MD5SUM="${_BINUTILS_MD5SUM[$i]}"
		XBT_BINUTILS_URL="${_BINUTILS_URL[$i]}"
		break # for loop
	fi
done

unset _BINUTILS
unset _BINUTILS_EXT
unset _BINUTILS_MD5SUM
unset _BINUTILS_URL

if [[ -z "${XBT_BINUTILS}" ]]; then
	echo "E> Cannot resolve \"${binutilsNameVer}\""
	return 1
fi

return 0

}


# *****************************************************************************
# binutils_build
# *****************************************************************************

binutils_build() {

local msg="Building ${XBT_BINUTILS} "
echo -n "${msg}"          >&${CONSOLE_FD}
xbt_print_dots_40 ${#msg} >&${CONSOLE_FD}
echo -n " "               >&${CONSOLE_FD}

xbt_debug_break "" >&${CONSOLE_FD}

# Find, uncompress and untar ${XBT_BINUTILS}.  The second argument is a
# secondary location to copy the source code tarball; this is so that users of
# the cross tool chain have access to the Linux source code as any users likely
# will cross-build the Linux kernel.
#
xbt_src_get ${XBT_BINUTILS}
unset _name # from xbt_src_get()

# Make an entry in the manifest.
#
echo -n "${XBT_BINUTILS} " >>"${XBT_TOOLCHAIN_MANIFEST}"
for ((i=(40-${#XBT_BINUTILS}) ; i > 0 ; i--)) do
	echo -n "." >>"${XBT_TOOLCHAIN_MANIFEST}"
done; unset i
echo " ${XBT_BINUTILS_URL}" >>"${XBT_TOOLCHAIN_MANIFEST}"

# Use any patches.
#
cd ${XBT_BINUTILS}
for p in ${XBT_SCRIPT_DIR}/binutils/${XBT_BINUTILS}-*.patch; do
	if [[ -f "${p}" ]]; then
		patch -Np1 -i "${p}"
		_p="/$(basename ${p})"
		chmod 644 "${_p}"
		echo "=> patch: ${_p}" >>"${XBT_TOOLCHAIN_MANIFEST}"
		unset _p
	fi
done; unset p
cd ..

# The Binutils documentation recommends building Binutils outside of the source
# directory in a dedicated build directory.
#
rm -rf	"build-binutils"
mkdir	"build-binutils"
cd	"build-binutils"

## Weird problem when building under ArchLinux i686 host: "makeinfo" is missing;
## it appears to be looking for bfd/docs/*.texi files in the build directory,
## even though they are actually in the source directory.
##
#mkdir -p bfd/doc
#cp -a ../${XBT_BINUTILS}/bfd/doc/* bfd/doc

local ENABLE_BFD64=""
[[ "${XBT_LINUX_ARCH}" == "x86_64" ]] && ENABLE_BFD64="--enable-64-bit-bfd"

# Configure Binutils for building.
#
echo "#: *********************************************************************"
echo "#: XBT_CONFIG"
echo "#: *********************************************************************"
../${XBT_BINUTILS}/configure \
	--build=${XBT_HOST} \
	--host=${XBT_HOST} \
	--target=${XBT_TARGET} \
	--prefix=${XBT_XHOST_DIR}/usr \
	${ENABLE_BFD64} \
	--enable-shared \
	--disable-build-warnings \
	--disable-multilib \
	--with-sysroot=${XBT_XTARG_DIR} || exit 1

xbt_debug_break "configured ${XBT_BINUTILS}" >&${CONSOLE_FD}

# Build Binutils.
#
echo "#: *********************************************************************"
echo "#: XBT_MAKE"
echo "#: *********************************************************************"
njobs=$((${ncpus} + 1))
make -j ${njobs} \
	LIB_PATH="${XBT_XTARG_DIR}/lib:${XBT_XTARG_DIR}/usr/lib" || exit 1
unset njobs

xbt_debug_break "maked ${XBT_BINUTILS}" >&${CONSOLE_FD}

# Install Binutils.
#
echo "#: *********************************************************************"
echo "#: XBT_INSTALL"
echo "#: *********************************************************************"
xbt_files_timestamp
make install || exit 1

echo "#: *********************************************************************"
echo "#: XBT_FILES"
echo "#: *********************************************************************"
xbt_files_find # Put the list of installed files in the log file.

xbt_debug_break "installed ${XBT_BINUTILS}" >&${CONSOLE_FD}

# Clean up.

cd ..
rm -rf "build-binutils"
rm -rf "${XBT_BINUTILS}"

echo "done [${XBT_BINUTILS} is complete]" >&${CONSOLE_FD}

return 0

}


# end of file
