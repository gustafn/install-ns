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

version_ns=${version_ns:-4.99.24}
#version_ns=GIT
git_branch_ns=${git_branch_ns:-main}
version_modules=${version_modules:-${version_ns}}
#version_modules=HEAD

#version_tcl=8.5.19
version_tcl=${version_tcl:-8.6.12}
version_tcllib=${version_tcllib:-1.20}
version_thread=""
#version_thread=2.8.2
#version_thread=2.8.6
version_xotcl=${version_xotcl:-2.4.0}
#version_xotcl=HEAD
#version_tdom=GIT
version_tdom=${version_tdom:-0.9.1}
version_tdom_git="master@{2014-11-01 00:00:00}"
ns_user=${ns_user:-nsadmin}
ns_group=${ns_group:-nsadmin}
with_mongo=${with_mongo:-0}
with_system_malloc=${with_system_malloc:-0}
with_ns_doc=${with_ns_doc:-1}

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
pg_incl=/usr/include/postgresql
pg_lib=/usr/lib
pg_user=postgres


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
    echo "${version_tcl} contains a DOT -> fetch from sourceforge"
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

if [ "${version_thread}" = "" ] && [ ${tcl_fetch_from_core} = "1" ] ; then
    if [ "${version_tcl}" = "trunk" ] ; then
        version_thread=trunk
    elif [[ ${version_tcl} == *"8-5"* ]] ; then
        version_thread=thread-2-6
    else
        version_thread=thread-2-8-branch
    fi
    thread_fetch_from_core=1
    thread_url=https://core.tcl-lang.org/thread/tarball/thread.tar.gz?uuid=${version_thread}
    thread_tar=thread.tar.gz
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
    else
        #
        # Newer versions of tdom have "-src" as root directory.
        #
        tdom_src_dir=tdom-${version_tdom}-src
    fi
    tdom_tar=tdom-${version_tdom}-src.tgz
    # tdom.org/downloads/ does not work reliably inside github actions
    #tdom_url=http://tdom.org/downloads/${tdom_tar}
    tdom_url=https://openacs.org/downloads/${tdom_tar}
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

make="make"
type="type -a"
tar="tar"

pg_packages=

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
           with_mongo             (Add MongoDB client and server)   ${with_mongo}
           with_postgres          (Install PostgreSQL DB server)    ${with_postgres}
           with_postgres_driver   (Add PostgreSQL driver support)   ${with_postgres_driver}
           with_system_malloc     (Tcl compiled with system malloc) ${with_system_malloc}
           with_ns_doc            (NaviServer documentation)        ${with_ns_doc}"

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

if [ "${tcl_fetch_always}" = "1" ] ; then
    rm -f ${tcl_tar}
fi

if [ ! -f ${tcl_tar} ] ; then
    #https://github.com/tcltk/tcl/archive/refs/tags/core-8-6-12.tar.gz
    echo "Downloading ${tcl_tar} ..."
    curl -L -s -k -o ${tcl_tar} ${tcl_url}
else
    echo "No need to fetch ${tcl_tar} (already available)"
fi

if [ ! "${thread_tar}" = "" ] ; then
    if [ ! -f ${thread_tar} ] ; then
        echo "Downloading ${thread_tar} ..."
        curl -L -s -k -o ${thread_tar} ${thread_url}
    else
        echo "No need to fetch ${thread_tar} (already available)"
    fi
fi


if [ ! -f ${tcllib_tar} ] ; then
    echo "Downloading ${tcllib_tar} ..."
    curl -L -s -k -o ${tcllib_tar} ${tcllib_url}
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
            echo "Downloading ${ns_tar} ..."
            curl -L -s -k -o ${ns_tar} ${ns_url}
        fi
    else
        if [ ! -d naviserver ] ; then
            git clone https://bitbucket.org/naviserver/naviserver
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
        echo "Downloading ${modules_tar} ..."
        curl -L -s -k -o ${modules_tar} ${modules_url}
    fi
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
    modules=nsdbpg
    cd ${modules_src_dir}
    for d in ${modules}
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

