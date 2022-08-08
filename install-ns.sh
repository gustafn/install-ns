#!/bin/bash

do_clean=0
clean_only=0
build=0
while [ x"$1" != x ] ; do
    case $1 in
        clean) clean_only=1
            do_clean=1
            shift
            continue;;
        build) build=1
            shift
            continue;;
        *)  echo "argument '$1' ignored"
            shift
            continue;;
    esac
done


echo "------------------------ Settings ---------------------------------------"
# Installation directory and software versions to be installed.

build_dir=${build_dir:-/usr/local/src}
#build_dir=/usr/local/src/oo2
ns_install_dir=${ns_install_dir:-/usr/local/ns}
#ns_install_dir=/usr/local/oo2

version_ns=${version_ns:-4.99.24}
#version_ns=GIT
git_branch_ns=${git_branch_ns:-main}
version_modules=${version_modules:${version_ns}}
#version_modules=HEAD

#version_tcl=8.5.19
version_tcl=${version_tcl:-8.6.12}
version_tcllib=${version_tcllib:-1.20}
tcllib_dirname=tcllib
version_thread=""
#version_thread=2.8.2
#version_thread=2.8.6
version_xotcl=${version_xotcl:-2.3.0}
#version_xotcl=HEAD
#version_tdom=GIT
version_tdom=${version_tdom:-0.9.1}
version_tdom_git="master@{2014-11-01 00:00:00}"
tdom_base=tdom-${version_tdom}
tdom_tar=${tdom_base}-src.tgz
ns_user=${ns_user:-nsadmin}
ns_group=${ns_group:-nsadmin}
with_mongo=${with_mongo:-0}
with_system_malloc=${with_system_malloc:-0}


#tcllib_tar=${tcllib_dirname}-${version_tcllib}.tar.bz2
tcllib_tar=${tcllib_dirname}-${version_tcllib}.tar.gz

#
# The setting "with_postgres=1" means that we want to install a fresh
# packaged PostgeSQL.
#
# The setting "with_postgres_driver=1" means that we want to install
# NaviServer with the nsdbpg driver (this requires that a at least a
# postgres client library is installed).
#
with_postgres=${with_postgres:-1}
with_postgres_driver=${with_postgres_driver:-1}

#
# some old versions of wget (e.g. inn CentOS 5.11) need the no-check flag
wget_options=""
#wget_options="--no-check-certificate"

#
# the pg_* variables should be the path leading to the include and
# library file of postgres to be used in this build.  In particular,
# "libpq-fe.h" and "libpq.so" are typically needed.
pg_incl=/usr/include/postgresql
pg_lib=/usr/lib
pg_user=postgres

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo "------------------------ Check System ----------------------------"
debian=0
redhat=0
macosx=0
sunos=0
freebsd=0
openbsd=0
archlinux=0

make="make"
type="type -a"
tar="tar"

pg_packages=

uname=$(uname)
if [ $uname = "Darwin" ] ; then
    macosx=1
    group_listcmd="dscl . list /Groups | grep ${ns_group}"
    group_addcmd="dscl . create /Groups/${ns_group} PrimaryGroupID $((`dscl . -list /Groups PrimaryGroupID | awk '{print $2}' | sort -rn|head -1` + 1))"
    ns_user_addcmd="dscl . create /Users/${ns_user}; dseditgroup -o edit -a ${ns_user} -t user ${ns_group}"
    ns_user_addgroup_hint="dseditgroup -o edit -a YOUR_USERID -t user ${ns_group}"

    maxid=$(dscl . -list /Users UniqueID | awk '{print $2}' | sort -ug | tail -1)
    newid=$((maxid+1))

    osxversionmajor=$(sw_vers -productVersion | awk -F '.' '{print $1}')
    osxversionminor=$(sw_vers -productVersion | awk -F '.' '{print $2}')

    #
    # In OS X Yosemite (macOS 10.10.*) sysadminctl was added for creating users
    #
    if [ ${osxversionmajor} -gt 10 ]; then
        ns_user_addcmd="sysadminctl -addUser ${ns_user} -UID ${newid}; dseditgroup -o edit -a ${ns_user} -t user ${ns_group}; dscl . -create /Users/${ns_user} PrimaryGroupID `dscl . -read  /Groups/nsadmin PrimaryGroupID | awk '{print $2}'`"
    elif [ ${osxversionminor} -ge 10 ]; then
        ns_user_addcmd="sysadminctl -addUser ${ns_user} -UID ${newid}; dseditgroup -o edit -a ${ns_user} -t user ${ns_group}; dscl . -create /Users/${ns_user} PrimaryGroupID `dscl . -read  /Groups/nsadmin PrimaryGroupID | awk '{print $2}'`"
    else
        ns_user_addcmd="dscl . create /Users/${ns_user}; dscl . -create /Users/${ns_user} UniqueID ${newid}; dseditgroup -o edit -a ${ns_user} -t user ${ns_group}"
    fi

    ns_user_addgroup_hint="dseditgroup -o edit -a YOUR_USERID -t user ${ns_group}"

    if [ $with_postgres = "1" ] ; then
        # Preconfigured for PostgreSQL 14 installed via MacPorts
        pg_incl=/opt/local/include/postgresql14/
        pg_lib=/opt/local/lib/postgresql14/
        pg_packages="postgresql14 postgresql14-server"
    fi
