#!/bin/bash
#!/usr/local/bin/bash

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

##
## In case you configured install-ns.sh to use a different
## ns_install_dir, adjust it here to the same directory
##
ns_install_dir=/usr/local/ns


#
# The following names are CVS tag mostly relevant for checkouts from
# CVS, but as well for naming the service.
#
#   HEAD:
#     the newest version, often not intended to be runable
#
#   oacs-x-y:
#      the newest version of the oacs-x-y branch
#      (not necessarily "released")
#
#   oacs-x-y-compat:
#      the newest "released" version of the oacs-x-y branch
#
#   openacs-x-y-z-final:
#      the version of the packages at the time OpenACS x.y.z was
#      released (similar to a tar file produced at the time of
#      a release of the main OpenACS packages).
#
# For tar releases, one should

oacs_version=5-9
#oacs_version=HEAD

#oacs_core_tag=HEAD
#oacs_core_tag=oacs-5-9
oacs_core_tag=openacs-5-9-compat
#oacs_core_tag=openacs-5-9-0-final

#oacs_packages_tag=HEAD
#oacs_packages_tag=oacs-5-9
oacs_packages_tag=openacs-5-9-compat
#oacs_packages_tag=openacs-5-9-0-final

#
# One can obtain the OpenACS sources either via tar file or via
# cvs. When oacs_tar_release is non-empty, it is used and the CVS tags
# are ignored.
#
oacs_tar_release=openacs-5.9.0
oacs_tar_release_url=http://openacs.org/projects/openacs/download/download/${oacs_tar_release}.tar.gz?revision_id=4869825
#oacs_tar_release_url=



pg_user=postgres
pg_dir=/usr

if [ "${oacs_version}" = "HEAD" ] ; then
    oacs_service=oacs-${oacs_version}
else
    oacs_service=${oacs_version}
fi


source ${ns_install_dir}/lib/nsConfig.sh
if [ "$ns_user" = "" ] ; then
    echo "could not determine ns_user from  ${ns_install_dir}/lib/nsConfig.sh"
    exit
fi
echo "Loaded definitions from ${ns_install_dir}/lib/nsConfig.sh"


oacs_dir=/var/www/${oacs_service}
db_name=${oacs_service}
install_dotlrn=0

#
# inherited/derived variables
#
#build_dir=/usr/local/src
#with_postgres=1
#ns_src_dir=/usr/local/src/naviserver-4.99.6

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


# Settings can be overridden by adding settings to custom-local-settings.sh
hostname=localhost
ip_address=127.0.0.1
httpport=8000
httpsport=8443
# Depending on if OpenACS code originates from cvs or github
oacs_core_dir=openacs-core
config_tcl_dir=${oacs_dir}


current_dir="$(realpath .)"
custom_settings="${current_dir}/custom-local-settings.sh"
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
OpenACS, installs OpenACS core, basic OpenACS packages (and xowiki, 
xowf and optionally dotlrn on CVS based installs; tar-based installs
can install these packages via 'install from repository'). The script 
generates a config file and startup files (for Ubuntu and Fedora Core). 
The script  assumes a pre-existing NaviServer installation, 
installed e.g. via install-ns.sh

To override settings in this script, create a file 
called 'custom-local-settings.sh' in this directory, 
and set variables using standard bash syntax like this:
  example_dir=/var/mtp

Tested on Ubuntu 12.04, 13.04, 14.04 Fedora Core 18, and CentOS 7, FreeBSD 10
(c) 2013 Gustaf Neumann

LICENSE    This program comes with ABSOLUTELY NO WARRANTY;
           This is free software, and you are welcome to redistribute it under certain conditions;
           For details see http://www.gnu.org/licenses.

SETTINGS   OpenACS version              ${oacs_core_tag}
           OpenACS packages             ${oacs_packages_tag}
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
           values from custom source    ${custom_p}
           hostname                     ${hostname}
           ip_address                   ${ip_address}
           httpport                     ${httpport}
           httpsport                    ${httpsport}
"

if [ "${build}" = "0" ] ; then
    echo "
WARNING    Check Settings AND Cleanup section before running this script!
           If you know what you're doing then call the call the script as
              bash $0 build
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
    pg_dir=/opt/local
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
    if [ -x "/usr/bin/dnf" ] ; then
	pkgmanager=/usr/bin/dnf
    else
	pkgmanager=yum	
    fi

    if [ "${with_postgres}" = "1" ] ; then
	${pkgmanager} install postgresql-server
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
# Here we assume, the postgres is installed and already running on port 5432,
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
	    ${pkgmanager} install cvs
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

mkdir -p ${oacs_dir}
cd ${oacs_dir}

if [ "$oacs_tar_release_url" = "" ] ; then

    cvs -q -d:pserver:anonymous@cvs.openacs.org:/cvsroot checkout -r ${oacs_core_tag} acs-core
    ln -sf $(echo openacs-4/[a-z]*) .
    cd ${oacs_dir}/packages
    cvs -d:pserver:anonymous@cvs.openacs.org:/cvsroot -q checkout -r ${oacs_packages_tag} xotcl-all
    cvs -d:pserver:anonymous@cvs.openacs.org:/cvsroot -q checkout -r ${oacs_packages_tag} xowf
    cvs -d:pserver:anonymous@cvs.openacs.org:/cvsroot -q checkout -r ${oacs_packages_tag} acs-developer-support ajaxhelper

    if [ $install_dotlrn = "1" ] ; then
	cvs -d:pserver:anonymous@cvs.openacs.org:/cvsroot -q checkout -r ${oacs_packages_tag} dotlrn-all
    fi
