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
start_dir=`pwd`

build_dir=${build_dir:-/usr/local/src}
#build_dir=/usr/local/src/oo2
ns_install_dir=${ns_install_dir:-/usr/local/ns}
#ns_install_dir=/usr/local/oo2

version_ns=${version_ns:-4.99.31}
#version_ns=GIT
git_branch_ns=${git_branch_ns:-main}
version_modules=${version_modules:-${version_ns}}
#version_modules=HEAD

#version_tcl=8.5.19
version_tcl=${version_tcl:-8.6.16}
version_tcllib=${version_tcllib:-1.20}
version_thread=${version_thread:-}
#version_thread=2.8.2
#version_thread=2.8.6
version_xotcl=${version_xotcl:-2.4.0}
#version_xotcl=HEAD
version_tdom=${version_tdom:-0.9.5}
#version_tdom=GIT
#version_tdom_git="master@{2014-11-01 00:00:00}"
ns_modules=${ns_modules:-}
ns_user=${ns_user:-nsadmin}
ns_group=${ns_group:-nsadmin}
with_mongo=${with_mongo:-0}
with_ns_deprecated=${with_ns_deprecated:-1}
with_system_malloc=${with_system_malloc:-0}
with_ns_doc=${with_ns_doc:-1}
with_debug_flags=${with_debug_flags:-0}

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
# the pg_* variables should be the path leading to the include and
# library file of postgres to be used in this build.  In particular,
# "libpq-fe.h" and "libpq.so" are typically needed.
pg_incl=${pg_incl:-/usr/include/postgresql}
pg_lib=${pg_lib:-/usr/lib}
pg_user=${pg_user:-postgres}
pg_packages=


if [ "${with_postgres_driver}" = "1" ] && [ "${ns_modules}" = "" ] ; then
    ns_modules=nsdbpg
fi


# ----------------------------------------------------------------------
#
# Check version info and derive more variables from it.
#
need_git=1
need_autoconf=1

# When getting Tcl via sourceforge tar ball
#   - the URL is https://downloads.sourceforge.net/sourceforge/tcl/tcl${version_tcl}-src.tar.gz
#   - the tarball is named tcl${version_tcl}-src.tar.gz
#   - the tcl_dir is named tcl${version_tcl}
#   - the thread library is included in the tar ball and placed in pkgs/thread
#
# When getting Tcl via tcl-lang.org
#   - the tcl_url is https://core.tcl-lang.org/tcl/tarball/tcl.tar.gz?uuid=${TCLTAG}
#   - the tcl_tarball is named tcl.tar.gz
#   - the tcl_dir is named tcl
#   - potential TCLTAG: trunk core-8-branch core-8-7-a5 core-8-6-branch core-8-6-12 core-8-5-19
#   - the thread library has to be obtained from
#     thread_url https://core.tcl-lang.org/thread/tarball/thread.tar.gz?uuid=${THREADTAG}
#   - the expanded tar file is named "thread"
#   - potential THREADTAG: trunk thread-2-8-branch thread-2-8-7 thread-2-7-3 thread-2-6-7
#
# When version name contains "." -> fetch from sourceforge
# else
#    - if name contains "branch" or trunk fetch always
#    - remove ${tcl_dir} before expanding tar
#
tcl_src_dir=tcl${version_tcl}

if [[ ${version_tcl} == *"."* ]] ; then
    echo "Tcl version number ${version_tcl} contains a DOT -> fetch Tcl from sourceforge"
    tcl_fetch_from_core=0
    tcl_fetch_always=0
    tcl_url=https://downloads.sourceforge.net/sourceforge/tcl/tcl${version_tcl}-src.tar.gz
    tcl_tar=tcl${version_tcl}-src.tar.gz
    tcl_src_dir=tcl${version_tcl}
else
    echo "${version_tcl} contains NO DOT -> fetch from Tcl core repos"
    tcl_fetch_from_core=1
    tcl_url=https://core.tcl-lang.org/tcl/tarball/tcl.tar.gz?uuid=${version_tcl}
    tcl_tar=tcl-${version_tcl}.tar.gz
    tcl_src_dir=tcl
    if [[ ${version_tcl} == *"branch"* ]] || [ "${version_tcl}" = "trunk" ] ; then
        tcl_fetch_always=1
    else
        tcl_fetch_always=0
    fi
fi

# comment for downloading from branch "core-9-0-b3-rc" (currently not supported)
#tcl_url=https://core.tcl-lang.org/tcl/tarball/core-9-0-b3-rc/tcl-core-9-0-b3-rc.tar.gz
#tcl_tar=tcl-core-9-0-b3-rc.tar.gz
#tcl_src_dir=tcl-core-9-0-b3-rc

# tags: https://core.tcl-lang.org/thread/taglist
if [ "${version_thread}" = "" ] && [ ${tcl_fetch_from_core} = "1" ] ; then
    if [ "${version_tcl}" = "trunk" ] ; then
        version_thread=trunk
    elif [[ ${version_tcl} == "main" ]] ; then
        version_thread=main
    elif [[ ${version_tcl} == *"core-9-0"* ]] ; then
        version_thread=main
    elif [[ ${version_tcl} == *"8-5"* ]] ; then
        version_thread=thread-2-6
    elif [[ ${version_tcl} == *"9.0."* ]] ; then
        version_thread=thread-3-0-0
        #version_thread=3.0b1
    else
        #version_thread=thread-2-8-branch
        version_thread=thread-2-8-10
    fi
    thread_fetch_from_core=1
    thread_url=https://core.tcl-lang.org/thread/tarball/thread.tar.gz?uuid=${version_thread}
    thread_tar=thread-${version_thread}.tar.gz
    thread_src_dir=thread