else
    #
    # Not Darwin
    #
    if [ -f "/etc/debian_version" ] ; then
        debian=1
        if [ $with_postgres = "1" ] ; then
            pg_packages="postgresql libpq-dev"
        elif [ $with_postgres_driver = "1" ] ; then
            pg_packages="libpq-dev"
        fi
    elif [ -f "/etc/redhat-release" ] ; then
        redhat=1
        if [ $with_postgres = "1" ] ; then
            pg_packages="postgresql postgresql-devel"
        elif [ $with_postgres_driver = "1" ] ; then
            pg_packages="postgresql-devel"
        fi
    elif [ -f "/etc/arch-release" ] ; then
        archlinux=1
        if [ $with_postgres = "1" ] || [ $with_postgres_driver = "1" ]; then
            pg_packages="postgresql"
        fi
    elif [ $uname = 'SunOS' ] ; then
        sunos=1
        make="gmake"
        export CC="gcc -m64"
        if [ $with_postgres = "1" ] ; then
            pg_packages="postgresql-960"
            pg_incl=/opt/pgsql960/include
            pg_lib=/opt/pgsql960/lib
        fi
    elif [ $uname = "FreeBSD" ] ; then
        freebsd=1
        make="gmake"
        type="type"
        # adjust following to local gcc version:
        setenv CC=clang
        if [ $with_postgres = "1" ] ; then
            # for freebsd10, file is: /usr/local/include/postgresql/internal/postgres_fe.h so:
            #pg_incl=/usr/local/include/postgresql/internal
            pg_packages="postgresql-client"
            pg_incl=/usr/local/include
            pg_lib=/usr/local/lib
        fi
        # make sure that bash is installed here, such that the recommendation for bash works below
        pkg install bash
    elif [ $uname = "OpenBSD" ] ; then
        make="gmake CC=clang"
        openbsd=1
        export CC=clang
        if [ $with_postgres = "1" ] ; then
            if [ $with_postgres_driver = "1" ] ; then
                pg_packages="postgresql-client postgresql-server"
            else
                pg_packages="postgresql-server"
            fi
            pg_incl=/usr/local/include/postgresql
            pg_lib=/usr/local/lib
        fi
    fi

    group_addcmd="groupadd ${ns_group}"
    if [ $uname = "FreeBSD" ] ; then
        group_addcmd="pw groupadd ${ns_group}"
        ns_user_addcmd="pw useradd ${ns_user} -G ${ns_group} "
    elif [ $uname = "OpenBSD" ] ; then
        ns_user_addcmd="useradd -m -g ${ns_group} ${ns_user}"
    else
        ns_user_addcmd="useradd -g ${ns_group} ${ns_user}"
    fi
    group_listcmd="grep ${ns_group} /etc/group"
    ns_user_addgroup_hint="sudo usermod -G ${ns_group} YOUR_USERID"
fi

echo "
Installation Script for NaviServer

This script installs Tcl, NaviServer, the essential
NaviServer modules, tcllib, libthread, XOTcl and tDOM
from scratch by obtaining the sources from the actual
releases and compiling it.

The script has a long heritage:
(c) 2008      Malte Sussdorff, Nima Mazloumi
(c) 2012-2021 Gustaf Neumann

