
# aolserver4 recommends descriptors limit (FD_SETSIZE) to be set to 1024, 
# which is standard for most OS distributions
# For freebsd systems using aolserver4, uncomment following line:
# ulimit -n 1024

# Usually, you will not need to edit anything below this comment.

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib:/usr/local/ns/lib
export PATH=$PATH:/usr/local/bin/psql

case "$1" in
    faststart)
        ${PREFIX}/bin/nsd -t ${CONFIG}/config-${oacs_service}.tcl -u ${oacs_user} -g ${oacs_group} -b ${IP}:8000,${IP}:8443
        ;;

    start)
        # give time for other services to start first. Try anyway after 13 seconds.
        # sleep 13
        #pre-start script
        i=1
        until sudo -u ${pg_user} ${pg_dir}/bin/psql -l || [ "${i}" -ge 14 ] ; do sleep 1; i=`expr $i + 1`;  done
        #end script

        ${PREFIX}/bin/nsd -t ${CONFIG}/config-${oacs_service}.tcl -u ${oacs_user} -g ${oacs_group} -b ${IP}:8000,${IP}:8443
        ;;

    stop)
        /bin/kill -9 `cat /var/www/${oacs_service}/log/nsd.pid`
        ;;

    *)
        echo "usage: ${oacs_service}.sh {faststart|start|stop}" 1>&2
        exit 64
        ;;
esac
