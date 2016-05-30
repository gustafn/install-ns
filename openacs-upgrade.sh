
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
backup_dir=upgrade-backup-${oacs_service}
backup_sql=${oacs_service}-backup.sql
# exit on error
set -o errexit


#echo "stopping service"
#stop ${oacs_service}

echo "cd ${service_dir}"
cd ${service_dir}

echo "----- Backup openacs system"
# backup files
echo "cp -Rp ${oacs_service} ${backup_dir}"
cp -Rp ${oacs_service} ${backup_dir}

# backup db
echo "su - ${pg_user} -c ${pg_dir}/bin/pg_dump -U ${pg_user} -o -O ${db_name} -f ${pg_user_dir}/${backup_sql}"
# pg_dump -U postgres -o -O oacs-dev -f oacs-dev-20160528-stopped-nsd.sql
su - ${pg_user} -c "${pg_dir}/bin/pg_dump -U ${pg_user} -o -O ${db_name} -f ${pg_user_dir}/${backup_sql}"

#copy dump to backup dir
echo "cp ${pg_user_dir}/${backup_sql} ${service_dir}/${backup_dir}/."
cp ${pg_user_dir}/${backup_sql} ${service_dir}/${backup_dir}/.

echo "----- Prepping upgrade source files"

cd ${service_dir}
echo "pwd"
pwd
echo "ls -l"
ls -l
if [ -d ${service_dir}/${downloaded_dir} ] ; then
    echo "rm -R ${downloaded_dir}"
    rm -R ${service_dir}/${downloaded_dir}
fi
if [ ! -f ${service_dir}/${downloaded_file} ] ; then
    echo "wget ${download_url}"
    wget ${download_url}
fi
if [ ! -d ${service_dir}/${downloaded_dir} ] ; then
    echo "tar xvfz ${downloaded_file}"
    tar xvfz ${downloaded_file}
fi

echo "----- Replacing old code with new code"
# name of packages $(echo ${service_dir}/${downloaded_dir}/packages/[a-z]*)

echo "cd ${service_dir}/${oacs_service}/packages"
cd ${service_dir}/${oacs_service}/packages

echo "rm -R $(echo `cd ${service_dir}/${downloaded_dir}/packages;ls -1d [a-z]*`)"
rm -R $(echo `cd ${service_dir}/${downloaded_dir}/packages;ls -1d [a-z]*`)

echo "cd ${service_dir}/${downloaded_dir}/packages"
cd ${service_dir}/${downloaded_dir}/packages

echo "mv -v $(echo `ls -1d [a-z]*`) ${service_dir}/${oacs_service}/packages/. "
mv -fv $(echo [a-z]*) ${service_dir}/${oacs_service}/packages/. 

# tcl dir

echo "cd ${service_dir}/${oacs_service}"
cd ${service_dir}/${oacs_service}

echo "rm -R tcl"
rm -R tcl

echo "cd ${service_dir}/${downloaded_dir}"
cd ${service_dir}/${downloaded_dir}

echo "mv -v tcl ${service_dir}/${oacs_service}/."
mv -v tcl ${service_dir}/${oacs_service}/.

# www
echo "cd ${service_dir}/${oacs_service}"
cd ${service_dir}/${oacs_service}

echo "cp -Rp www www-$(echo `date -Idate`)"
cp -Rp www www-$(echo `date -Idate`)

echo "cd ${service_dir}/${downloaded_dir}"
cd ${service_dir}/${downloaded_dir}

echo "cp -Rp www ${service_dir}/${oacs_service}/www-new"
cp -Rp www ${service_dir}/${oacs_service}/www-new

# permissions

echo "chown -R ${ns_user}:${ns_group} *"
chown -R ${ns_user}:${ns_group} *


echo "
Automatic part of upgrade is done.
Next steps:

1. start ${oacs_service}

2. Browse to the Site-wide admin page:  http://your domain/acs-admin

3. Click 'Install Packages'

4. CLick 'Install or upgrade' from the local file system.

5. Select packages requiring 'upgrade'

6. Load all data model scripts. ie Select all and click 'Install Packages'.

7. Retstart service.

8. www files may have to be manually integrated.
   Files in ${service_dir}/${oacs_service}/www have been copied to ${service_dir}/${oacs_service}/www-$(echo www-`date -Idate`)
   New files are in ${service_dir}/${oacs_service}/www-new

Usually there are changes in *master.adp/.tcl templates. 
If site has manually changed templates, changes may need to be manually added again to prevent template rendering errors.
In any case, edits of the old templates should be manually re-edited into the new ones.
"

