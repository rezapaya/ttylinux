#!/bin/bash


# This file is part of the ttylinux software.
# The license which this software falls under is GPLv2 as follows:
#
# Copyright (C) 2010-2012 Douglas Jerome <douglas@ttylinux.org>
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


# ******************************************************************************
# Definitions
# ******************************************************************************

PKG_URL="http://www.lua.org/ftp/"
PKG_TAR="lua-5.2.0.tar.gz"
PKG_SUM=""

PKG_NAME="lua"
PKG_VERSION="5.2.0"


# ******************************************************************************
# pkg_patch
# ******************************************************************************

pkg_patch() {
PKG_STATUS=""
return 0
}


# ******************************************************************************
# pkg_configure
# ******************************************************************************

pkg_configure() {
PKG_STATUS=""
return 0
}


# ******************************************************************************
# pkg_make
# ******************************************************************************

pkg_make() {

PKG_STATUS="make error"

cd "${PKG_NAME}-${PKG_VERSION}"
source "${TTYLINUX_XTOOL_DIR}/_xbt_env_set"

PATH="${XBT_BIN_PATH}:${PATH}" make linux \
	--jobs=${NJOBS} \
	AR="${XBT_AR} rcu " \
	AS="${XBT_AS} --sysroot=${TTYLINUX_SYSROOT_DIR}" \
	CC="${XBT_CC} --sysroot=${TTYLINUX_SYSROOT_DIR}" \
	CXX="${XBT_CXX} --sysroot=${TTYLINUX_SYSROOT_DIR}" \
	LD="${XBT_LD} --sysroot=${TTYLINUX_SYSROOT_DIR}" \
	NM="${XBT_NM}" \
	OBJCOPY="${XBT_OBJCOPY}" \
	RANLIB="${XBT_RANLIB}" \
	SIZE="${XBT_SIZE}" \
	STRIP="${XBT_STRIP}" \
	CFLAGS="${TTYLINUX_CFLAGS}" || return 1

source "${TTYLINUX_XTOOL_DIR}/_xbt_env_clr"
cd ..

PKG_STATUS=""
return 0

}


# ******************************************************************************
# pkg_install
# ******************************************************************************

pkg_install() {

PKG_STATUS="Unspecified error -- check the ${PKG_NAME} build log"

cd "${PKG_NAME}-${PKG_VERSION}"
source "${TTYLINUX_XTOOL_DIR}/_xbt_env_set"
PATH="${XBT_BIN_PATH}:${PATH}" make \
	INSTALL_TOP=${TTYLINUX_SYSROOT_DIR} \
	install || return 1
mv "${TTYLINUX_SYSROOT_DIR}/lib/liblua.a" "${TTYLINUX_SYSROOT_DIR}/usr/lib"
source "${TTYLINUX_XTOOL_DIR}/_xbt_env_clr"
cd ..

if [[ -d "rootfs/" ]]; then
	find "rootfs/" ! -type d -exec touch {} \;
	cp --archive --force rootfs/* "${TTYLINUX_SYSROOT_DIR}"
fi

PKG_STATUS=""
return 0

}


# ******************************************************************************
# pkg_clean
# ******************************************************************************

pkg_clean() {
PKG_STATUS=""
return 0
}


# end of file
