#!/bin/bash -xv

AWK=/usr/bin/awk
CAT=/bin/cat
CHMOD=/bin/chmod
CP=/bin/cp
DPKG_DEB=/usr/bin/dpkg-deb
ECHO=/bin/echo
FAKEROOT=/usr/bin/fakeroot 
GPG=/usr/bin/gpg
MAKE=/usr/bin/make
MKDIR=/bin/mkdir
PATCH=/usr/bin/patch
PRINTF=printf
PWD=/bin/pwd
RM=/bin/rm
SED=/bin/sed
UNXZ=/usr/bin/unxz
TAR=/bin/tar
WGET=/usr/bin/wget

NB_CORES=$(grep -c '^processor' /proc/cpuinfo)

USAGE="$(basename "$0") [{-h|--help}][{-n|--nodelete}] [{-t|--temp}=temporary-folder] {-c|--conf}=configuration-file [{-a|--alt}={alldefconfig|allnoconfig|config|defconfig|menuconfig}] {-v|--version}=kernel-version [{-p|--path}=install-path]\n
\t\t-a, --alt\tAlternative Configuration (config, menuconfig, defconf, alldefconfig, allnoconfig,...).\n
\t\t-c, --conf\tConfiguration file.\n
\t\t-d, --deb\tCreate Debian package archive.\n
\t\t-g, --grsec\tGrsecurity patch.\n
\t\t-h, --help\tDisplay this message.\n
\t\t-n, --nodelete\tKeep temporary files.\n
\t\t-p, --path\tPath to install kernel and kernel modules (default=current folder).\n
\t\t-t, --temp\tTemporary folder.\n
\t\t-v, --version\tKernel version to build."

for i in "$@"; do
  case $i in
    -a==*|--alt=*)
    j="${i#*=}"
    shift
      case $j in
        alldefconfig|allnoconfig|config|defconfig|menuconfig)
        ALT=${j}
        ;;

        *)    # unknown alternative configuration
        ${ECHO} -e ${USAGE}
        exit 1
        ;;
      esac
    ;;

    -c=*|--conf=*)
    CONF_FILE="${i#*=}"
    shift
    ;;

    -d|--deb)
    DEB=1
    ;;

    -g=*|--grsec=*)
    GRSEC_PATCH="${i#*=}"
    shift
    ;;

    -h|--help)
    ${ECHO} -e ${USAGE}
    exit 0
    ;;

    -n|--nodelete)
    NO_DELETE=1
    ;;

    -p=*|--path=*)
    DEST_PATH="${i#*=}"
    shift
    ;;

    -t=*|--temp=*)
    TMP_PATH="${i#*=}"
    shift
    ;;

    -v=*|--version=*)
    KERNEL_VERSION="${i#*=}"
    shift
    ;;
  
    *)    # unknown option
    ${ECHO} -e ${USAGE}
    exit 1
    ;;
  
  esac
done

if [ -z "${CONF_FILE}" ]; then
  ${ECHO} "None configuration file" >&2
  exit 1
fi

if [ -z "${KERNEL_VERSION}" ]; then
  ${ECHO} "None kernel version" >&2
  exit 1
fi

if [ -z "${TMP_PATH}" ]; then
  if [ -d /tmp ]; then
    TMP_PATH=/tmp
  else
    ${ECHO} "Neither /tmp nor temporary folder exists" >&2
    exit 1
  fi
fi

pushd ${TMP_PATH} || exit 1

# kernel.org branch url and target files
KERNEL_SIGN=linux-${KERNEL_VERSION}.tar.sign
KERNEL_TAR=linux-${KERNEL_VERSION}.tar.xz
KERNEL_URL=https://www.kernel.org/pub/linux/kernel/v${KERNEL_VERSION/%.*/.x}

# Check if BOTH kernel version AND signature file exist
${WGET} -c --spider ${KERNEL_URL}/linux-${KERNEL_VERSION}.tar.{sign,xz}

if [ $? -ne 0 ]; then
  ${ECHO} "Kernel version does not exist" >&2
  exit 1
fi

# Download kernel AND signature
${WGET} -c ${KERNEL_URL}/linux-${KERNEL_VERSION}.tar.{sign,xz}

# Initialize GPG keyrings
${PRINTF} "" | ${GPG}

# Uncompressing kernel archive
${UNXZ} ${KERNEL_TAR}