else
    thread_fetch_from_core=0
    if [ ! "${version_thread}" = "" ] ; then
        thread_tar=thread${version_thread}.tar.gz
        thread_url=https://downloads.sourceforge.net/sourceforge/tcl/thread${version_thread}.tar.gz
        thread_src_dir=thread${version_thread}
    else
        thread_tar=""
        thread_url=""
        thread_src_dir=${tcl_src_dir}/pkgs/thread
    fi
fi

if [ ! "${version_tdom}" = "GIT" ] ; then
    if [ "${version_tdom}" = "0.9.0" ] || [ "${version_tdom}" = "0.9.1" ] ; then
        tdom_src_dir=tdom-${version_tdom}
        tdom_tar=tdom-${version_tdom}-src.tgz
        tdom_url=https://tdom.org/downloads/${tdom_tar}
    elif [[ ${version_tdom} == *"."* ]] ; then
        #
        # Download from the "downloads" directory.
        # Newer versions of tdom have "-src" as root directory.
        #
        tdom_src_dir=tdom-${version_tdom}-src
        tdom_tar=tdom-${version_tdom}-src.tgz
        tdom_url=https://tdom.org/downloads/${tdom_tar}
        # tdom.org/downloads/ does not work reliably inside github actions
        #tdom_url=https://openacs.org/downloads/${tdom_tar}
    else
        #
        # Download from tdom fossil
        #
        tdom_src_dir=tDOM-${version_tdom}
        tdom_tar=tDOM-${version_tdom}.tar.gz
        tdom_url=https://tdom.org/index.html/tarball/${version_tdom}/${tdom_tar}
    fi
else
    need_git=1
    tdom_src_dir=tdom
fi

tcllib_src_dir=tcllib-${version_tcllib}
tcllib_tar=${tcllib_src_dir}.tar.gz
tcllib_url=https://downloads.sourceforge.net/sourceforge/tcllib/${tcllib_tar}

if [ ! "${version_xotcl}" = "HEAD" ] ; then
    nsf_src_dir=nsf${version_xotcl}
    nsf_tar=${nsf_src_dir}.tar.gz
    nsf_url=https://downloads.sourceforge.net/sourceforge/next-scripting/${nsf_tar}
else
    nsf_src_dir=nsf
    need_git=1
fi

ns_tar=""
ns_url=""
if [ "${version_ns}" = "HEAD" ] || [ "${version_ns}" = "GIT" ] ; then
    need_git=1
    need_autoconf=1
    ns_src_dir=naviserver
elif [ "${version_ns}" = ".." ] ; then
    need_autoconf=1
    ns_src_dir=${start_dir}/..
else
    ns_tar=naviserver-${version_ns}.tar.gz
    ns_url=https://downloads.sourceforge.net/sourceforge/naviserver/${ns_tar}
    ns_src_dir=naviserver-${version_ns}
fi

if [ ! "${version_modules}" = "HEAD" ] && [ ! "${version_modules}" = "GIT" ] ; then
    modules_src_dir=modules
    modules_tar=naviserver-${version_modules}-modules.tar.gz
    modules_url=https://downloads.sourceforge.net/sourceforge/naviserver/${modules_tar}
else
    modules_src_dir=modules-git
    modules_tar=
    modules_url=
fi



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
alpine=0
wolfi=0

make="make"
type="type -p"
tar="tar"


