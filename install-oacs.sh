#!/bin/bash

clean=0
build=0
while [ x"$1" != x ] ; do
    case $1 in
        clean) clean=1
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

##
## In case you configured install-ns.sh to use a different
## ns_install_dir, adjust it here to the same directory
##
ns_install_dir=/usr/local/ns
oacs_core_dir=openacs-4
oacs_core_dir=openacs-core
oacs_core_version=HEAD
oacs_core_version=oacs-5-8
oacs_packages_version=HEAD
oacs_packages_version=oacs-5-8

if [ "${oacs_core_version}" = "HEAD" ] ; then
    oacs_service=oacs-${oacs_core_version}
else
    oacs_service=${oacs_core_version}
fi

oacs_dir=/var/www/${oacs_service}
db_name=${oacs_service}
install_dotlrn=0

pg_user=postgres
pg_dir=/usr
#pg_dir=/usr/local/pgsql

source ${ns_install_dir}/lib/nsfConfig.sh
#
# inherited/derived variables
# add defaults if inherited didn't work
if [ -f "/etc/debian_version" ] ; then
	debian=1
fi
if [ "${build_dir}x" = "x" ] ; then
    build_dir=/usr/local/src
fi
if [ "${with_postgres}x" = "x" ] ; then
    with_postgres=1
fi
if [ "${make}x" = "x" ] ; then
    make="make"
fi
if [ "${type}x" = "x" ] ; then
    type="type -a"
fi
if [ "${ns_user}x" = "x" ] ; then
    ns_user=nsadmin
fi
if [ "${ns_group}x" = "x" ] ; then
    ns_group=nsadmin
fi
if [ "${version_ns}x" = "x" ] ; then
    version_ns=4.99.6
fi
if [ "${ns_src_dir}x" = "x" ] ; then
    ns_src_dir=/usr/local/src/naviserver-${version_ns}
fi

oacs_user=${ns_user}
oacs_group=${ns_group}

if [ ! "${version_ns}" = "HEAD" ] ; then
    ns_src_dir=${build_dir}/naviserver-${version_ns}
else
    ns_src_dir=${build_dir}/naviserver
fi
modules_src_dir=${build_dir}/modules

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo "
Installation Script for OpenACS

This script configures a (pre-installed) PostgreSQL installation for
OpenACS, installs OpenACS core, basic OpenACS packages, xowiki, xowf
and optionally dotlrn and generates a config file and startup files
(for Ubuntu and Fedora Core). The script assumes a pre-existing
NaviServer installation, installed e.g. via install-ns.sh

Tested on Ubuntu 12.04, 13.04 and Fedora Core 18
(c) 2013 Gustaf Neumann

LICENSE    This program comes with ABSOLUTELY NO WARRANTY;
           This is free software, and you are welcome to redistribute it under certain conditions;
           For details see http://www.gnu.org/licenses.

SETTINGS   OpenACS version              ${oacs_core_version}
           OpenACS packages             ${oacs_packages_version}
           OpenACS directory            ${oacs_dir}
           OpenACS service              ${oacs_service}
           OpenACS user                 ${oacs_user}
           OpenACS group                ${oacs_group}
           With PostgresSQL             ${with_postgres}
           PostgresSQL user             ${pg_user}
           PostgreSQL directory         ${pg_dir}
           Database name                ${db_name}
           Naviserver install directory ${ns_install_dir}
           Naviserver src directory     ${ns_src_dir}
           Naviserver modules directory ${modules_src_dir}
           Naviserver user              ${ns_user}
           Naviserver group             ${ns_group}
           Install DotLRN               ${install_dotlrn}
           Make command                 ${make}
           Type command                 ${type}
"

if [ "${build}" = "0" ] ; then
    echo "
WARNING    Check Settings AND Cleanup section before running this script!
           If you know what you're doing then call the call the script as
              $0 build
"
exit
fi

echo "------------------------ Cleanup -----------------------------------------"
# First we clean up

# The cleanup on ${oacs_dir} might be optional, since it can
# delete something else not from our installation.

#rm -r ${oacs_dir}

# just clean?
if [ $clean = "1" ] ; then
  exit
fi

echo "------------------------ Check System ----------------------------"
if  [ "${macosx}" = "1" ] ; then
    group_listcmd="dscl . list /Groups | grep ${oacs_group}"
    group_addcmd="dscl . create /Groups/${oacs_group}"
    oacs_user_addcmd="dscl . create /Users/${oacs_user};dseditgroup -o edit -a ${oacs_user} -t user ${oacs_group}"
    pg_user_addcmd="dscl . create /Users/${pg_user};dscl . create /Users/${pg_user} UserShell /bin/bash"
else
    group_listcmd="grep -o ${oacs_group} /etc/group"
    group_addcmd="groupadd ${oacs_group}"
    oacs_user_addcmd="useradd -g ${oacs_group} ${oacs_user}"
    pg_user_addcmd="useradd -s /bin/bash ${pg_user}"
    if  [ "${sunos}" = "1" ] ; then
       pkg install pkg:/omniti/database/postgresql-927/hstore
       pg_dir=/opt/pgsql927
    fi
