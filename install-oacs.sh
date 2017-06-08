#!/bin/bash

clean=0
build=0
while [ x"$1" != x ] ; do
    case $1 in
        clean) clean=1
            shift
            rm /etc/init/
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

## You can override any of these settings by adding settings to custom-local-settings.sh
hostname=localhost
ip_address=0.0.0.0
httpport=8000
httpsport=8443
oacs_core_dir=openacs-core
oacs_tar_release_url=http://openacs.org/projects/openacs/download/download/${oacs_tar_release}.tar.gz?revision_id=4869825
# set oacs_core_version to either oacs-5-9 for example, or HEAD
oacs_core_version=oacs-5-9
oacs_packages_version=oacs-5-9
oacs_tar_release=openacs-5.9.0
ns_install_dir=/usr/local/ns

install_dotlrn=0

pg_user=postgres
#pg_dir=/usr
pg_dir=/usr/local


if [ "${oacs_core_version}" = "HEAD" ] ; then
    oacs_service=oacs-${oacs_core_version}
else
    oacs_service=${oacs_core_version}
fi


source ${ns_install_dir}/lib/nsConfig.sh

if [ "$ns_user" = "" ] ; then
    echo "could not determine ns_user from  ${ns_install_dir}/lib/nsConfig.sh"
    exit
fi
echo "Loaded definitions from ${ns_install_dir}/lib/nsConfig.sh"

oacs_dir=/var/www/${oacs_service}
config_tcl_dir=${oacs_dir}
db_name=${oacs_service}
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


SCRIPT_PATH=$(dirname "$0")
custom_settings="${SCRIPT_PATH}/custom-local-settings.sh"
echo "Checking for existence of '${custom_settings}'"
if [[ -e "${custom_settings}" ]]; then
    source ${custom_settings}
    echo "Loaded local definitions from ${custom_settings}"
    custom_p=1
else
    custom_p=0
fi


echo "
Installation Script for OpenACS

This script configures a (pre-installed) PostgreSQL installation for
OpenACS, installs OpenACS core, basic OpenACS packages, xowiki, xowf
and optionally dotlrn and generates a config file and startup files
(for Ubuntu and Fedora Core). The script assumes a pre-existing
NaviServer installation, installed e.g. via install-ns.sh

Tested on Ubuntu 12.04, 13.04, 14.04 Fedora Core 18, and CentOS 7, FreeBSD 10
(c) 2013 Gustaf Neumann

LICENSE    This program comes with ABSOLUTELY NO WARRANTY;
           This is free software, and you are welcome to redistribute it under certain conditions;
           For details see http://www.gnu.org/licenses.

SETTINGS   values from custom source    ${custom_p}
           hostname                     ${hostname}
           ip_address                   ${ip_address}
           OpenACS version              ${oacs_core_version}
           OpenACS packages             ${oacs_packages_version}
           OpenACS tar release URL      ${oacs_tar_release_url}
           OpenACS directory            ${oacs_dir}
           OpenACS service              ${oacs_service}
           OpenACS config dir           ${config_tcl_dir}
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
echo "${group_listcmd} => ${group}"
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
if [ "$oacs_tar_release_url" = "" ] ; then
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

if [ "${cvs_p}" = "1" ] ; then
    cvs -q -d:pserver:anonymous@cvs.openacs.org:/cvsroot checkout -r ${oacs_core_version} acs-core
else
    if [ "${xdcpm}" = "xdcpm" ] ; then
        git clone https://github.com/${xdcpm}/openacs-core.git
        mv openacs-core ${oacs_core_dir}
    else
        git clone https://github.com/openacs/openacs-core.git
        mv openacs-core ${oacs_core_dir}
    fi
fi
ln -sf $(echo ${oacs_core_dir}/[a-z]*) .
cd packages
#cvs -d:pserver:anonymous@cvs.openacs.org:/cvsroot -q checkout -r ${oacs_packages_version} xotcl-all
#cvs -d:pserver:anonymous@cvs.openacs.org:/cvsroot -q checkout -r ${oacs_packages_version} acs-developer-support ajaxhelper
 git clone https://github.com/${xdcpm}/ajaxhelper.git
 git clone https://github.com/${xdcpm}/acs-datetime.git
 git clone https://github.com/${xdcpm}/acs-events.git
 git clone https://github.com/${xdcpm}/spreadsheet.git
 git clone https://github.com/${xdcpm}/q-forms.git
 git clone https://github.com/${xdcpm}/accounts-finance.git