uname=$(uname)
if [ "$uname" = "Darwin" ] ; then
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
    if [ ${osxversionmajor} -gt 10 ] ; then
        ns_user_addcmd="sysadminctl -addUser ${ns_user} -UID ${newid}; dseditgroup -o edit -a ${ns_user} -t user ${ns_group}; dscl . -create /Users/${ns_user} PrimaryGroupID `dscl . -read  /Groups/nsadmin PrimaryGroupID | awk '{print $2}'`"
    elif [ ${osxversionminor} -ge 10 ] ; then
        ns_user_addcmd="sysadminctl -addUser ${ns_user} -UID ${newid}; dseditgroup -o edit -a ${ns_user} -t user ${ns_group}; dscl . -create /Users/${ns_user} PrimaryGroupID `dscl . -read  /Groups/nsadmin PrimaryGroupID | awk '{print $2}'`"
    else
        ns_user_addcmd="dscl . create /Users/${ns_user}; dscl . -create /Users/${ns_user} UniqueID ${newid}; dseditgroup -o edit -a ${ns_user} -t user ${ns_group}"
    fi

    ns_user_addgroup_hint="dseditgroup -o edit -a YOUR_USERID -t user ${ns_group}"

    #
    # Preconfigured for PostgreSQL 16 installed via MacPorts
    #
    pgversion=postgresql16

    if [ $with_postgres_driver = "1" ] ; then
        pg_incl=/opt/local/include/$pgversion/
        pg_lib=/opt/local/lib/$pgversion/
        pg_packages=$pgversion
    fi
    if [ $with_postgres = "1" ] ; then
        #
        # Also include the PostgreSQL "*-server" package
        #
        pg_packages="$pgversion $pgversion-server"
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

    elif [ -f "/etc/alpine-release" ] ; then
        alpine=1
        if [ $with_postgres_driver = "1" ] ; then
            pg_packages="libpq"
        fi
        if [ $with_postgres = "1" ] ; then
            pg_packages="postgresql ${pg_packages}"
        fi

    elif [ -f "/etc/os-release" ] ; then
        wolfi=1
        if [ $with_postgres_driver = "1" ] ; then
            pg_packages="libpq"
        fi
        if [ $with_postgres = "1" ] ; then
            pg_packages="postgresql ${pg_packages}"
        fi

    elif [ -f "/etc/arch-release" ] ; then
        archlinux=1
        if [ $with_postgres = "1" ] || [ $with_postgres_driver = "1" ] ; then
            pg_packages="postgresql"
        fi

    elif [ "$uname" = 'SunOS' ] ; then
        sunos=1
        make="gmake"
        export CC="gcc -m64"
        if [ $with_postgres = "1" ] ; then
            pg_packages="postgresql-960"
            pg_incl=/opt/pgsql960/include
            pg_lib=/opt/pgsql960/lib
        fi

    elif [ "$uname" = "FreeBSD" ] ; then
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

    elif [ "$uname" = "OpenBSD" ] ; then
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
    if [ "$uname" = "FreeBSD" ] ; then
        group_addcmd="pw groupadd ${ns_group}"
        ns_user_addcmd="pw useradd ${ns_user} -G ${ns_group} "
    elif [ "$uname" = "OpenBSD" ] ; then
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
(c) 2012-2023 Gustaf Neumann

Tested under macOS, Ubuntu 12.04, 13.04, 14.04, 16.04, 18.04, 20.04, Raspbian 9.4,
OmniOS r151014, OpenBSD 6.1, 6.3, 6.6, 6.8, 6.9 FreeBSD 12.2, 13.0, 14.0,
Fedora Core 18, 20, 32, 35, CentOS 7, Roxy Linux 8.4, ArchLinux, Alpine 3.18, 3.19

LICENSE    This program comes with ABSOLUTELY NO WARRANTY;
           This is free software, and you are welcome to redistribute it under certain conditions;
           For details see http://www.gnu.org/licenses.

SETTINGS   build_dir              (Build directory)                 ${build_dir}
           ns_install_dir         (Installation directory)          ${ns_install_dir}
           version_ns             (Version of NaviServer)           ${version_ns}
           git_branch_ns          (Branch for git checkout of ns)   ${git_branch_ns}
           version_modules        (Version of NaviServer Modules)   ${version_modules}
           version_tcllib         (Version of Tcllib)               ${version_tcllib}
           version_thread         (Version Tcl thread library)      ${version_thread}
           version_xotcl          (Version of NSF/NX/XOTcl)         ${version_xotcl}
           version_tcl            (Version of Tcl)                  ${version_tcl}
           version_tdom           (Version of tDOM)                 ${version_tdom}
           ns_user                (NaviServer user)                 ${ns_user}
           ns_group               (NaviServer group)                ${ns_group}
                                  (Make command)                    ${make}
                                  (Type command)                    ${type}
           ns_modules             (NaviServer Modules)              ${ns_modules}
           with_mongo             (Add MongoDB client and server)   ${with_mongo}
           with_postgres          (Install PostgreSQL DB server)    ${with_postgres}
           with_postgres_driver   (Add PostgreSQL driver support)   ${with_postgres_driver}
           with_ns_deprecated     (NaviServer with deprecated cmds) ${with_ns_deprecated}
           with_system_malloc     (Tcl compiled with system malloc) ${with_system_malloc}
           with_debug_flags       (Tcl and nsd compiled with debug) ${with_debug_flags}
           with_ns_doc            (NaviServer documentation)        ${with_ns_doc}"

if [ $with_postgres = "1" ] ; then
    echo "
           pg_user                (PostgreSQL user)                 ${pg_user}
                                  (PostgreSQL include)              ${pg_incl}
                                  (PostgreSQL lib)                  ${pg_lib}
                                  (PostgreSQL Packages)             ${pg_packages}
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

if [ "$do_clean" = "1" ] ; then
    rm -r ${tcl_src_dir}
    rm -r ${tcllib_src_dir}
    rm -rf naviserver-${version_ns}
    rm -rf modules modules-git
    rm -r ${thread_src_dir}
    rm -rf ${nsf_src_dir}
    rm -rf ${tdom_src_dir} tdom
fi

# just clean?
if [ "$clean_only" = "1" ] ; then
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
with_postgres_driver=${with_postgres_driver}
with_ns_deprecated=${with_ns_deprecated}
with_system_malloc=${with_system_malloc}
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
alpine=${alpine}
wolfi=${wolfi}
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
    if [ $debian = "1" ] || [ $macosx = "1" ] || [ $archlinux = "1" ] ; then
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
    need_git=1
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
        if [ "" = "$PKG_OK" ] ; then
            sudo apt-get install -y gnupg
            curl -s -L https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -
            echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/5.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list
            sudo apt-get update
            sudo apt-get install -y mongodb-org
        fi
        mongodb="libtool autoconf cmake"
    elif [ $debian = "1" ] ; then
        mongodb="libtool autoconf cmake mongodb"
   fi
