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
# Installation directory and software versions to be installed

build_dir=/usr/local/src
#build_dir=/usr/local/src/oo2
ns_install_dir=/usr/local/ns
#ns_install_dir=/usr/local/oo2
version_ns=4.99.6
#version_ns=HEAD
version_modules=4.99.6
#version_modules=HEAD
version_tcl=8.5.16
version_tcllib=1.15
version_thread=2.7.0
version_xotcl=2.0b5
#version_xotcl=HEAD
version_tdom=0.8.3
ns_user=nsadmin
ns_group=nsadmin
with_mongo=0
with_postgres=1
#
# the pg_* variables should be the path leading to the include and
# library file of postgres to be used in this build.  In particular,
# "libpg-fe.h" and "libpq.so" are typically needed.
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

make="make"
type="type -a"

pg_packages=

uname=$(uname)
if [ $uname = "Darwin" ] ; then
    macosx=1
    group_listcmd="dscl . list /Groups | grep ${ns_group}"
    group_addcmd="dscl . create /Groups/${ns_group}"
    ns_user_addcmd="dscl . create /Users/${ns_user};dseditgroup -o edit -a ${ns_user} -t user ${ns_group}"
    ns_user_addgroup_hint="dseditgroup -o edit -a YOUR_USERID -t user ${ns_group}"

    if [ $with_postgres = "1" ] ; then
	# Preconfigured for PostgreSQL 9.3 installed via mac ports
	pg_incl=/opt/local/include/postgresql93/
	pg_lib=/opt/local/lib/postgresql93/
	pg_packages="postgresql93 postgresql93-server"
    fi
else
    if [ -f "/etc/debian_version" ] ; then
	debian=1
	if [ $with_postgres = "1" ] ; then
	    pg_packages="postgresql libpq-dev"
	fi
    elif [ -f "/etc/redhat-release" ] ; then
	redhat=1
	if [ $with_postgres = "1" ] ; then
	    pg_packages="postgresql postgresql-devel"
	fi
    elif [ $uname = 'SunOS' ] ; then
	sunos=1
	make="gmake"
	export CC="gcc -m64"
	if [ $with_postgres = "1" ] ; then
	    pg_packages="postgresql-927"
	    pg_incl=/opt/pgsql927/include
            pg_lib=/opt/pgsql927/lib
	fi
    elif [ $uname = "FreeBSD" ] ; then
        freebsd=1
        make="gmake"
	type="type"
        # adjust following to local gcc version:
        setenv CC="/usr/local/bin/gcc49"
	if [ $with_postgres = "1" ] ; then
            # for freebsd10, file is: /usr/local/include/postgresql/internal/postgres_fe.h so:
            #pg_incl=/usr/local/include/postgresql/internal
            pg_incl=/usr/local/include
            pg_lib=/usr/local/lib
	fi
    fi
    group_listcmd="grep ${ns_group} /etc/group"
    group_addcmd="groupadd ${ns_group}"
    ns_user_addcmd="useradd -g ${ns_group} ${ns_user}"
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
(c) 2012-2014 Gustaf Neumann

Tested under Mac OS X and Ubuntu 12.04 and 13.04

LICENSE    This program comes with ABSOLUTELY NO WARRANTY;
           This is free software, and you are welcome to redistribute it under certain conditions;
           For details see http://www.gnu.org/licenses.

SETTINGS   Build-Dir             ${build_dir}
           Install-Dir           ${ns_install_dir}
           NaviServer            ${version_ns}
           NaviServer Modules    ${version_modules}
           Tcllib                ${version_tcllib}
           Thread                ${version_thread}
           NSF/NX/XOTcl          ${version_xotcl}
           Tcl                   ${version_tcl}
           tDOM                  ${version_tdom}
           NaviSever user        ${ns_user}
           NaviServer group      ${ns_group}
           Make command          ${make}
           Type command          ${type}
           With Mongo            ${with_mongo}
           With PostgreSQL       ${with_postgres}"