fi

if [ "${redhat}" = "1" ] ; then
    if [ "${with_postgres}" = "1" ] ; then
	yum install postgresql-server
    fi
    running=$(ps ax|fgrep postgres:)
    if [ "${running}" = "" ] ; then
	echo "PostgreSQL is not running. You might consider to initialize PostgreSQL"
	echo "    service postgresql initdb"
	echo "and/or to start the database"
	echo "    service postgresql start"
	echo "and rerun this script"
	exit
    fi
elif  [ "${debian}" = "1" ] ; then
    if [ "${with_postgres}" = "1" ] ; then
	apt-get install postgresql postgresql-contrib
    fi
elif  [ "${sunos}" = "1" ] ; then
    if [ "${with_postgres}" = "1" ] ; then
	running=$(ps ax|fgrep "/postgres ")
	if [ "${running}" = "" ] ; then
            echo "Postgres is NOT running. Please start the PostgreSQL server first"
	fi
    fi
fi

echo "------------------------ Check Userids ----------------------------"

group=$(eval ${group_listcmd})
echo "${group_listcmd}" => ${group}
if [ "x${group}" = "x" ] ; then
    eval ${group_addcmd}
fi

id=$(id -u ${oacs_user})
if [ $? != "0" ] ; then
    if  [ "${debian}" = "1" ] ; then
	eval ${oacs_user_addcmd}
    else
	echo "User ${oacs_user} does not exist; you might add it with something like"
	echo "     ${oacs_user_addcmd}"
	exit
    fi
fi
id=$(id -u ${pg_user})
if [ $? != "0" ] ; then
    echo "User ${pg_user} does not exist; you should add it via installing postgres"
    echo "like e.g. under Ubuntu with "
    echo "     apt-get install postgresql postgresql-contrib"
    echo "alternatively you might create the use with e.g."
    echo "     ${pg_user_addcmd}"
    exit
fi

echo "------------------------ Setup Database ----------------------------"

#
# assume, the db is installed and already running,
# and users ${pg_user} and ${oacs_user} and group ${oacs_group} are created
#

cd /tmp
set -o errexit

echo "Checking if oacs_user ${oacs_user} exists in db."
dbuser_exists=$(su ${pg_user} -c "${pg_dir}/bin/psql template1 -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${oacs_user}'\"")
if [ "$dbuser_exists" = "1" ] ; then
    echo "db user ${oacs_user} exists. "
else
    echo "Creating oacs_user ${oacs_user}. "
    su ${pg_user} -c "${pg_dir}/bin/createuser -a -d ${oacs_user}"
fi

echo "Checking if db ${db_name} exists."
db_exists=$(su ${pg_user} -c "${pg_dir}/bin/psql template1 -tAc \"SELECT 1 FROM pg_database WHERE datname='${db_name}'\"")
if [ "$db_exists" != "1" ] ; then
    echo "Creating db ${db_name}."
    su ${pg_user} -c "${pg_dir}/bin/createdb -E UNICODE ${db_name}"
    #su ${pg_user} -c "${pg_dir}/bin/psql -d ${db_name} -f ${pg_dir}/share/postgresql/contrib/hstore.sql"
    su ${pg_user} -c "${pg_dir}/bin/psql -d ${db_name} -tAc \"create extension hstore\""
fi

echo "------------------------ Download OpenACS ----------------------------"
set +o errexit

#
# we use cvs for obtaining OpenACS
#
cvspath=$(${type} cvs)
if [ "${cvspath}" = "" ] ; then
    if [ "${debian}" = "1" ] ; then
	apt-get install cvs
    elif [ "${redhat}" = "1" ] ; then
	yum install cvs
    elif [ "${sunos}" = "1" ] ; then
	# why is there no CVS available via "pkg install" ?
	cd ${build_dir}
	if [ ! -f cvs-1.11.23.tar.gz ] ; then
	    wget http://ftp.gnu.org/non-gnu/cvs/source/stable/1.11.23/cvs-1.11.23.tar.gz
	fi
	tar zxvf cvs-1.11.23.tar.gz
	cd cvs-1.11.23
	./configure --prefix=/usr/gnu
	${make}
	${make} install
    else
	echo "cvs is not installed; you might install it with"
	echo "    apt-get install cvs"
	exit
    fi
fi

#
# we use git for obtaining xowf
#
gitpath=$(${type} git)
if [ "$gitpath" = "" ] ; then
    if [ "$debian" = "1" ] ; then
	apt-get install git
    elif [ "${redhat}" = "1" ] ; then
	yum install git
    else
	echo "git is not installed; you might install it with"
	echo "    apt-get install git"
	exit
    fi
fi


mkdir -p ${oacs_dir}
cd ${oacs_dir}