fi

if [ "${need_git}" = "1" ] ; then
    git=git
else
    git=
fi

if [ "${need_autoconf}" = "1" ] ; then
    autoconf=autoconf
else
    autoconf=
fi
with_openssl_configure_flag=

if [ $debian = "1" ] ; then
    # On Debian/Ubuntu, make sure we have zlib installed, otherwise
    # NaviServer can't provide compression support
    apt-get install -y make ${autoconf} locales gcc zlib1g-dev \
            curl zip unzip openssl libssl-dev \
            ${pg_packages} ${git} ${mongodb}
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

    ${pkgmanager} install make ${autoconf} automake gcc zlib zlib-devel \
                  curl zip unzip openssl openssl-devel \
                  ${pg_packages} ${git} ${mongodb}
    export LANG=en_US.UTF-8
    localedef --verbose --force -i en_US -f UTF-8 en_US.UTF-8
fi

if [ $archlinux = "1" ] ; then
    pacman -Sy --noconfirm gcc make ${pg_packages}
fi

if [ $alpine = "1" ] ; then
    apk add musl-dev zlib openssl ${pg_packages}
    dev_packages="curl musl-dev gcc make zlib-dev openssl-dev autoconf automake patch"
    if [ $with_postgres_driver = "1" ] ; then
        dev_packages="${dev_packages} libpq-dev"
    fi
    apk add $dev_packages

fi

if [ $wolfi = "1" ] ; then
    apk add zlib openssl ${pg_packages}
    dev_packages="curl clang make zlib-dev openssl-dev autoconf automake patch"
    if [ $with_postgres_driver = "1" ] ; then
        dev_packages="${dev_packages} postgresql-dev"
    fi
    apk add $dev_packages

fi


if [ $macosx = "1" ] ; then
    port install ${autoconf} automake zlib curl zip unzip openssl \
         ${pg_packages} ${git} ${mongodb}
    with_openssl_configure_flag="--with-openssl=/opt/local"
fi

if [ $sunos = "1" ] ; then
    # packages for OpenSolaris/OmniOS
    pkg install pkg://omnios/developer/versioning/git \
        ${autoconf} automake /developer/gcc51 zlib \
        curl compress/zip compress/unzip \
        ${pg_packages} ${git} ${mongodb}
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
    pkg install gmake llvm openssl automake curl zip unzip \
        ${pg_packages} ${autoconf} ${git} ${mongodb}
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
    pkg_add gcc openssl curl zip unzip bash gmake \
            ${git} ${mongodb} ${pg_packages} autoconf-2.69p2 automake-1.15.1
    pkg_add autoconf-2.69p3
fi


echo "------------------------ Downloading sources ----------------------------"
set -o errexit

# Function to set a value in the pseudo-associative array
chksum_set_value() {
    local key=$(echo $1 | sed -r 's/[-.]/_/g')
    local value="$2"
    #echo setting "arr_${key}='$value'"
    eval "arr_${key}='$value'"
}

# Function to get a value from the pseudo-associative array
chksum_get_value() {
    local key=$(echo $1 | sed -r 's/[-.]/_/g')
    eval "echo \$arr_${key}"
}

#
# Set known checksum values.
#
# Do not save checksums for changing branches, such as:
#
#chksum_set_value tcl-core-8-6-14-rc.tar.gz 4a8834f8b7ec68087e21a05779758956d559c88491cc43020d445ff3edaabaab

chksum_set_value tcl8.6.13-src.tar.gz      43a1fae7412f61ff11de2cfd05d28cfc3a73762f354a417c62370a54e2caf066
chksum_set_value tcl8.6.14-src.tar.gz      5880225babf7954c58d4fb0f5cf6279104ce1cd6aa9b71e9a6322540e1c4de66
chksum_set_value tcl8.6.15-src.tar.gz      861e159753f2e2fbd6ec1484103715b0be56be3357522b858d3cbb5f893ffef1
chksum_set_value tcl8.6.16-src.tar.gz      91cb8fa61771c63c262efb553059b7c7ad6757afa5857af6265e4b0bdc2a14a5
chksum_set_value tcl9.0.0-src.tar.gz       3bfda6dbaee8e9b1eeacc1511b4e18a07a91dff82d9954cdb9c729d8bca4bbb7
chksum_set_value tcl9.0.1-src.tar.gz       a72b1607d7a399c75148c80fcdead88ed3371a29884181f200f2200cdee33bbc

chksum_set_value tcl-core-8-5-19.tar.gz    45bf6624144d063e12dcc840a27d9edfedf9a4d33c8362f95f718a2ea7e799a1
chksum_set_value tcl-core-8-6-14.tar.gz    4a8834f8b7ec68087e21a05779758956d559c88491cc43020d445ff3edaabaab
chksum_set_value tcl-core-8-6-13.tar.gz    69d4b1192a3ad94c1748e1802c5cf727b2dbba400f5560407f9af19f3d8fd6b3
chksum_set_value tcl-core-8-6-15.tar.gz    40a6432db8bd9e5725582d758352c15f7dcacfc33c58f10599cdc3f709f4c2bd
chksum_set_value tcl-core-8-6-16.tar.gz    a142d2c6f6ca979c5747e9fd6c8220d7b0a783412b46e9bda0ee7baafedba258
chksum_set_value tcl-core-8-7-a5.tar.gz    7dd250dc6a76af47f3fc96b218906cfd166edf63c5d142186d632b500a6030eb