# Download GPG keys
GPG_KEY=`${GPG} --verify ${KERNEL_SIGN} 2>&1 | ${AWK} '{print $NF}' | ${SED} -n '/[0-9]$/p' | ${SED} -n '1p'`
${GPG} --recv-keys ${GPG_KEY}

# Verify kernel archive against signature file
${GPG} --verify ${KERNEL_SIGN}

# Decompress kernel archive
${TAR} -xf linux-${KERNEL_VERSION}.tar -C ${TMP_PATH}

# Copy config file
${CP} ${CONF_FILE} linux-${KERNEL_VERSION}/.config

pushd ${TMP_PATH}/linux-${KERNEL_VERSION} || exit 1
# Configuring kernel
if [ -n "${ALT}" ]; then
  ${MAKE} ${ALT}
fi

# Patching kernel with grsecurity
if [ -n "${GRSEC_PATCH}" ]; then

  ${PATCH} -p1 < ${GRSEC_PATCH}
  
  # Configuring kernel with Grsecurity
  # Grsecurity configuration options 
  # cf. https://en.wikibooks.org/wiki/Grsecurity/Appendix/Grsecurity_and_PaX_Configuration_Options
  ${MAKE}
fi

###################################
if [ -z "${DEST_PATH}" ]; then
    DEST_PATH=$(${PWD})
fi

# Define install folder
if [ -n "${DEB}" ]; then
    INSTALL_PATH=${TMP_PATH}/kernel-${KERNEL_VERSION}
else
    INSTALL_PATH=${DEST_PATH}
fi
###################################

# Build and install kernel
${MKDIR} -p ${INSTALL_PATH}/boot
${MAKE} --jobs=$((NB_CORES+1)) --load-average=${NB_CORES}
${MAKE} INSTALL_PATH=${INSTALL_PATH}/boot install
exit 0
# Build and install kernel modules
${MAKE} --jobs=$((NB_CORES+1)) --load-average=${NB_CORES} modules
${MAKE} INSTALL_MOD_PATH=${INSTALL_PATH} modules_install

# Install firmware
${MAKE} INSTALL_MOD_PATH=${INSTALL_PATH} firmware_install

popd

# Create Debian package 
if [ -n "${DEB}" ]; then
    ${MKDIR} -p kernel-${KERNEL_VERSION}/DEBIAN
    
    ${CAT} > kernel-${KERNEL_VERSION}/DEBIAN/control << EOF
Package: kernel
Version: ${KERNEL_VERSION}
Section: kernel
Priority: optional
Essential: no
Architecture: amd64
Maintainer: David DIALLO
Provides: linux-image
Description: Linux kernel, version ${KERNEL_VERSION}
  This package contains the Linux kernel, modules and corresponding other
  files, version: ${KERNEL_VERSION}
EOF
    
    ${CAT} > kernel-${KERNEL_VERSION}/DEBIAN/postinst << EOF
rm -f /boot/initrd.img-${KERNEL_VERSION}
update-initramfs -c -k ${KERNEL_VERSION}
EOF
    
    ${CAT} > kernel-${KERNEL_VERSION}/DEBIAN/postrm << EOF
rm -f /boot/initrd.img-${KERNEL_VERSION}
EOF
   
    ${CAT} > kernel-${KERNEL_VERSION}/DEBIAN/triggers << EOF
interest update-initramfs
EOF
    
    ${CHMOD} 755 kernel-${KERNEL_VERSION}/DEBIAN/postinst kernel-${KERNEL_VERSION}/DEBIAN/postrm
    
    ${FAKEROOT} ${DPKG_DEB} --build kernel-${KERNEL_VERSION}
    
    # Copy Debian package 
    ${CP} kernel-${KERNEL_VERSION}.deb ${DEST_PATH}

    # Delete Debian package and install folder
    if [ -z "${NO_DELETE}" ]; then
        ${RM} kernel-${KERNEL_VERSION}.deb
        ${RM} -rf kernel-${KERNEL_VERSION}
    fi
fi

# Delete temporary files
if [ -z "${NO_DELETE}" ]; then
  # Delete kernel archive and decompressed kernel archive
  ${RM} linux-${KERNEL_VERSION}.tar
  ${RM} linux-${KERNEL_VERSION}.tar.sign
  ${RM} -rf linux-${KERNEL_VERSION}
fi

popd

exit 0