elif [ "${xdcpm}" = "xdcpm" ] ; then
    git clone https://github.com/${xdcpm}/openacs-core.git
    mv openacs-core ${oacs_core_dir}
    ln -sf $(echo ${oacs_core_dir}/[a-z]*) .
    cd ${oacs_dir}/packages
    
    if [ "$dev_p" = "1" ] ; then
        git clone http:://github.com/tekbasse/hosting-farm.git
        git clone https://github.com/tekbasse/accounts-receivables.git
        git clone https://github.com/tekbasse/accounts-ledger.git
        git clone https://github.com/tekbasse/q-wiki.git
        git clone https://github.com/tekbasse/ref-us-states.git
        git clone https://github.com/tekbasse/ref-us-counties.git
        git clone https://github.com/tekbasse/customer-service.git
        git clone https://github.com/tekbasse/ajaxhelper.git
        git clone https://github.com/tekbasse/acs-datetime.git
        git clone https://github.com/tekbasse/acs-events.git
        git clone https://github.com/tekbasse/spreadsheet.git
        git clone https://github.com/tekbasse/q-forms.git
        git clone https://github.com/tekbasse/accounts-finance.git
    else
        git clone https://github.com/${xdcpm}/ajaxhelper.git
        git clone https://github.com/${xdcpm}/acs-datetime.git
        git clone https://github.com/${xdcpm}/acs-events.git
        git clone https://github.com/${xdcpm}/spreadsheet.git
        git clone https://github.com/${xdcpm}/q-forms.git
        git clone https://github.com/${xdcpm}/accounts-finance.git
    fi
    
else
    wget $oacs_tar_release_url -O ${oacs_tar_release}.tar.gz
    tar zxvf ${oacs_tar_release}.tar.gz
    ln -sf ${oacs_tar_release}/* .
fi

# install nsstats
mkdir -p ${oacs_dir}/www/admin/
cp ${modules_src_dir}/nsstats/nsstats.tcl ${oacs_dir}/www/admin/



chown -R ${oacs_user}:${oacs_group} ${oacs_dir}
chmod -R g+w ${oacs_dir}

# install and adapt NaviServer config file
echo "Writing ${ns_install_dir}/config-${oacs_service}.tcl"
cp ${ns_src_dir}/openacs-config.tcl ${config_tcl_dir}/config-${oacs_service}.tcl
cat << EOF > /tmp/subst.tcl
 set fn1 ${ns_src_dir}/openacs-config.tcl
 set fn2 ${config_tcl_dir}/config-${oacs_service}.tcl
 set file [open \$fn1]; set c [read \$file] ; close \$file
 regsub -- {localhost} \$c {"${hostname}"} c
 regsub -- {127.0.0.1} \$c {${ip_address}} c
 regsub -- {8000} \$c {"${httpport}"} c
 regsub -- {8443} \$c {"${httpsport}"} c
 regsub -all -- {"openacs"} \$c {"${oacs_service}"} c
 regsub -all -- {/usr/local/ns} \$c {${ns_install_dir}} c
 regsub -all -- {set\\s+db_name\\s+\\\$server} \$c {set db_name ${db_name}} c
 regsub -all -- {set\\s+db_user\\s+\\\$server} \$c {set db_user ${oacs_user}} c
 set file [open \$fn2 w]; puts -nonewline \$file \$c; close \$file
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
Environment="LANG=en_US.UTF-8"
# In case, a site is using Google Perfortools malloc with the system-malloc patch for Tcl:
# Environment="LD_PRELOAD=/usr/lib64/libtcmalloc.so"
ExecStartPre=/bin/rm -f ${oacs_dir}/log/nsd.pid

# standard startup (non-privileged port, like 8000)
ExecStart=${ns_install_dir}/bin/nsd -u ${oacs_user} -g ${oacs_group} -t ${config_tcl_dir}/config-${oacs_service}.tcl

# startup for privileged port, like 80
# ExecStart=${ns_install_dir}/bin/nsd -u ${oacs_user} -g ${oacs_group} -t ${config_tcl_dir}/config-${oacs_service}.tcl -b YOUR.IP.ADDRESS:80

# Use "Restart=always" to make the instance start up again after it has stopped via ns_shutdown (e.g. /acs-admin/server-restart).
Restart=on-abnormal
KillMode=process

[Install]
# Uncomment this if the service should start automatically after system reboots.
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

script

  # In case, a site is using Google Perfortools malloc with the system-malloc patch for Tcl:
  # export LD_PRELOAD="/usr/lib/libtcmalloc.so"

  # standard startup (non-privileged port, like 8000)
  exec ${ns_install_dir}/bin/nsd -i -t ${config_tcl_dir}/config-${oacs_service}.tcl -u ${oacs_user} -g ${oacs_group}

  # startup for privileged port, like 80
  #exec /usr/local/oo2/bin/nsd -i -t /usr/local/oo2/config-wi1.tcl -u ${oacs_user} -g ${oacs_group} -b YOUR.IP.ADDRESS:80

end script
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
After starting the server, you can use OpenACS by loading
http://${hostname}:${httpport}/ from a browser. The NaviServer 
configuration file  is ${config_tcl_dir}/config-${oacs_service}.tcl 
and might be  tailored to your needs. The access.log and error.log 
of this instance are in ${oacs_dir}/log

"