chksum_set_value tcllib-1.20.tar.gz        e3b097475bcb93c4439df4a088daa59592e1937beee2a2c8495f4f0303125d71
chksum_set_value tcllib-2.0.tar.gz         590263de0832ac801255501d003441a85fb180b8ba96265d50c4a9f92fde2534

chksum_set_value tdom-0.9.1-src.tgz        3b1f644cf07533fe4afaa8cb709cb00a899d9e9ebfa66f4674aa2dcfb398242c
chksum_set_value tdom-0.9.3-src.tgz        b46bcb6750283bcf41bd6f220cf06e7074752dc8b9a87a192bd81e53caad53f9
chksum_set_value tdom-0.9.4-src.tgz        f947d38cbb7978ec1510e3cf894a672a4ad18cb823b8c9bb3604934ebe4c4546
chksum_set_value tdom-0.9.5-src.tgz        ce22e3f42da9f89718688bf413b82fbf079b40252ba4dd7f2a0e752232bb67e8

chksum_set_value nsf2.3.0.tar.gz           3940c4c00e18900abac8d57c195498f563c3cdb65157257af57060185cfd7ba9
chksum_set_value nsf2.4.0.tar.gz           51bd956d8db19f9bc014bec0909f73659431ce83f835c479739b5384d3bcc1f6

#chksum_set_value thread-thread-2-8-branch.tar.gz 1674cd723f175afc55912694b01d1918539eefc3d2e8fef0b8b509f7ae77d490
chksum_set_value thread-thread-2-8-branch.tar.gz 21d69cfb8a010957398ee6fd41a03a770941803971ae0b5d17229684cec6ce88

# Get and print a value
# echo "The value of key1 is: $(chksum_get_value "tdom-0.9.1-src.tgz")"

function fail {
  echo $1 >&2
  exit 1
}

function retry {
  local n=1
  local max=5
  local delay=15
  while true; do
    "$@" && break || {
      if [[ $n -lt $max ]]; then
          ((n++))
          echo "Command failed. Attempt $n/$max, error code: $?"
          sleep $delay;
      else
          # fail "The command has failed after $n attempts."
          echo "The command has failed after $n attempts."
          return
      fi
    }
  done
}

function download_file() {
    local target_filename="$1"
    local download_url="$2"

    local provided_checksum=$(chksum_get_value ${target_filename})
    local max_attempts=5
    local attempt=1
    local openssl=$(${type} openssl)
    local sha256sum=$(${type} sha256sum)
    local shasum=$(${type} shasum)

    #echo openssl $openssl sha256sum $sha256sum shasum $shasum

    while [ $attempt -le $max_attempts ]; do
        echo "Downloading ($attempt) ${target_filename} from ${download_url} ..."
        if [ $attempt = $((max_attempts-1)) ] ; then
            extraflags="--http1.1"
        elif [ $attempt = $max_attempts ] ; then
            extraflags="--max-time 300 --connect-timeout 300 --keepalive-time 300 -v --trace-time"
        else
            extraflags=""
        fi

        #
        # Make sure, we check after the download the retrieved file.
        #
        rm -f ${target_filename}
        #
        # The function "retry" is used for commands ending with an
        # error return code.
        #
        retry curl $extraflags -H "Connection: close" -L -s -k -o  "${target_filename}" "$download_url"

        if [ ! -f ${target_filename} ] ; then
            #
            # We got no file.
            #
            local actual_checksum="download failed"
        else
            #
            # A file was downloaded
            #
            if [ "$openssl" != "" ] ; then
                local actual_checksum=$(openssl dgst -sha256 "${target_filename}" | sed -e 's/.* //')
            elif [ "$sha256sum" != "" ] ; then
                local actual_checksum=$(sha256sum "${target_filename}" | sed -e 's/\s.*$//')
            elif [ "$shasum" != "" ] ; then
                local actual_checksum=$(shasum -a 256 "${target_filename}" | sed -e 's/\s.*$//')
            else
                local actual_checksum=
            fi
        fi

        if [ "${provided_checksum}" = "" ] ; then
            echo "   no checksum provided, consider setting:"
            echo "   chksum_set_value ${target_filename} ${actual_checksum}"
            break
        fi
        if [ "${provided_checksum}" = "${actual_checksum}" ] ; then
            echo "... checksum of ${target_filename} OK"
            break
        fi
        if [ "${actual_checksum}" = "" ] ; then
            echo "... do not know how to compute checksum of ${target_filename} on this system"
            break
        fi

        echo "Checksums differ for ${target_filename}"
        echo "    Provided checksum : ${provided_checksum}"
        echo "    Actual checksum   : ${actual_checksum}"
        echo "    Downloadeded      :" `ls -l "${target_filename}"`

        attempt=$((attempt + 1))
        sleep 1 # Wait a bit before retrying
    done

    if [ $attempt -gt $max_attempts ]; then
        echo "Failed to download the file after $max_attempts attempts."
        exit 1
    fi
}

if [ "${tcl_fetch_always}" = "1" ] ; then
    rm -f ${tcl_tar}