Tested under macOS, Ubuntu 12.04, 13.04, 14.04, 16.04, 18.04, 20.04, Raspbian 9.4,
OmniOS r151014, OpenBSD 6.1, 6.3, 6.6, 6.8, 6.9 FreeBSD 12.2, 13.0,
Fedora Core 18, 20, 32, 35, CentOS 7, Roxy Linux 8.4, ArchLinux

LICENSE    This program comes with ABSOLUTELY NO WARRANTY;
           This is free software, and you are welcome to redistribute it under certain conditions;
           For details see http://www.gnu.org/licenses.

SETTINGS   build_dir              (Build directory)                 ${build_dir}
           ns_install_dir         (Installation directory)          ${ns_install_dir}
           version_ns             (Version of NaviServer)           ${version_ns}
           git_branch_ns          (Branch for git checkout of ns)   ${git_branch_ns}
           version_modules        (Version opf NaviServer Modules)  ${version_modules}
           version_tcllib         (Version of Tcllib)               ${version_tcllib}
                                  (Version Tcl thread library)      ${version_thread}
           version_xotcl          (Version of NSF/NX/XOTcl)         ${version_xotcl}
           version_tcl            (Version of Tcl)                  ${version_tcl}
           version_tdom           (Version of tDOM)                 ${version_tdom}
           ns_user                (NaviServer user)                 ${ns_user}
           ns_group               (NaviServer group)                ${ns_group}
                                  (Make command)                    ${make}
                                  (Type command)                    ${type}
           with_mongo             (Add MongoDB client and server)   ${with_mongo}
           with_postgres          (Install PostgreSQL DB server)    ${with_postgres}
           with_postgres_driver   (Add PostgreSQL driver support)   ${with_postgres_driver}
           with_system_malloc     (Tcl compiled with system malloc) ${with_system_malloc}"

if [ $with_postgres = "1" ] ; then
    echo "
           PostgreSQL user       ${pg_user}
           postgres/include      ${pg_incl}
           postgres/lib          ${pg_lib}
           PostgreSQL Packages   ${pg_packages}
"
fi


if [ $build = "0" ] && [ ! $clean_only = "1" ] ; then
    echo "
WARNING    Check Settings AND Cleanup section before running this script!
           If you know what you're doing then call the call the script as

              sudo bash $0 build
"
    exit
fi

echo "------------------------ Cleanup -----------------------------------------"

# The cleanup on the installation dir is optional, since it might
# delete something else not from our installation.
#rm -rf ${ns_install_dir}

mkdir -p ${build_dir}
cd ${build_dir}

if [ $do_clean = 1 ] ; then
    #rm    tcl${version_tcl}-src.tar.gz
    rm -r tcl${version_tcl}
    #rm    ${tcllib_tar}
    rm -r ${tcllib_dirname}-${version_tcllib}
    #rm    naviserver-${version_ns}.tar.gz
    rm -rf naviserver-${version_ns}
    #rm    naviserver-${version_ns}-modules.tar.gz
    rm -rf modules modules-git
    #rm    thread${version_thread}.tar.gz
    rm -r thread${version_thread}
    #rm    nsf${version_xotcl}.tar.gz
    rm -rf nsf${version_xotcl}
    rm  -rf ${tdom_base} ${tdom_tar} tdom
fi

# just clean?
if [ $clean_only = "1" ] ; then
  exit
fi

echo "------------------------ Save config variables in ${ns_install_dir}/lib/nsConfig.sh"
mkdir -p  ${ns_install_dir}/lib
cat << EOF > ${ns_install_dir}/lib/nsConfig.sh
build_dir="${build_dir}"
ns_install_dir="${ns_install_dir}"
version_ns=${version_ns}
version_modules=${version_modules}
version_tcl=${version_tcl}
version_tcllib=${version_tcllib}
version_thread=${version_thread}
version_xotcl=${version_xotcl}
version_tdom=${version_tdom}
ns_user=${ns_user}
pg_user=${pg_user}
ns_group=${ns_group}
with_mongo=${with_mongo}
with_postgres=${with_postgres}
pg_incl="${pg_incl}"
pg_lib="${pg_lib}"
make="${make}"
type="${type}"
debian=${debian}
redhat=${redhat}
macosx=${macosx}
sunos=${sunos}
freebsd=${freebsd}
archlinux=${archlinux}
EOF