if [ ${with_postgres} = "1" ] ; then
    echo "
           PostgresSQL user      ${pg_user}
           postgres/include      ${pg_incl}
           postgres/lib          ${pg_lib}
           PostgresSQL Packages  ${pg_packages}
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
# First we clean up

# The cleanup on the installation dir is optional, since it might
# delete something else not from our installation.
#rm -rf ${ns_install_dir}

mkdir -p ${build_dir}
cd ${build_dir}

if [ $do_clean = 1 ] ; then
    #rm    tcl${version_tcl}-src.tar.gz
    rm -r tcl${version_tcl}
    #rm    tcllib-${version_tcllib}.tar.bz2
    rm -r tcllib-${version_tcllib}
    #rm    naviserver-${version_ns}.tar.gz
    rm -rf naviserver-${version_ns}
    #rm    naviserver-${version_ns}-modules.tar.gz
    rm -r modules
    #rm    thread${version_thread}.tar.gz
    rm -r thread${version_thread}
    #rm    nsf${version_xotcl}.tar.gz
    rm -rf nsf${version_xotcl}
    #rm    tDOM-${version_tdom}.tgz
    rm -r tDOM-${version_tdom}
fi

# just clean?
if [ $clean_only = "1" ] ; then
  exit
fi

echo "------------------------ Save config variables in ${ns_install_dir}/lib/nsConfig.sh"
cat << EOF > ${ns_install_dir}/lib/nsConfig.sh
build_dir=${build_dir}
ns_install_dir=${ns_install_dir}
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
pg_incl=${pg_incl}
pg_lib=${pg_lib}
make=${make}
type=${type}
debian=${debian}
redhat=${redhat}
macosx=${macosx}
sunos=${sunos}
freebsd=${freebsd}
EOF

echo "------------------------ Check User and Group --------------------"

group=$(eval ${group_listcmd})
echo "${group_listcmd} => $group"
if [ "x$group" = "x" ] ; then
    eval ${group_addcmd}
fi

id=$(id -u ${ns_user})
if [ $? != "0" ] ; then
    if  [ $debian = "1" ] ; then
	eval ${ns_user_addcmd}
    else
	echo "User ${ns_user} does not exist; you might add it with something like"
	echo "     ${ns_user_addcmd}"
	exit
    fi
fi

echo "------------------------ System dependencies ---------------------------------"
if [ $with_mongo = "1" ] ; then
    mongodb=mongodb
else
    mongodb=
fi

if [ $with_mongo = "1" ] || [ $version_xotcl = "HEAD" ] ; then
    git=git
else
    git=
fi

if [  $version_ns = "HEAD" ] ; then
    mercurial=mercurial
    autoconf=autoconf
else
    mercurial=
    autoconf=
fi

if [ $debian = "1" ] ; then
    # On Debian/Ubuntu, make sure we have zlib installed, otherwise
    # naviserver can't provide compression support
    apt-get install make ${autoconf} gcc zlib1g-dev wget ${pg_packages} ${mercurial} ${git} ${mongodb}
fi
if [ $redhat = "1" ] ; then
    # packages for FC/RHL
    yum install make ${autoconf} gcc zlib wget ${pg_packages} ${mercurial} ${git} ${mongodb}
fi

if [ $macosx = "1" ] ; then
    port install make ${autoconf} zlib wget ${pg_packages} ${mercurial} ${git} ${mongodb}
fi

if [ $sunos = "1" ] ; then
    # packages for OpenSolaris/OmniOS
    pkg install pkg://omnios/developer/versioning/git mercurial ${autoconf} automake gcc48 zlib wget \
	${pg_packages} ${mercurial} ${git} ${mongodb}
    pkg install \
	developer/object-file \
	developer/linker \
	developer/library/lint \
	developer/build/gnu-make \
	system/header \
	system/library/math/header-math
fi