fi

if [ ! -f ${tcl_tar} ] ; then
    #https://github.com/tcltk/tcl/archive/refs/tags/core-8-6-12.tar.gz
    #echo "Downloading ${tcl_tar} from ${tcl_url} ..."
    #curl -L -s -k -o ${tcl_tar} ${tcl_url}
    #curl --max-time 300 --connect-timeout 300 --keepalive-time 300 -v --trace-time \
    #     -L -s -k -o ${tcl_tar} ${tcl_url}
    download_file $tcl_tar $tcl_url
else
    echo "No need to fetch ${tcl_tar} (already available)"
fi

if [ ! "${thread_tar}" = "" ] ; then
    if [ ! -f ${thread_tar} ] ; then
        download_file ${thread_tar} ${thread_url}
    else
        echo "No need to fetch ${thread_tar} (already available)"
    fi
fi


if [ ! -f ${tcllib_tar} ] ; then
    download_file ${tcllib_tar} ${tcllib_url}
fi

# All versions of tcllib up to 1.15 were named tcllib-*.
# tcllib-1.16 was named a while Tcllib-1.16 (capital T), but has been renamed later
# to the standard naming conventions. tcllib-1.17 is fine again.
#if [ ! -f ${tcllib_tar} ] ; then
#    curl -L -s -k -o ${tcllib_tar} https://downloads.sourceforge.net/sourceforge/tcllib/Tcllib-${version_tcllib}.tar.bz2
#    tcllib_src_dir=Tcllib
#fi

if [ ! "${version_ns}" = ".." ] ; then
    if [ ! "${ns_tar}" = "" ] ; then
        if [ ! -f ${ns_tar} ] ; then
            download_file ${ns_tar} ${ns_url}
            #echo "Downloading ${ns_tar} ..."
            #curl -L -s -k -o ${ns_tar} ${ns_url}
        fi
    else
        if [ ! -d naviserver ] ; then
            git clone https://github.com/naviserver-project/naviserver.git
        else
            cd ${build_dir}/naviserver
            git pull
        fi
        if [ ! "${git_branch_ns}" = "" ] ; then
            cd ${build_dir}/naviserver
            git checkout ${git_branch_ns}
        fi
    fi
fi

cd ${build_dir}
if [ ! "${modules_tar}" = "" ] ; then
    if [ ! -f ${modules_tar} ] ; then
        #echo "Downloading ${modules_tar} ..."
        #curl -L -s -k -o ${modules_tar} ${modules_url}
        download_file ${modules_tar} ${modules_url}
    fi
    ${tar} zxf naviserver-${version_modules}-modules.tar.gz
else
    if [ ! -d ${modules_src_dir} ] ; then
        mkdir ${modules_src_dir}
    fi

    modules='
        letsencrypt
        nsaccess
        nsaspell
        nsauthpam
        nschartdir
        nsclamav
        nscoap
        nsconf
        nsdbbdb
        nsdbi
        nsdbilite
        nsdbimy
        nsdbipg
        nsdbmysql
        nsdbpg
        nsdbsqlite
        nsdbtds
        nsdhcpd
        nsdns
        nsexample
        nsexpat
        nsfortune
        nsgdchart
        nsicmp
        nsimap
        nsldap
        nsldapd
        nsloopctl
        nsmemcache
        nsocaml
        nsoracle
        nsphp
        nsradiusd
        nsrtsp
        nssavi
        nsshell
        nssip
        nssmtpd
        nssnmp
        nsstats
        nssys
        nssyslogd
        nstftpd
        nstk
        nsudp
        nsvfs
        nswebpush
        nszlib
        revproxy
        websocket
    '
    cd ${modules_src_dir}
    for module in ${ns_modules}
    do
        if [ ! -d $module ] ; then
            git clone https://github.com/naviserver-project/$module
        else
            cd $module
            git pull
            cd ..
        fi
    done
fi

cd ${build_dir}

if [ ! "${version_xotcl}" = "HEAD" ] ; then
    if [ ! -f ${nsf_tar} ] ; then
        #echo "Downloading ${nsf_tar} from ${nsf_url} ..."
        #curl -L -s -k -o ${nsf_tar} ${nsf_url}
        download_file ${nsf_tar} ${nsf_url}
    fi
else
    if [ ! -d nsf ] ; then
        #git clone https://github.com/nm-wu/nsf.git
        git clone https://github.com/gustafn/nsf.git
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

if [ ! "${version_tdom}" = "GIT" ] ; then
    if [ ! -f ${tdom_tar} ] ; then
        #echo "Downloading ${tdom_tar} from ${tdom_url}"
        rm -rf ${tdom_src_dir} ${tdom_tar}
        #curl --max-time 300 --connect-timeout 300 --keepalive-time 300 -v --trace-time \
        #     -L -s -k -o ${tdom_tar} ${tdom_url}
        #curl -L -s -k -o ${tdom_tar} ${tdom_url}
        download_file $tdom_tar $tdom_url
        #echo "... download from ${tdom_url} finished."
    else
        echo "No need to fetch ${tdom_tar} (already available)"
    fi
    ${tar} zxf ${tdom_tar}
else
    if [ ! -f "tdom/${version_tdom_git}" ] ; then
        #
        # Get the newest version of tDOM from git
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