echo "------------------------ Check User and Group --------------------"

group=$(eval ${group_listcmd})
echo "${group_listcmd} => $group"
if [ "x$group" = "x" ] ; then
    echo "creating group ${ns_group} with command ${group_addcmd}"
    eval ${group_addcmd}
fi

id=$(id -u ${ns_user})
if [ $? != "0" ] ; then
    if [ $debian = "1" ] || [ $macosx = "1" ] || [ $archlinux = "1" ]; then
        echo "creating user ${ns_user} with command ${ns_user_addcmd}"
        eval ${ns_user_addcmd}
    else
        echo "User ${ns_user} does not exist; you might add it with a command like"
        echo "     sudo ${ns_user_addcmd}"
        exit
    fi
fi

echo "------------------------ System dependencies ---------------------------------"

function version_greater_equal()
{
    printf '%s\n%s\n' "$2" "$1" | sort --check=quiet --version-sort
}

mongodb=
if [ $with_mongo = "1" ] ; then
    debian10=0
    # Avoid Ubuntu, which has /etc/lsb-release
    if [ $debian = "1" ] && [ ! -f /etc/lsb-release ] ; then
        debian_version=`cat /etc/debian_version`
        if version_greater_equal $debian_version 10 ; then
            debian10=1
        fi
    fi
    if [ $debian10 = "1" ] ; then
        PKG_OK=$(dpkg-query -W --showformat='${Status}\n' mongodb-org|grep "install ok installed")
        if [ "" = "$PKG_OK" ]; then
            sudo apt-get install -y gnupg
            wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -
            echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/5.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list
            sudo apt-get update
            sudo apt-get install -y mongodb-org
        fi
        mongodb="libtool autoconf cmake"
    elif [ $debian = "1" ] ; then
        mongodb="libtool autoconf cmake mongodb"
   fi
fi

if [ $with_mongo = "1" ] || [ $version_xotcl = "HEAD" ] || [ $version_tdom = "GIT" ] || [ $version_ns = "HEAD" ] || [ $version_ns = "GIT" ]; then
    git=git
else
    git=
fi

if [ $version_ns = "HEAD" ] || [ $version_ns = "GIT" ]; then
    autoconf=autoconf
else
    autoconf=
fi
mercurial=
with_openssl_configure_flag=

if [ $debian = "1" ] ; then
    # On Debian/Ubuntu, make sure we have zlib installed, otherwise
    # NaviServer can't provide compression support
    apt-get install -y make ${autoconf} locales gcc zlib1g-dev wget curl zip unzip openssl libssl-dev ${pg_packages} ${mercurial} ${git} ${mongodb}
    locale-gen en_US.UTF-8
    update-locale LANG="en_US.UTF-8"
fi
if [ $redhat = "1" ] ; then
    # packages for FC/RHL

    if [ -x "/usr/bin/dnf" ] ; then
        pkgmanager=/usr/bin/dnf
    else
        pkgmanager=yum
    fi

    ${pkgmanager} install make ${autoconf} automake gcc zlib zlib-devel wget curl zip unzip openssl openssl-devel ${pg_packages} ${mercurial} ${git} ${mongodb}
elif [ $archlinux = "1" ] ; then
    pacman -Sy --noconfirm wget gcc make ${pg_packages}
fi

if [ $macosx = "1" ] ; then
    port install ${autoconf} automake zlib wget curl zip unzip openssl ${pg_packages} ${mercurial} ${git} ${mongodb}
    with_openssl_configure_flag="--with-openssl=/opt/local"
fi

if [ $sunos = "1" ] ; then
    # packages for OpenSolaris/OmniOS
    pkg install pkg://omnios/developer/versioning/git mercurial ${autoconf} automake /developer/gcc51 zlib wget \
        curl compress/zip compress/unzip \
        ${pg_packages} ${mercurial} ${git} ${mongodb}
    pkg install \
        developer/object-file \
        developer/linker \
        developer/library/lint \
        developer/build/gnu-make \
        system/header \
        system/library/math/header-math \
        archiver/gnu-tar

    #ln -s /opt/gcc-4.8.1/bin/gcc /bin/gcc
    tar="gtar"
fi