echo "------------------------ Downloading sources ----------------------------"
if [ ! -f tcl${version_tcl}-src.tar.gz ] ; then
    echo wget http://heanet.dl.sourceforge.net/sourceforge/tcl/tcl${version_tcl}-src.tar.gz
    wget http://heanet.dl.sourceforge.net/sourceforge/tcl/tcl${version_tcl}-src.tar.gz
fi
if [ ! -f tcllib-${version_tcllib}.tar.bz2 ] ; then
    wget http://heanet.dl.sourceforge.net/sourceforge/tcllib/tcllib-${version_tcllib}.tar.bz2
fi

if [ ! ${version_ns} = "HEAD" ] ; then
    if [ ! -f naviserver-${version_ns}.tar.gz ] ; then
	wget http://heanet.dl.sourceforge.net/sourceforge/naviserver/naviserver-${version_ns}.tar.gz
    fi
else
    if [ ! -d naviserver ] ; then
	hg clone https://bitbucket.org/naviserver/naviserver
    else
	cd naviserver
	hg pull
	hg update
	cd ..
    fi
    if [ ! -f naviserver/configure ] ; then
	cd naviserver
	bash autogen.sh --with-tcl=${ns_install_dir}/lib --prefix=${ns_install_dir}
	cd ..
    fi
fi

cd ${build_dir}
if [ ! ${version_modules} = "HEAD" ] ; then
    if [ ! -f naviserver-${version_modules}-modules.tar.gz ] ; then
	wget http://heanet.dl.sourceforge.net/sourceforge/naviserver/naviserver-${version_modules}-modules.tar.gz
    fi
else
    mkdir modules
    cd modules
    for d in nsdbbdb nsdbtds nsdbsqlite nsdbpg nsdbmysql \
	nsocaml nssmtpd nstk nsdns nsfortune \
	nssnmp nsicmp nsudp nsaccess nschartdir \
	nsexample nsgdchart nssavi nssys nszlib nsaspell \
	nsclamav nsexpat nsimap nssip nstftpd \
	nssyslogd nsldapd nsradiusd nsphp nsstats nsconf \
	nsdhcpd nsrtsp nsauthpam nsmemcache nsssl \
	nsvfs nsdbi nsdbipg nsdbilite nsdbimy
    do
	if [ ! -d $d ] ; then
	    hg clone http://bitbucket.org/naviserver/$d
	else
	    cd $d
	    hg pull
	    hg update
	    cd ..
	fi
    done
fi

cd ${build_dir}
if [ ! -f thread${version_thread}.tar.gz ] ; then
    wget http://heanet.dl.sourceforge.net/sourceforge/tcl/thread${version_thread}.tar.gz
fi

if [ ! ${version_xotcl} = "HEAD" ] ; then
    if [ ! -f nsf${version_xotcl}.tar.gz ] ; then
	wget http://heanet.dl.sourceforge.net/sourceforge/next-scripting/nsf${version_xotcl}.tar.gz
    fi
else
    if [ ! -d nsf ] ; then
	git clone git://alice.wu-wien.ac.at/nsf
    else
	cd nsf
	git pull
	cd ..
    fi
fi

if [ $with_mongo = "1" ] ; then
    if [ ! -d mongo-c-driver-legacy ] ; then
	git clone https://github.com/mongodb/mongo-c-driver-legacy
    else
	cd mongo-c-driver-legacy
	git pull
	cd ..
    fi
fi

if [ ! -f tDOM-${version_tdom}.tgz ] ; then
    wget --no-check-certificate https://github.com/downloads/tDOM/tdom/tDOM-${version_tdom}.tgz
fi

#exit
echo "------------------------ Installing TCL ---------------------------------"
set -o errexit

tar xfz tcl${version_tcl}-src.tar.gz
cd tcl${version_tcl}/unix
./configure --enable-threads --prefix=${ns_install_dir}
${make}
${make} install

# Make sure, we have a tclsh in ns/bin
if [ -f $ns_install_dir/bin/tclsh ] ; then
    rm $ns_install_dir/bin/tclsh