if [ ! "${version_xotcl}" = "HEAD" ] ; then
    if [ ! -f ${nsf_tar} ] ; then
        echo "Downloading ${nsf_tar} ..."
        curl -L -s -k -o ${nsf_tar} ${nsf_url}
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

if [ ! "${version_tdom}" = "GIT" ] ; then
    if [ ! -f ${tdom_tar} ] ; then
        echo "Downloading ${tdom_tar} from ${tdom_url}"
        rm -rf ${tdom_src_dir} ${tdom_tar}
        curl --max-time 300 --connect-timeout 300 --keepalive-time 300 -v --trace-time \
             -L -s -k -o ${tdom_tar} ${tdom_url}
        echo "... download from ${tdom_url} finished."
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
set -o errexit

rm -rf ${tcl_src_dir}
${tar} xfz ${tcl_tar}

if [ $with_system_malloc = "1" ] ; then
    cd ${tcl_src_dir}
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

rm -rf  ${tcl_src_dir}/pkgs/sqlit*

cd ${tcl_src_dir}/unix
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

${tar} xf ${tcllib_tar}
cd ${tcllib_src_dir}
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
        bash autogen.sh --enable-threads --with-tcl=${ns_install_dir}/lib --prefix=${ns_install_dir} ${with_openssl_configure_flag}
    else
        ./configure --enable-threads --with-tcl=${ns_install_dir}/lib --prefix=${ns_install_dir} ${with_openssl_configure_flag}
    fi
fi
${make}

if [ "${version_ns}" = "HEAD" ] || [ "${version_ns}" = "GIT" ] || [ "${version_ns}" = ".." ] ; then
    if [ ! "${with_ns_doc}" = "0" ] ; then
        ${make} "DTPLITE=${ns_install_dir}/bin/tclsh $ns_install_dir/bin/dtplite" build-doc
    fi
fi
${make} install
cd ${build_dir}

if [ "${with_postgres_driver}" = "1" ] ; then

    echo "------------------------ Installing Modules/nsdbpg ----------------------"
    cd ${build_dir}
    if [ ! "${version_modules}" = "HEAD" ] && [ ! "${version_modules}" = "GIT" ] ; then
        ${tar} zxvf naviserver-${version_modules}-modules.tar.gz
    fi
    cd ${modules_src_dir}/nsdbpg
    ${make} PGLIB=${pg_lib} PGINCLUDE=${pg_incl} NAVISERVER=${ns_install_dir}
    ${make} NAVISERVER=${ns_install_dir} install

    cd ${build_dir}
fi

if [ "${thread_tar}" = "" ] ; then
    # Use the thread library as distributed with Tcl
    echo "------------------------ Compile and install libthread from Tcl Sources ------------------"
    cd ${build_dir}/${tcl_src_dir}/pkgs/thread*
    ./configure --enable-threads --prefix=${ns_install_dir} --with-naviserver=${ns_install_dir}
    ${make} clean
    ${make} install
    cd ${build_dir}

else
    echo "------------------------ Compile and install libthread from ${thread_tar} ----------------"

    rm -rf ${thread_src_dir}
    ${tar} xfz ${thread_tar}

    if [ ! -f ${thread_src_dir}/tclconfig ] ; then
        echo "Downloading tclconfig"
        url=https://core.tcl-lang.org/tclconfig/tarball/tclconfig.tar.gz?uuid=tcl8-compat
        curl -L -s -k -o tclconfig.tar.gz $url
        tar xf tclconfig.tar.gz
        ln -s ${build_dir}/tclconfig ${thread_src_dir}/tclconfig
    else
        echo "No need to fetch tclconfig (already available)"
    fi

    cd ${thread_src_dir}/unix/
    ../configure --enable-threads --prefix=${ns_install_dir} --exec-prefix=${ns_install_dir} --with-naviserver=${ns_install_dir} --with-tcl=${ns_install_dir}/lib
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