#cvs -q -d:pserver:anonymous@cvs.openacs.org:/cvsroot checkout -r ${oacs_core_version} acs-core
git clone https://github.com/xdcpm/openacs-core.git
#mv openacs-core ${oacs_core_dir}

ln -sf $(echo ${oacs_core_dir}/[a-z]*) .
cd ${oacs_dir}/packages
#cvs -d:pserver:anonymous@cvs.openacs.org:/cvsroot -q checkout -r ${oacs_packages_version} xotcl-all
#cvs -d:pserver:anonymous@cvs.openacs.org:/cvsroot -q checkout -r ${oacs_packages_version} acs-developer-support ajaxhelper
 git clone https://github.com/xdcpm/ajaxhelper.git
 git clone https://github.com/xdcpm/acs-datetime.git
 git clone https://github.com/xdcpm/acs-events.git
 git clone https://github.com/xdcpm/spreadsheet.git
 git clone https://github.com/xdcpm/q-forms.git
 git clone https://github.com/xdcpm/accounts-finance.git

if [ "$install_dotlrn" = "1" ] ; then
    cvs -d:pserver:anonymous@cvs.openacs.org:/cvsroot -q checkout -r ${oacs_packages_version} dotlrn-all
fi

# install xowf
if [ ! -d "./xowf" ] ; then
    git clone git://alice.wu.ac.at/xowf
fi
cd xowf
git pull
cd ..

# install nsstats
mkdir -p ${oacs_dir}/www/admin/
cp ${modules_src_dir}/nsstats/nsstats.tcl ${oacs_dir}/www/admin/



chown -R ${oacs_user}:${oacs_group} ${oacs_dir}
chmod -R g+w ${oacs_dir}

# install and adapt naviserver config file
echo "Writing ${ns_install_dir}/config-${oacs_service}.tcl"
cp ${ns_src_dir}/openacs-config.tcl ${ns_install_dir}/config-${oacs_service}.tcl
cat << EOF > /tmp/subst.tcl
 set fn ${ns_install_dir}/config-${oacs_service}.tcl
 set file [open \$fn]; set c [read \$file] ; close \$file
 regsub -all {"openacs"} \$c {"${oacs_service}"} c
 regsub -all {set\\s+db_user\\s+\\\$server} \$c {set db_user ${oacs_user}} c
 set file [open \$fn w]; puts -nonewline \$file \$c; close \$file
EOF
${ns_install_dir}/bin/tclsh8.5 /tmp/subst.tcl


if [ "${redhat}" = "1" ] ; then
echo "Writing /lib/systemd/system/${oacs_service}.service"
cat <<EOF > /lib/systemd/system/${oacs_service}.service
[Unit]
Description=OpenACS/Naviserver
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=forking
PIDFile=${oacs_dir}/log/nsd.pid
Environment=LANG=en_US.UTF-8
ExecStartPre=/bin/rm -f ${oacs_dir}/log/nsd.pid
ExecStart=${ns_install_dir}/bin/nsd -t ${ns_install_dir}/config-${oacs_service}.tcl -u ${oacs_user} -g ${oacs_group}
KillMode=process
PrivateTmp=true

[Install]
#WantedBy=multi-user.target
EOF
elif [ "${debian}" = "1" ] ; then
   # Create automatically a configured upstart script into /etc/init/ ...
echo "Writing /etc/init/${oacs_service}.conf"
cat <<EOF > /etc/init/${oacs_service}.conf
# /http://upstart.ubuntu.com/wiki/Stanzas

description "OpenACS/NaviServer"
start on stopped rc
stop on runlevel S

respawn
umask 002
env LANG=en_US.UTF-8

pre-start script
  until sudo -u ${pg_user} ${pg_dir}/bin/psql -l ; do sleep 1; done
end script

exec ${ns_install_dir}/bin/nsd -i -t ${ns_install_dir}/config-${oacs_service}.tcl -u ${oacs_user} -g ${oacs_group}
EOF
fi


echo "
Congratulations, you have installed OpenACS with NaviServer on your machine.
You might start the server manually with

    sudo ${ns_install_dir}/bin/nsd -t ${ns_install_dir}/config-${oacs_service}.tcl -u ${oacs_user} -g ${oacs_group}"
if [ "${redhat}" = "1" ] ; then
echo "
or you can manage your installation with systemd (RedHat, Fedora Core). In this case,
you might use the following commands

    systemctl status ${oacs_service}
    systemctl start ${oacs_service}
    systemctl stop ${oacs_service}
"
elif [ "${debian}" = "1" ] ; then
echo "
or you can manage your installation with upstart (Ubuntu/Debian). In this case,
you might use the following commands

    status ${oacs_service}
    start ${oacs_service}
    stop ${oacs_service}
"
fi

echo "
To use OpenACS, point your browser to http://localhost:8000/
The configuration file is ${ns_install_dir}/config-${oacs_service}.tcl
and might be tailored to your needs. The access.log and error.log of
this instance are in ${oacs_dir}/log

"