fi
source $ns_install_dir/lib/tclConfig.sh
ln -sf $ns_install_dir/bin/tclsh${TCL_VERSION} $ns_install_dir/bin/tclsh

cd ../..

echo "------------------------ Installing TCLLib ------------------------------"

tar xvfj tcllib-${version_tcllib}.tar.bz2
cd tcllib-${version_tcllib}
./configure --prefix=${ns_install_dir}
${make} install
cd ..

echo "------------------------ Installing Naviserver ---------------------------"

if [ ! ${version_ns} = "HEAD" ] ; then
    tar zxvf naviserver-${version_ns}.tar.gz
    cd naviserver-${version_ns}
else
    cd naviserver
fi
./configure --with-tcl=${ns_install_dir}/lib --prefix=${ns_install_dir}
${make}

if [ ${version_ns} = "HEAD" ] ; then
    ${make} "DTPLITE=${ns_install_dir}/bin/tclsh $ns_install_dir/bin/dtplite" build-doc
fi
${make} install
cd ..

echo "------------------------ Installing Modules/nsdbpg ----------------------"
if [ ! ${version_modules} = "HEAD" ] ; then
    tar zxvf naviserver-${version_modules}-modules.tar.gz
fi
cd modules/nsdbpg
${make} PGLIB=${pg_lib} PGINCLUDE=${pg_incl} NAVISERVER=${ns_install_dir}
${make} NAVISERVER=${ns_install_dir} install
cd ../..


echo "------------------------ Installing Thread ------------------------------"

tar xfz thread${version_thread}.tar.gz
cd thread${version_thread}/unix/
../configure --enable-threads --prefix=${ns_install_dir} --exec-prefix=${ns_install_dir} --with-naviserver=${ns_install_dir} --with-tcl=${ns_install_dir}/lib
make
${make} install
cd ../..

if [ $with_mongo = "1" ] ; then
    echo "------------------------ MongoDB-driver ----------------------------------"

    cd mongo-c-driver-legacy
    ${make}
    ${make} install
    if  [ $debian = "1" ] ; then
	ldconfig -v
    fi
    if  [ $redhat = "1" ] ; then
	ldconfig -v
    fi
    cd ..
fi

echo "------------------------ Installing XOTcl 2.0 ----------------------------"

if [ ! ${version_xotcl} = "HEAD" ] ; then
    tar xvfz nsf${version_xotcl}.tar.gz
    cd nsf${version_xotcl}
else
    cd nsf
fi
export CC=gcc

if [ $with_mongo = "1" ] ; then
    ./configure --enable-threads --enable-symbols --prefix=${ns_install_dir} --exec-prefix=${ns_install_dir} --with-tcl=${ns_install_dir}/lib --with-mongodb=${build_dir}/mongo-c-driver-legacy/src/,${build_dir}/mongo-c-driver-legacy
else
    ./configure --enable-threads --enable-symbols --prefix=${ns_install_dir} --exec-prefix=${ns_install_dir} --with-tcl=${ns_install_dir}/lib
fi

${make}
${make} install
cd ..

echo "------------------------ Installing tdom --------------------------------"

tar xfz tDOM-${version_tdom}.tgz
cd tDOM-${version_tdom}/unix
../configure --enable-threads --disable-tdomalloc --prefix=${ns_install_dir} --exec-prefix=${ns_install_dir} --with-tcl=${ns_install_dir}/lib
${make} install
cd ../..

# set up minimal permissions in ${ns_install_dir}
chgrp -R ${ns_group} ${ns_install_dir}
chmod -R g+w ${ns_install_dir}

echo "

Congratulations, you have installed NaviServer.

You can now run plain NaviServer by typing the following command:

  sudo ${ns_install_dir}/bin/nsd -f -u ${ns_user} -g ${ns_group} -t ${ns_install_dir}/conf/nsd-config.tcl

As a next step, you need to configure the server according to your needs,
or you might want to use the server with OpenACS. Consult as a reference
the alternate configuration files in ${ns_install_dir}/conf/

"