if [ $freebsd = "1" ] ; then
     pkg install gmake llvm openssl automake wget curl zip unzip ${pg_packages} ${autoconf} ${mercurial} ${git} ${mongodb}
fi

if [ $openbsd = "1" ] ; then
    #export PKG_PATH=https://ftp.eu.openbsd.org/pub/OpenBSD/6.3/packages/`machine -a`/
    export AUTOCONF_VERSION=2.69
    export AUTOMAKE_VERSION=1.15
    #
    # OpenBSD does not require a build with OpenSSL (libreSSL works as
    # well), but NaviServer gets more functionality by using recent
    # versions of OpenSSL.
    #
    pkg_add gcc openssl wget curl zip unzip bash gmake ${mercurial} ${git} ${mongodb} ${pg_packages} autoconf-2.69p2 automake-1.15.1
    pkg_add autoconf-2.69p3
fi


echo "------------------------ Downloading sources ----------------------------"
set -o errexit

if [ ! -f tcl${version_tcl}-src.tar.gz ] ; then
    echo wget ${wget_options} https://downloads.sourceforge.net/sourceforge/tcl/tcl${version_tcl}-src.tar.gz
    wget ${wget_options} https://downloads.sourceforge.net/sourceforge/tcl/tcl${version_tcl}-src.tar.gz
fi
if [ ! -f ${tcllib_tar} ] ; then
    wget ${wget_options} https://downloads.sourceforge.net/sourceforge/tcllib/${tcllib_tar}
fi

# All versions of tcllib up to 1.15 were named tcllib-*.
# tcllib-1.16 was named a while Tcllib-1.16 (capital T), but has been renamed later
# to the standard naming conventions. tcllib-1.17 is fine again.
if [ ! -f ${tcllib_tar} ] ; then
    wget ${wget_options} https://downloads.sourceforge.net/sourceforge/tcllib/Tcllib-${version_tcllib}.tar.bz2
    tcllib_dirname=Tcllib
fi

if [ ! $version_ns = "HEAD" ] &&  [ ! $version_ns = "GIT" ] ; then
    if [ ! -f naviserver-${version_ns}.tar.gz ] ; then
        wget ${wget_options} https://downloads.sourceforge.net/sourceforge/naviserver/naviserver-${version_ns}.tar.gz
    fi
else
    if [ ! -d naviserver ] ; then
        git clone https://bitbucket.org/naviserver/naviserver
    else
        cd ${build_dir}/naviserver
        git pull
    fi
    if [ ! ${git_branch_ns} = "" ] ; then
        cd ${build_dir}/naviserver
        git checkout ${git_branch_ns}
    fi
fi

cd ${build_dir}
if [ ! ${version_modules} = "HEAD" ] ; then
    modules_dir=modules
    if [ ! -f naviserver-${version_modules}-modules.tar.gz ] ; then
        wget ${wget_options} https://downloads.sourceforge.net/sourceforge/naviserver/naviserver-${version_modules}-modules.tar.gz
    fi
else
    modules_dir=modules-git
    if [ ! -d ${modules_dir} ] ; then
        mkdir ${modules_dir}
    fi
    cd ${modules_dir}
    for d in letsencrypt \
                 nsaccess \
                 nsaspell \
                 nsauthpam \
                 nschartdir \
                 nsclamav \
                 nscoap \
                 nsconf \
                 nsdbbdb \
                 nsdbi \
                 nsdbilite \
                 nsdbimy \
                 nsdbipg \
                 nsdbmysql \
                 nsdbpg \
                 nsdbsqlite \
                 nsdbtds \
                 nsdhcpd \
                 nsdns \
                 nsexample \
                 nsexpat \
                 nsfortune \
                 nsgdchart \
                 nsicmp \
                 nsimap \
                 nsldap \
                 nsldapd \
                 nsloopctl \
                 nsmemcache \
                 nsocaml \
                 nsoracle \
                 nsphp \
                 nsradiusd \
                 nsrtsp \
                 nssavi \
                 nsshell \
                 nssip \
                 nssmtpd \
                 nssnmp \
                 nsstats \
                 nssys \
                 nssyslogd \
                 nstftpd \
                 nstk \
                 nsudp \
                 nsvfs \
                 nswebpush \
                 nszlib \
                 revproxy \
                 websocket
    do
        if [ ! -d $d ] ; then
            git clone https://bitbucket.org/naviserver/$d
        else
            cd $d
            git pull
            cd ${build_dir}
        fi
    done