if [ "$dev_p" = "1" ] ; then
  git clone http:://github.com/tekbasse/hosting-farm.git
  git clone https://github.com/tekbasse/accounts-receivables.git
  git clone https://github.com/tekbasse/accounts-ledger.git
  git clone https://github.com/tekbasse/q-wiki.git
  git clone https://github.com/tekbasse/ref-us-states.git
  git clone https://github.com/tekbasse/ref-us-counties.git
  git clone https://github.com/tekbasse/customer-service.git
fi

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

# install and adapt NaviServer config file
echo "Writing ${ns_install_dir}/config-${oacs_service}.tcl"
cp ${ns_src_dir}/openacs-config.tcl ${config_tcl_dir}/config-${oacs_service}.tcl
cat << EOF > /tmp/subst.tcl
 set fn ${ns_install_dir}/config-${oacs_service}.tcl
 set file [open \$fn]; set c [read \$file] ; close \$file
 regsub -- {localhost} \$c {"${hostname}"} c
 regsub -- {0.0.0.0  ;#} \$c {${ip_address}  ;#} c
 regsub -- {set db_name        } \$c {set db_name ${db_name}  ;# was}
 regsub -all -- {"openacs"} \$c {"${oacs_service}"} c
 regsub -all -- ${ns_install_dir} \$c {${ns_install_dir}} c
 regsub -all -- {set\\s+db_user\\s+\\\$server} \$c {set db_user ${oacs_user}} c
 set file [open \$fn w]; puts -nonewline \$file \$c; close \$file
EOF
${ns_install_dir}/bin/tclsh /tmp/subst.tcl


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

# standard startup (non-privileged port, like 8000)
ExecStart=${ns_install_dir}/bin/nsd -u ${oacs_user} -g ${oacs_group} -t ${config_tcl_dir}/config-${oacs_service}.tcl

# startup for privileged port, like 80
# ExecStart=${ns_install_dir}/bin/nsd -u ${oacs_user} -g ${oacs_group} -t ${config_tcl_dir}/config-${oacs_service}.tcl -b YOUR.IP.ADRESS:80

# Could be prone to fire if doing this on a private, unmonitored development server:
#Restart=on-abnormal

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

exec ${ns_install_dir}/bin/nsd -i -t ${config_tcl_dir}/config-${oacs_service}.tcl -u ${oacs_user} -g ${oacs_group}

# startup for privileged port, like 80
#exec /usr/local/oo2/bin/nsd -i -t /usr/local/oo2/config-wi1.tcl -u ${oacs_user} -g ${oacs_group} -b YOUR.IP.ADRESS:80
EOF
elif [ "${freebsd}" = "1" ] ; then
    cat <<EOF > /usr/local/etc/rc.d/${hostname}-${oacs_service}.sh
#!/bin/sh

# Startup script for NaviServer on FreeBSD
#
# Begin EDIT section
#
# Use the values provided from the beginning of the install script:
oacs_service=${oacs_service}
hostname=${hostname}
IP=${ip_address}
oacs_user=${oacs_user}
oacs_group=${oacs_group}
pg_user=${pg_user}
pg_dir=${pg_dir}
#
# End EDIT section
#
PREFIX=${ns_install_dir}
CONFIG=${config_tcl_dir}

EOF
    cat ${current_dir}/freebsd-server-rc.sh >> /usr/local/etc/rc.d/${hostname}-${oacs_service}.sh
    chmod 750 /usr/local/etc/rc.d/${hostname}-${oacs_service}.sh
fi


echo "
Congratulations, you have installed OpenACS with NaviServer on your machine.
You might start the server manually with

    sudo ${ns_install_dir}/bin/nsd -t ${config_tcl_dir}/config-${oacs_service}.tcl -u ${oacs_user} -g ${oacs_group}"
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
elif [ "${freebsd}" = "1" ] ; then
echo "
or you can manage your installation with an rc.d script. In this case,
/usr/local/etc/rc.d/${hostname}-${oacs_service}.sh start
/usr/local/etc/rc.d/${hostname}-${oacs_service}.sh stop
/usr/local/etc/rc.d/${hostname}-${oacs_service}.sh faststart
"
fi

echo "
To use OpenACS, point your browser to http://localhost:8000/
The configuration file is ${ns_install_dir}/config-${oacs_service}.tcl
and might be tailored to your needs. The access.log and error.log of
this instance are in ${oacs_dir}/log

"
