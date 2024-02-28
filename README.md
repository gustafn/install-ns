install-ns
==========

Install scripts for NaviServer
([source code](https://github.com/orgs/naviserver-project/naviserver-project/naviserver),
[releases](https://sourceforge.net/projects/naviserver/))
and optionally [OpenACS](https://openacs.org/).

To see the default settings, use the following command

     sudo bash install-ns.sh

This command returns a listing like e.g., the following:

     SETTINGS   build_dir              (Build directory)                 /usr/local/src
                ns_install_dir         (Installation directory)          /usr/local/ns
                version_ns             (Version of NaviServer)           4.99.24
                git_branch_ns          (Branch for git checkout of ns)   main
                version_modules        (Version of NaviServer Modules)   4.99.24
                version_tcllib         (Version of Tcllib)               1.20
                version_thread         (Version Tcl thread library)
                version_xotcl          (Version of NSF/NX/XOTcl)         2.4.0
                version_tcl            (Version of Tcl)                  8.6.13
                version_tdom           (Version of tDOM)                 0.9.1
                ns_user                (NaviServer user)                 nsadmin
                ns_group               (NaviServer group)                nsadmin
                                       (Make command)                    make
                                       (Type command)                    type -an
                ns_modules             (NaviServer Modules)              nsdbpg
                with_mongo             (Add MongoDB client and server)   0
                with_postgres          (Install PostgreSQL DB server)    1
                with_postgres_driver   (Add PostgreSQL driver support)   1
                with_system_malloc     (Tcl compiled with system malloc) 0
                with_debug_flags       (Tcl and nsd compiled with debug) 0
                with_ns_doc            (NaviServer documentation)        1

                pg_user                (PostgreSQL user)                 postgres
                                       (PostgreSQL include)              /usr/include/postgresql
                                       (PostgreSQL lib)                  /usr/lib
                                       (PostgreSQL Packages)             postgresql libpq-dev

This listing shows in the first column a name that can be used to
adapt the defaults to the needs of the current instance. One can edit
the script, or provide these variables as shell variables for the script.

For example, one can compile with some site-specific settings

    sudo with_debug_flags=1 version_tcl=8.6.10 ns_modules="nsdbpg nssmtpd" bash install-ns.sh

This command will change the default setting by
  * compile with debiggung enabled (compilation flag -g)
  * use a special version of Tcl (here 6.8.10)
  * with some extra NaviServer modules

If you want to reuse an existing PostgresSQL database installation,
use e.g.

    sudo with_postgres=0 bash install-ns.sh

Finally, to compile and build NaviServer, add the word "build" add the end of
the  command:

    sudo ... bash install-ns.sh build





For details, see: http://openacs.org/xowiki/naviserver-openacs