fi

cd ${build_dir}
if [ ! "$version_thread" = "" ] ; then
    if [ ! -f thread${version_thread}.tar.gz ] ; then
        wget ${wget_options} https://downloads.sourceforge.net/sourceforge/tcl/thread${version_thread}.tar.gz
    fi
fi

if [ ! ${version_xotcl} = "HEAD" ] ; then
    if [ ! -f nsf${version_xotcl}.tar.gz ] ; then
        wget ${wget_options} https://downloads.sourceforge.net/sourceforge/next-scripting/nsf${version_xotcl}.tar.gz
    fi
else
    if [ ! -d nsf ] ; then
        git clone git://alice.wu-wien.ac.at/nsf
    else
        cd nsf
        git pull
        cd ${build_dir}
    fi
fi

if [ $with_mongo = "1" ] ; then
    if [ ! -d mongo-c-driver ] ; then
        git clone https://github.com/mongodb/mongo-c-driver
    else
        cd mongo-c-driver
        git pull
        cd ${build_dir}
    fi
fi

if [ ! $version_tdom = "GIT" ] ; then
    if [ ! -f ${tdom_tar} ] ; then
        #wget --no-check-certificate https://cloud.github.com/downloads/tDOM/tdom/tDOM-${version_tdom}.tgz
        #curl -L -O  https://github.com/downloads/tDOM/tdom/tDOM-${version_tdom}.tgz
        #
        # Get a version of tdom, which is compatible with Tcl
        # 8.6. Unfortunately, the released version is not.
        #
        rm  -rf ${tdom_base} ${tdom_tar}
        #curl -L -O https://github.com/tDOM/tdom/tarball/4be49b70cabea18c90504d1159fd63994b323234
        #${tar} zxvf 4be49b70cabea18c90504d1159fd63994b323234
        #mv tDOM-tdom-4be49b7 tDOM-${version_tdom}
        curl -L -O http://tdom.org/downloads/${tdom_tar}
        ${tar} zxvf ${tdom_tar}
    fi
else
    if [ ! -f "tdom/${version_tdom_git}" ] ; then
        #
        # get the newest version of tDOM
        #
        rm -rf tdom
        echo "get  tDOM via: git clone https://github.com/tDOM/tdom.git"
        git clone https://github.com/tDOM/tdom.git
        # cd tdom
        # git checkout 'master@{2012-12-31 00:00:00}'
        # cd ${build_dir}
    fi
fi


#exit
echo "------------------------ Installing Tcl ---------------------------------"
set -o errexit

${tar} xfz tcl${version_tcl}-src.tar.gz

if [ $with_system_malloc = "1" ] ; then
    cd tcl${version_tcl}
    cat <<EOF > tcl86-system-malloc.patch
Index: generic/tclThreadAlloc.c
==================================================================
--- generic/tclThreadAlloc.c
+++ generic/tclThreadAlloc.c
@@ -305,11 +305,19 @@
  * Side effects:
  *	May allocate more blocks for a bucket.
  *
  *----------------------------------------------------------------------
  */
-
+#define SYSTEM_MALLOC 1
+#if defined(SYSTEM_MALLOC)
+char *
+TclpAlloc(
+    unsigned int numBytes)     /* Number of bytes to allocate. */
+{
+    return (char*) malloc(numBytes);
+}
+#else
 char *
 TclpAlloc(
     unsigned int reqSize)
 {
     Cache *cachePtr;
@@ -366,10 +374,11 @@
     if (blockPtr == NULL) {
 	return NULL;
     }
     return Block2Ptr(blockPtr, bucket, reqSize);
 }
+#endif
 
 /*
  *----------------------------------------------------------------------
  *
  * TclpFree --
@@ -382,11 +391,19 @@
  * Side effects:
  *	May move blocks to shared cache.
  *
  *----------------------------------------------------------------------
  */
