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
                version_ns             (Version of NaviServer)           5.0.4
                git_branch_ns          (Branch for git checkout of ns)   main
                version_modules        (Version of NaviServer Modules)   5.0.4
                version_tcllib         (Version of Tcllib)               1.20
                version_thread         (Version Tcl thread library)
                version_xotcl          (Version of NSF/NX/XOTcl)         2.4.0
                version_tcl            (Version of Tcl)                  8.6.18
                version_tdom           (Version of tDOM)                 0.9.6
                version_openssl        (Version of OpenSSL)              SYSTEM
                version_nghttp3        (Version of nghttp3)
                ns_user                (NaviServer user)                 nsadmin
                ns_group               (NaviServer group)                nsadmin
                                       (Make command)                    make
                                       (Type command)                    type -p
                ns_modules             (NaviServer Modules)              nsdbpg
                with_mongo             (Add MongoDB client and server)   0
                with_postgres          (Install PostgreSQL DB server)    1
                with_postgres_driver   (Add PostgreSQL driver support)   1
                with_ns_deprecated     (NaviServer with deprecated cmds) 1
                with_system_malloc     (Tcl compiled with system malloc) 0
                with_debug_flags       (Tcl and nsd compiled with debug) 0
                with_ns_doc            (NaviServer documentation)        1

                pg_user                (PostgreSQL user)                 postgres
                                       (PostgreSQL include)              /opt/local/include/postgresql17/
                                       (PostgreSQL lib)                  /opt/local/lib/postgresql17/
                                       (PostgreSQL Packages)             postgresql17 postgresql17-server


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

To build NaviServer with HTTP/3 support, specify OpenSSL 4.0.2 or newer:

```bash
sudo version_openssl=4.0.2 bash install-ns.sh build
```

For these OpenSSL versions, the installer automatically builds the required
nghttp3 library before configuring and compiling NaviServer.

## Additional Information

For further details, visit:  
[http://openacs.org/xowiki/naviserver-openacs](http://openacs.org/xowiki/naviserver-openacs)
```

## Optional nssmtpd SPF support

Selecting `nssmtpd` automatically attempts to install the external libspf2 SPF
utility (`with_spfquery=1`, the default). Package mappings are:

| Platform | Package | Executable |
| --- | --- | --- |
| Debian/Ubuntu | `spfquery` | `/usr/bin/spfquery.libspf2` |
| Alpine | `libspf2-tools` | `/usr/bin/spfquery` |
| Fedora / RHEL-compatible | `libspf2-progs` | `/usr/bin/spfquery.libspf2` |
| openSUSE | `libspf2-tools` | `/usr/bin/spf_query` |

RHEL-compatible systems need an appropriate repository such as EPEL already
configured; the installer does not add repositories. On other platforms, or to
use a custom installation, set `SPFQUERY=/absolute/path/to/libspf2-spfquery`.
This skips package installation and uses the supplied executable. Perl/Python
SPF utilities with similar names are not compatible.

After installing NaviServer, the installer creates
`$ns_install_dir/bin/spfquery` as a symlink to the executable. Existing files
and links are preserved; rerunning with the same link is harmless. Missing
packages or executables produce warnings but do not prevent installation.
Use `with_spfquery=0` to skip this feature; this does not remove an existing
utility or link. No external timeout utility is needed.

The link provides a stable path for opt-in startup configuration:

```tcl
ns_section "ns/server/$server/module/nssmtpd" {
    set spfquery [file join [ns_info home] bin spfquery]
    if {[file executable $spfquery]} {
        ns_param spfproc [list smtpd::spfquery -command $spfquery]
    }
}
```

Load the `nsproxy` module and configure `greylistspfexceptions` separately.
Use the installation prefix instead of `[ns_info home]` if the server home is
configured elsewhere. The installer does not activate SPF policy or overwrite
an explicit evaluator setting. The external adapter requires NaviServer 5.0+
and an nssmtpd version containing `smtpd::spfquery`.

The default `with_spf2=0` builds without native libspf2 linking. To enable the
native evaluator, include nssmtpd in the selected modules and use:

```sh
sudo with_spf2=1 ns_modules="nssmtpd nsstats" bash install-ns.sh build
```

Retain any other modules needed by your installation. Use NaviServer 5.0 or
newer for the Tcl SPF interface and an nssmtpd source revision supporting
`WITH_SPF2` (2.8 or newer). An explicit request with older module sources fails.

On Debian/Ubuntu and Alpine the installer installs development and runtime
libspf2 packages, keeping the runtime package explicitly installed so image
cleanup can remove development packages safely. Other systems require a
preinstalled library and explicit `SPF2_CFLAGS` and/or `SPF2_LIBS`, e.g.
`SPF2_CFLAGS=-I/opt/local/include SPF2_LIBS='-L/opt/local/lib -lspf2'`.
These overrides also work on supported systems. The setting and library flags
are saved in `lib/nsConfig.sh` for subsequent module builds. nssmtpd is cleaned
before rebuilding so toggling support cannot reuse an incompatible object.

Compiling support does not enable mail-policy exceptions. Configure
`spfproc smtpd::libspf2` and selected `greylistspfexceptions` separately.
libspf2 uses the system DNS resolver; it needs no separate service/config file.