rm -rf ${tcl_src_dir}
${tar} xfz ${tcl_tar}

set +o errexit
cd ${tcl_src_dir}
TCL9=$(grep 'define.*TCL_MAJOR_VERSION.*9' generic/tcl.h)
if [ "${TCL9}" = "" ] ; then
    enable_threads=""
else
    enable_threads="--enable-threads"
fi

set -o errexit

if [ $with_system_malloc = "1" ] ; then
    cd ${tcl_src_dir}
    echo "patching Tcl with SYSTEM malloc patch ..."
    if [ "${TCL9}" = "" ] ; then
        #
        # Tcl 8.*
        #
        patch_file=tcl86-system-malloc.patch
        cat <<EOF > $patch_file
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
        patch -p0 --fuzz=3 < $patch_file
    else
        #
        # Tcl 9.*
        #
        patch_file=tcl9-system-malloc.patch
        cat <<EOF > $patch_file
--- generic/tclThreadAlloc.c-orig	2024-09-23 01:12:41.711892003 +0000
+++ generic/tclThreadAlloc.c	2024-09-23 01:12:41.711892003 +0000
@@ -297,7 +297,15 @@
  *
  *----------------------------------------------------------------------
  */
-
+#define SYSTEM_MALLOC 1
+#if defined(SYSTEM_MALLOC)
+void *
+TclpAlloc(
+    size_t numBytes)     /* Number of bytes to allocate. */
+{
+    return malloc(numBytes);
+}
+#else
 void *
 TclpAlloc(
     size_t reqSize)
@@ -345,6 +353,7 @@
     }
     return Block2Ptr(blockPtr, bucket, reqSize);
 }
+#endif
 
 /*
  *----------------------------------------------------------------------
@@ -361,7 +370,15 @@
  *
  *----------------------------------------------------------------------
  */
-
+#if defined(SYSTEM_MALLOC)
+void
+TclpFree(
+    void *ptr)         /* Pointer to memory to free. */
+{
+    free(ptr);
+    return;
+}
+#else
 void
 TclpFree(
     void *ptr)
@@ -404,6 +421,7 @@
 	PutBlocks(cachePtr, bucket, bucketInfo[bucket].numMove);
     }
 }
+#endif
 
 /*
  *----------------------------------------------------------------------
@@ -420,7 +438,15 @@
  *
  *----------------------------------------------------------------------
  */
-
+#if defined(SYSTEM_MALLOC)
+void *
+TclpRealloc(
+    void *oldPtr,              /* Pointer to alloced block. */
+    size_t numBytes)     /* New size of memory. */
+{
+    return realloc(oldPtr, numBytes);
+}
+#else
 void *
 TclpRealloc(
     void *ptr,
@@ -485,6 +511,7 @@
     }
     return newPtr;
 }