-
+#if defined(SYSTEM_MALLOC)
+void
+TclpFree(
+    char *ptr)         /* Pointer to memory to free. */
+{
+    free(ptr);
+    return;
+}
+#else
 void
 TclpFree(
     char *ptr)
 {
     Cache *cachePtr;
@@ -425,10 +442,11 @@
     if (cachePtr != sharedPtr &&
 	    cachePtr->buckets[bucket].numFree > bucketInfo[bucket].maxBlocks) {
 	PutBlocks(cachePtr, bucket, bucketInfo[bucket].numMove);
     }
 }
+#endif
 
 /*
  *----------------------------------------------------------------------
  *
  * TclpRealloc --
@@ -441,11 +459,19 @@
  * Side effects:
  *	Previous memory, if any, may be freed.
  *
  *----------------------------------------------------------------------
  */
-
+#if defined(SYSTEM_MALLOC)
+char *
+TclpRealloc(
+    char *oldPtr,              /* Pointer to alloced block. */
+    unsigned int numBytes)     /* New size of memory. */
+{
+    return realloc(oldPtr, numBytes);
+}
+#else
 char *
 TclpRealloc(
     char *ptr,
     unsigned int reqSize)
 {
@@ -519,10 +545,11 @@
 	memcpy(newPtr, ptr, reqSize);
 	TclpFree(ptr);
     }
     return newPtr;
 }
