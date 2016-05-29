
# current settings
oacs_service=oacs-5-8
ns_user=nsadmin
ns_group=nsadmin



#name of new openacs service
oacs_service_new=5-9

db_name=${oacs_service}

pg_dir=/usr/
pg_user=postgres
pg_user_dir=/var/lib/postgresql
download_url="http://openacs.org/projects/openacs/download/download/openacs-5.9.0.tar.gz?revision_id=4869825"
downloaded_file=openacs-5.9.0-release.tar.gz
downloaded_dir=openacs-5.9.0

service_dir=/var/www

# exit on error
set -o errexit


echo "stopping service"
stop ${oacs_service}

echo "cd ${service_dir}"
cd ${service_dir}

echo "----- Backup openacs system"
# backup files
echo "cp -R ${oacs_service} upgrade-backkup-${oacs_service}"
cp -R ${oacs_service} upgrade-backkup-${oacs_service}

# backup db
echo "su - ${pg_user} -c ${pg_dir}/bin/pg_dump -U ${pg_user} -o -O ${db_name} -f ${pg_user-dir}/${oacs-dev}-backup-.sql"
# pg_dump -U postgres -o -O oacs-dev -f oacs-dev-20160528-stopped-nsd.sql
su - ${pg_user} -c "${pg_dir}/bin/pg_dump -U ${pg_user} -o -O ${db_name} -f ${pg_user-dir}/${oacs-dev}-backup-.sql"

#copy dump to backup dir
echo "cp ${pg_user-dir}/${oacs-dev}-backup-.sql ${service_dir}/upgrade-backup-${oacs_service}/."
cp ${pg_user-dir}/${oacs-dev}-backup-.sql ${service_dir}/upgrade-backup-${oacs_service}/.

echo "----- Prepping upgrade source files"

if [ -f ${downloaded_dir} ] ; then
    echo "rm -R ${downloaded_dir}"
    rm -R ${service_dir}/${downloaded_dir}
fi
if [ ! -f ${downloaded_file} ] ; then
    echo "wget ${download_url}"
    wget ${download_url}
fi
if [ -f ${downloaded_dir} ] ; then
    echo "tar xvfz ${downloaded_file}"
    tar xvfz ${downloaded_file}
fi

echo "----- Replacing old code with new code"
# name of packages $(echo ${service_dir}/${downloaded_dir}/packages[a-z]*)
echo "cd ${service_dir}/${oacs_service}/package/"
cd ${service_dir}/${oacs_service}/packages

echo "rm -R $(echo ${service_dir}/${downloaded_dir}/packages[a-z]*)"
rm -R $(echo ${service_dir}/${downloaded_dir}/packages[a-z]*)

echo "cd ${service_dir}/${downloaded_dir}/packages"
cd ${service_dir}/${downloaded_dir}/packages

echo "mv $(echo ${service_dir}/${downloaded_dir}/packages[a-z]*) ${service_dir}/${oacs_service}/packages/."
mv $(echo ${service_dir}/${downloaded_dir}/packages[a-z]*) ${service_dir}/${oacs_service}/packages/.

# tcl 
echo "cd ${service_dir}/${oacs_service}"
cd ${service_dir}/${oacs_service}

echo "rm -R tcl"
rm -R tcl

echo "cd ${service_dir}/${downloaded_dir}"
cd ${service_dir}/${downloaded_dir}

echo "mv tcl ${service_dir}/${oacs_service}/."
mv tcl ${service_dir}/${oacs_service}/.

# www
echo "cd ${service_dir}/${oacs_service}"
cd ${service_dir}/${oacs_service}

echo "cp -R www www-$(echo date -Idate)"
cp -R www www-$(echo date -Idate)

echo "cd ${service_dir}/${downloaded_dir}"
cd ${service_dir}/${downloaded_dir}

echo "cp -R www ${service_dir}/${oacs_service}/www-new"
cp -R www ${service_dir}/${oacs_service}/www-new

# permissions

echo "chown -R ${ns_user}:${ns_group} *"
chown -R ${ns_user}:${ns_group} *


echo "
Automatic part of upgrade is done.
Next steps:

1. start ${oacs_service}

2. Browse to the Site-wide admin page:  http://your domain/acs-admin

3. Click 'Install Packages'

4. Retstart service.

5. www files have to be manually integrated.

Files in ${oacs_service}/www have been copied to ${oacs_service}/www-$(echo date -Idate)

New files are in www-new

Usually there are changes in base templates. These changes can cause errors.
"