+#endif
 
 /*
  *----------------------------------------------------------------------
EOF
        patch -p0 < $patch_file
    fi
    cd ..
    echo "patching Tcl with SYSTEM malloc patch $patch_file DONE"
fi

rm -rf ${tcl_src_dir}/pkgs/sqlit* ${tcl_src_dir}/pkgs/itcl* ${tcl_src_dir}/pkgs/tdbc*

cd ${tcl_src_dir}/unix
echo PWD=`pwd`
echo Running: ./configure ${enable_threads} --prefix=${ns_install_dir}
./configure ${enable_threads} --prefix=${ns_install_dir}
#./configure ${enable_threads} --prefix=${ns_install_dir} --with-naviserver=${ns_install_dir}

if [ "${with_debug_flags}" = "1" ] ; then
    sed -i.bak -e 's/-DNDEBUG=1//' -e 's/-DNDEBUG//' Makefile
    extra_debug_flags="CFLAGS_OPTIMIZE=-O0 -g"
else
    extra_debug_flags="EXTRA_DEBUG_FLAGS="
fi

echo "Compiling Tcl with extra flags: ${extra_debug_flags}"
${make} -j4 "${extra_debug_flags}"
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

${tar} xf ${tcllib_tar}
#export TCL_PKG_PREFER_LATEST=1
cd ${tcllib_src_dir}
sed -i.bak '/package require Tcl 8.2/d' installer.tcl
./configure --prefix=${ns_install_dir}
${make} install
cd ..

echo "------------------------ Installing NaviServer ---------------------------"

cd ${build_dir}

if [ ! "${ns_tar}" = "" ] ; then
    ${tar} zxvf ${ns_tar}
    cd ${ns_src_dir}
    ./configure --with-tcl=${ns_install_dir}/lib --prefix=${ns_install_dir} ${with_openssl_configure_flag}
else
    cd ${ns_src_dir}
    if [ ! -f configure ] ; then
        echo PWD=`pwd` PATH=${PATH}
        ls -1ltr
        echo version_ns=${version_ns} start_dir=${start_dir} ns_src_dir=${ns_src_dir}
        bash autogen.sh --with-tcl=${ns_install_dir}/lib --prefix=${ns_install_dir} ${with_openssl_configure_flag}
    else
        ./configure --with-tcl=${ns_install_dir}/lib --prefix=${ns_install_dir} ${with_openssl_configure_flag}
    fi
fi

#
# We have no extra section in general for these flags, so we use sed
# to update the structures available cross versions. This is fragile.
#
if [ "${with_debug_flags}" = "1" ] ; then
    sed -i.bak -e 's/-DNDEBUG=1//' -e 's/-DNDEBUG//' include/Makefile.global
    extra_debug_flags="CFLAGS_OPTIMIZE=-O0 -g"
else
    extra_debug_flags="EXTRA_DEBUG_FLAGS="
fi

if  [ "${with_ns_deprecated}" = "0" ] ; then
    sed -i.bak -e 's/-std=c99/-DNS_NO_DEPRECATED -std=c99/' include/Makefile.global
fi

${make} clean

echo "Compiling NaviServer with extra flags: ${extra_debug_flags}"
${make} -j4 all "${extra_debug_flags}"

if [ "${version_ns}" = "HEAD" ] || [ "${version_ns}" = "GIT" ] || [ "${version_ns}" = ".." ] ; then
    if [ ! "${with_ns_doc}" = "0" ] ; then
        ${make} "DTPLITE=${ns_install_dir}/bin/tclsh $ns_install_dir/bin/dtplite" build-doc
    fi
fi
${make} install
cd ${build_dir}

for module in ${ns_modules}
do
    echo "------------------------ Installing modules/${module} ----------------------"
    cd ${modules_src_dir}/${module}

    if [ "${module}" = "nsdbpg" ] || [ "${module}" = "nsdbipg" ] ; then
        ${make} PGLIB=${pg_lib} PGINCLUDE=${pg_incl} NAVISERVER=${ns_install_dir} "${extra_debug_flags}"
        ${make} NAVISERVER=${ns_install_dir} install
    else
        ${make} NAVISERVER=${ns_install_dir} "${extra_debug_flags}"
        ${make} NAVISERVER=${ns_install_dir} install
    fi
    cd ${build_dir}
done


if [ "${thread_tar}" = "" ] ; then
    # Use the thread library as distributed with Tcl
    echo "------------------------ Compile and install libthread from Tcl Sources ------------------"
    cd ${build_dir}/${tcl_src_dir}/pkgs/thread*
    ./configure ${enable_threads} --prefix=${ns_install_dir} --with-tcl=${ns_install_dir}/lib \
                --with-naviserver=${ns_install_dir}
    ${make} clean
    ${make} install
    cd ${build_dir}

else
    echo "------------------------ Compile and install libthread from ${thread_tar} ----------------"

    rm -rf ${thread_src_dir}
    ${tar} xfz ${thread_tar}

    if [ ! -f ${thread_src_dir}/tclconfig ] ; then
        url=https://core.tcl-lang.org/tclconfig/tarball/tclconfig.tar.gz?uuid=tcl8-compat
        download_file tclconfig.tar.gz $url
        tar xf tclconfig.tar.gz
        ln -s ${build_dir}/tclconfig ${thread_src_dir}/tclconfig
    else
        echo "No need to fetch tclconfig (already available)"
    fi

    cd ${thread_src_dir}/unix/
    ../configure ${enable_threads} --prefix=${ns_install_dir} --exec-prefix=${ns_install_dir} \
                 --with-tcl=${ns_install_dir}/lib \
                 --with-naviserver=${ns_install_dir}
    make
    ${make} install
    #
    # Copy installed naviserver flavor of libthread to a special name.
    # Use for the time being "cp" instead of "mv" to keep old
    # configuration (not expeclsting the suffix) files working.
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

if [ ! "${version_xotcl}" = "HEAD" ] ; then
    ${tar} xfz ${nsf_tar}
fi
cd ${nsf_src_dir}

#export CC=gcc

if [ $with_mongo = "1" ] ; then
    echo "------------------------ WITH MONGO"

    ./configure ${enable_threads} --enable-symbols \
                --prefix=${ns_install_dir} --exec-prefix=${ns_install_dir} --with-tcl=${ns_install_dir}/lib \
                --with-nsf=../../ \
                --with-mongoc=/usr/local/include/libmongoc-1.0/,/usr/local/lib/ \
                --with-bson=/usr/local/include/libbson-1.0,/usr/local/lib/
else
    ./configure ${enable_threads} --enable-symbols \
                --prefix=${ns_install_dir} --exec-prefix=${ns_install_dir} --with-tcl=${ns_install_dir}/lib
fi

if [ "$with_debug_flags" = "1" ] ; then
    sed -i.bak -e 's/-DNDEBUG=1//' -e 's/-DNDEBUG//' Makefile
    ${make} CFLAGS_OPTIMIZE=-g
else
    ${make}
fi
${make} install
cd ..

echo "------------------------ Installing tDOM --------------------------------"

if [ "${version_tdom}" = "GIT" ] ; then
    cd tdom
    if [ ! -f "${version_tdom_git}" ] ; then
        git checkout "${version_tdom_git}"
        echo > "${version_tdom_git}"
    fi
    cd unix
else
    #${tar} xfz tDOM-${version_tdom}.tgz
    cd ${tdom_src_dir}/unix
fi
../configure ${enable_threads} --disable-tdomalloc --prefix=${ns_install_dir} --exec-prefix=${ns_install_dir} --with-tcl=${ns_install_dir}/lib
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
#################################################################
if [ "$alpine" = "1" ] || [ "$wolfi" = "1" ] ; then
    echo "You might consider to cleanup develoment packages:"
    echo "        apk del git $dev_packages"
fi