+#endif
 
 /*
  *----------------------------------------------------------------------
  *
  * TclThreadAllocObj --


EOF
    echo "patching Tcl with SYSTEM malloc patch ..."
    patch -p0 < tcl86-system-malloc.patch
    echo "patching Tcl with SYSTEM malloc patch DONE"
    cd ..
fi

rm -rf  tcl${version_tcl}/pkgs/sqlit*
#rm -rf tcl${version_tcl}/pkgs/thread*

cd tcl${version_tcl}/unix
./configure --enable-threads --prefix=${ns_install_dir}
#./configure --enable-threads --prefix=${ns_install_dir} --with-naviserver=${ns_install_dir}

${make}
${make} install

# Make sure, we have a tclsh in ns/bin
if [ -f ${ns_install_dir}/bin/tclsh ] ; then
    rm ${ns_install_dir}/bin/tclsh
fi
source ${ns_install_dir}/lib/tclConfig.sh
ln -sf ${ns_install_dir}/bin/tclsh${TCL_VERSION} ${ns_install_dir}/bin/tclsh

#
# Go back where you started from
#
cd ${build_dir}


echo "------------------------ Installing Tcllib ------------------------------"

#${tar} xvfj ${tcllib_tar}
${tar} xvf ${tcllib_tar}
cd ${tcllib_dirname}-${version_tcllib}
./configure --prefix=${ns_install_dir}
${make} install
cd ..

echo "------------------------ Installing NaviServer ---------------------------"

cd ${build_dir}

if [ ! ${version_ns} = "HEAD" ] &&  [ ! $version_ns = "GIT" ] ; then
    ${tar} zxvf naviserver-${version_ns}.tar.gz
    cd naviserver-${version_ns}
    ./configure --with-tcl=${ns_install_dir}/lib --prefix=${ns_install_dir} ${with_openssl_configure_flag}
else
    cd naviserver
    if [ ! -f naviserver/configure ] ; then
        bash autogen.sh --enable-threads --with-tcl=${ns_install_dir}/lib --prefix=${ns_install_dir} ${with_openssl_configure_flag}
    else
        ./configure --enable-threads --with-tcl=${ns_install_dir}/lib --prefix=${ns_install_dir} ${with_openssl_configure_flag}
    fi
fi
${make}

if [ ${version_ns} = "HEAD" ] ; then
    ${make} "DTPLITE=${ns_install_dir}/bin/tclsh $ns_install_dir/bin/dtplite" build-doc
fi
${make} install
cd ..

if [ $with_postgres_driver = "1" ] ; then

    echo "------------------------ Installing Modules/nsdbpg ----------------------"
    cd ${build_dir}
    if [ ! ${version_modules} = "HEAD" ] ; then
        ${tar} zxvf naviserver-${version_modules}-modules.tar.gz
    fi
    cd ${modules_dir}/nsdbpg
    ${make} PGLIB=${pg_lib} PGINCLUDE=${pg_incl} NAVISERVER=${ns_install_dir}
    ${make} NAVISERVER=${ns_install_dir} install

    cd ${build_dir}
fi

if [ "$version_thread" = "" ] ; then

    echo "------------------------ Configure, compile and install libthread for NaviServer ------------------"
    cd ${build_dir}/tcl${version_tcl}/pkgs/thread*
    ./configure --enable-threads --prefix=${ns_install_dir} --with-naviserver=${ns_install_dir}
    ${make} clean
    ${make} install
    cd ${build_dir}

else
    echo "------------------------ Installing Tcl Thread library -----------------------"

    ${tar} xfz thread${version_thread}.tar.gz
    cd thread${version_thread}/unix/
    ../configure --enable-threads --prefix=${ns_install_dir} --exec-prefix=${ns_install_dir} --with-naviserver=${ns_install_dir} --with-tcl=${ns_install_dir}/lib
    make
    ${make} install
    #
    # Copy installed naviserver flavor of libthread to a special name.
    # Use for the time being "cp" instead of "mv" to keep old
    # configuration (not expecting the suffix) files working.
    #
    # thread2.8.6/libthread2.8.6.so -> thread2.8.6/libthread-ns2.8.6.so
    #binary=${ns_install_dir}/lib/thread${version_thread}/libthread${version_thread}.so
    #if [ -f "$binary" ] ; then
    #    cp $binary ${ns_install_dir}/lib/thread${version_thread}/libthread-ns${version_thread}.so
    #else
    #    binary=${ns_install_dir}/lib/thread${version_thread}/libthread${version_thread}.dylib
    #    cp $binary ${ns_install_dir}/lib/thread${version_thread}/libthread-ns${version_thread}.dylib
    #fi
    cd ${build_dir}
fi

if [ $with_mongo = "1" ] ; then
    echo "------------------------ MongoDB-driver ----------------------------------"

    cd mongo-c-driver
    cmake .
    ${make}
    ${make} install
    if [ $debian = "1" ] ; then
        ldconfig -v
    fi
    if [ $redhat = "1" ] ; then
        ldconfig -v
    fi
    cd ${build_dir}
fi

echo "------------------------ Installing XOTcl 2.* (with_mongo $with_mongo) -----------------"

if [ ! ${version_xotcl} = "HEAD" ] ; then
    ${tar} xvfz nsf${version_xotcl}.tar.gz
    cd nsf${version_xotcl}
else
    cd nsf
fi
#export CC=gcc

if [ $with_mongo = "1" ] ; then
    echo "------------------------ WITH MONGO"

    ./configure --enable-threads --enable-symbols \
                --prefix=${ns_install_dir} --exec-prefix=${ns_install_dir} --with-tcl=${ns_install_dir}/lib \
                --with-nsf=../../ \
                --with-mongoc=/usr/local/include/libmongoc-1.0/,/usr/local/lib/ \
                --with-bson=/usr/local/include/libbson-1.0,/usr/local/lib/
else
    ./configure --enable-threads --enable-symbols \
                --prefix=${ns_install_dir} --exec-prefix=${ns_install_dir} --with-tcl=${ns_install_dir}/lib
fi

${make}
${make} install
cd ..

echo "------------------------ Installing tDOM --------------------------------"

if [ $version_tdom = "GIT" ] ; then
    cd tdom
    if [ ! -f "${version_tdom_git}" ] ; then
        git checkout "${version_tdom_git}"
        echo > "${version_tdom_git}"
    fi
    cd unix
else
    #${tar} xfz tDOM-${version_tdom}.tgz
    cd ${tdom_base}/unix
fi
../configure --enable-threads --disable-tdomalloc --prefix=${ns_install_dir} --exec-prefix=${ns_install_dir} --with-tcl=${ns_install_dir}/lib
${make} install
cd ../..

echo "------------------------ Set permissions --------------------------------"

# set up minimal permissions in ${ns_install_dir}
chgrp -R ${ns_group} ${ns_install_dir}
chmod -R g+w ${ns_install_dir}

echo "

Congratulations, you have installed NaviServer.

You can now run plain NaviServer by typing the following command:

  sudo ${ns_install_dir}/bin/nsd -f -u ${ns_user} -g ${ns_group} -t ${ns_install_dir}/conf/nsd-config.tcl

As a next step, you need to configure the server according to your needs,
or you might want to use the server with OpenACS (search for /install-oacs.sh).
Consult as a reference the alternate configuration files in ${ns_install_dir}/conf/

"
