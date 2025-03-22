# install-ns

**Install Scripts for NaviServer**

This repository provides installation scripts for NaviServer—and
optionally OpenACS. For more details, see the links below:

- [Source Code](https://github.com/naviserver-project/naviserver/)
- [Releases](https://sourceforge.net/projects/naviserver/)
- [OpenACS](https://openacs.org/)

## Overview

The `install-ns.sh` script allows you to install NaviServer with
customizable settings. When run without additional parameters, it
displays the default configuration values.

To view the default settings, run:

```bash
sudo bash install-ns.sh
```

This command outputs a list of settings, similar to the example below:


     SETTINGS   build_dir              (Build directory)                 /usr/local/src
                ns_install_dir         (Installation directory)          /usr/local/ns
                version_ns             (Version of NaviServer)           4.99.31
                git_branch_ns          (Branch for git checkout of ns)   main
                version_modules        (Version of NaviServer Modules)   4.99.31
                version_tcllib         (Version of Tcllib)               1.20
                version_thread         (Version Tcl thread library)
                version_xotcl          (Version of NSF/NX/XOTcl)         2.4.0
                version_tcl            (Version of Tcl)                  8.6.16
                version_tdom           (Version of tDOM)                 0.9.5
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


The first column lists variable names that you can use to override the
defaults. You can edit the script directly or provide these variables
as environment variables when invoking the script.


## Customizing the Installation

For example, to compile NaviServer with site-specific settings, run:

```bash
sudo with_debug_flags=1 version_tcl=8.6.13 ns_modules="nsdbpg nssmtpd" \
     bash install-ns.sh
```

This command changes the defaults by:
- Enabling debugging (compilation flag `-g`).
- Using a specific version of Tcl (`8.6.13`).
- Including additional NaviServer modules (e.g., `nsdbpg` and `nssmtpd`).

You can specify any released version of Tcl 8.6.* or 9.* (as denoted
by the dots), or use tags names from the Tcl Fossil repository. For example,
to use the latest version from the Tcl 8.5 branch on Fossil, set
`version_tcl` to `core-8-5-branch` (note that this tag does not include
dots).


For the NaviServer components (controlled by `version_ns` and
`version_modules`), you can use the value `GIT` to automatically fetch
the latest version from GitHub. If these variables contain a dot, the
installer will use the tarball releases from SourceForge instead.


To reuse an existing PostgreSQL database installation while still
building the PostgreSQL module, run:

```bash
sudo with_postgres=0 bash install-ns.sh
```

If you prefer to build NaviServer without PostgreSQL support at all, run:
```bash
sudo with_postgres=0 with_postgres_driver=0 bash install-ns.sh
```

To compile and build NaviServer, append the word `build` at the end of the command:

```bash
sudo bash install-ns.sh build
```

## Additional Information

For further details, visit:  
[http://openacs.org/xowiki/naviserver-openacs](http://openacs.org/xowiki/naviserver-openacs)
```
