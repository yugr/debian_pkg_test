# What's this?

One of the major tasks when developing code analyzers (both static
and dynamic) is testing them on a sufficiently large codebase.

Debian-package-test is a set of simple scripts that simplify
application of code analysis tools to arbitrary Debian packages.
It was originally developed for testing [SortChecker](https://github.com/yugr/sortcheck),
[DirtyFrame](https://github.com/yugr/DirtyFrame), [DirtyPad](https://github.com/yugr/DirtyPad)
and [Valgrind-preload (Pregrind)](https://github.com/yugr/valgrind-preload).
It also supports AddressSanitizer (and can be extended to other sanitizers
too).

Debian-package-test is built on top of standard Debian build tools (pbuilder
et al.). It builds package and runs it's builtin testsuites, if any.
It provides hooks for instrumenting program at compile or at run time.

I only developed this toolset for pragmatic reasons (to test my own tools)
so it's quick, dirty and probably not very well designed.

# Setting up

Firstly you need to inform APT about all existing package repositories:
```
$ SERVER=http://us.archive.ubuntu.com/ubuntu
$ REL=$(lsb_release -cs)
$ COMPONENTS='main universe multiverse restricted'
$ for REPO in $REL $REL-updates $REL-backports $REL-security; do
    echo deb $SERVER $REPO $COMPONENTS
    echo deb-src $SERVER $REPO $COMPONENTS
  done | sudo tee /etc/apt/sources.list
$ sudo apt-get update
```

Then set up a chroot:
* install pbuilder and cowbuilder and add them to sudoers:
```
# Replace `$USER` with user name
$USER ALL=(ALL) NOPASSWD: /usr/sbin/pbuilder
$USER ALL=(ALL) NOPASSWD: /usr/sbin/cowbuilder
```
* create chroot (use `--basepath` if you need multiple chroots):
```
$ sudo cowbuilder --create --distribution $REL --components "$COMPONENTS"
$ sudo cowbuilder --login --distribution $REL --bindmounts pbuilder-shared --save-after-login
# cat > /etc/apt/sources.list
...  # Copy contents of your host sources.list
(Ctrl-D)
# apt-get update
# apt-get upgrade
# # Turn off synches on every dpkg write to speed things up
# echo force-unsafe-io > /etc/dpkg/dpkg.cfg.d/02apt-speedup
# # Turn off man updates to speed up package installation
# echo 'man-db man-db/auto-update boolean false' | debconf-set-selections
# # Avoid gpg (used by adt-run) stalling machine due to lack of entropy
# apt-get install -y --force-yes rng-tools
# rngd -b -r /dev/urandom
# # Install packages for debugging errors inside chroot
# apt-get install vim gdb valgrind
# exit
```
* in case you'll need debuginfo packages for symbolizing backtraces,
  set up APT repos as described [here](https://wiki.ubuntu.com/Debug%20Symbol%20Packages)
* copy /usr/share/doc/pbuilder/examples/B20autopkgtest to pbuilder-hooks
  subdir (can't include it directly due to incompatible license)
* do tool-specific setup; this usually means installing prerequisites, making folder
  for logs, building/installing necessary files inside the chroot; e.g. for
  StackWipe:
```
# apt-get install python
# cd /path/to/pbuilder-shared/StackWipe
# make clean all
```
  (pbuilder-shared/ folder will be shared across host and chroot).
* add tool-specific hooks in pbuilder-shared/hooks

There are three types of hooks:
* environment hook `pbuilder-shared/hooks/env` to modify startup envinronment variables e.g.
  set `PATH`, `LD_LIBRARY_PATH`, `CC`, `CXX`, etc.
* startup hook `pbuilder-shared/hooks/start` (this usually contains a quick smoke test of
  tool's functionality e.g. that it detects some standard error)
* completion hook `pbuilder-shared/hooks/finish` (this may print additional output to console
  or copy necessary files to pbuilder-shared/output folder); note that this hook will
  be called both for successful and failed build

Many example hooks are in `examples/` folder.

# Finding targets

Once set up, you'd want to find packages to run your tool on.

Here's a short list of security-critical software which I typically use for testing
(loosely based on bug reports in existing checkers like [AFL](http://lcamtuf.coredump.cx/afl/#bugs),
[ASan](https://github.com/google/sanitizers/wiki/AddressSanitizerFoundBugs)
or [Fuzzing project](https://blog.fuzzing-project.org/)):
* media: freetype cairo libsdl2 pango1.0 tiff djvulibre libjpeg libpng libtiff libsndfile audiofile openjpeg mupdf flac libmatroska
* media (large): ffmpeg gimp mesa imagemagick vlc evince opencv
* network: openvpn vsftpd curl apache2 clamav bind9 ntp nginx
* crypto: openssh openssl libgcrypt20 gnutls28 botan1.10
* databases: mysql-5.5 mariadb-5.5 postgresql-common db5.3 sqlite3
* compiler/interpreters: gcc clang bash openjdk-6 ghc php5 perl python2.7 lua50 octave
* system: dbus samba gstreamer1.0 systemd
* other: libftdi libxml2 libtasn1-6 dpkg libarchive

Another option is to try several hundred top packages from
[Debian package rating](https://popcon.debian.org/by_vote):
```
# Remove 'head' below to get full list
$ curl http://popcon.debian.org/by_vote 2>/dev/null | awk '/^[0-9]/{print $2}' | xargs ./get_source | head -100 | while read p; do ./is_c_pkg $p && echo $p; done | sort -u
```

You can also use [Debian Code Search](https://codesearch.debian.net) to search for packages which contain relevant APIs
([debian-code-search-cli](https://github.com/FedericoCeratto/debian-code-search-cli) gives cmdline interface).

Or just take first N packages from `apt-cache`:
```
# Remove 'head' below to get full list
$ apt-cache dump | awk '/^Package/ && !/:[^ ]|dbgsym/ { print $2; }' | xargs ./get_source | head -100 | while read p; do ./is_c_pkg $p && echo $p; done | sort -u
```

# Testing

To build and test packages in `paks.lst`, run
```
$ ./test_pkgs $(cat paks.lst)
```

Results will be stored in `test_pkgs.$NUM` for further analysis.

`test_pkgs` can be customized with various cmdline options
(mainly for debugging errors), see `test_pkgs -h` for details.
In particular, to specify Pbuilder chroot use `--pbuilder-opts '--basepath /var/cache/pbuilder/$CHROOT_NAME.cow'`

Note that you might want to cherry-pick a fix for [#855999](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=855999).

# Analyzing results

Filtering, deduplicating and interpreting results are hard to generalize
so must be done by the user.

E.g. in case of SortCheck you can simply apply `sort -u` to all
collected `sortcheck.log`'s. StackWipe does not emit it's own error messages
but rather provokes abnormal behavior in application
so you need to mine "interesting" messages yourself e.g. by comparing output of
```
$ ./find_bugs path/to/logs
```
to reference.

# Known issues

This tool should be easily adaptable to other dynamic checkers
(UBSan, etc.) although I do not have plans to add anything else any time soon.
Ping me if you think this infrastructure may of help for your checker.

Tool fails to run tests for many packages due to
* non-standard makefile names (e.g. GNUmakefile in batmon.app or pcp, makefile in bcpp or t-coffee, Makefile.tests in xml2, etc.)
* weird langs (Haskell, PHP, Ruby, etc.)
* non-standard build system (e.g. SCons in balder2d, waf in sushi, shell scripts in bomstrip, etc.)

Still 50% of packages are testable on average.

# Other approaches

Many Debian packages come with unit-testsuites but most
seem to test only basic functionality and thus do not uncover too many errors
(in case of SortChecker I've mined only 3 bugs out of ~1000 runs).

It may be that system-level automated tests could achieve
better coverage and bugcount. Here's a list of popular
_system_ testsuites:
* Phoronix (http://www.phoronix-test-suite.com)
* LDTP (http://ldtp.freedesktop.org)
* Autotest (http://autotest.readthedocs.org/en/latest/)

Some additional info is available at
* [Ubuntu Autotesting wiki](https://wiki.ubuntu.com/Testing/Automation/)
* [How to test a Tizen PC distribution](https://wiki.tizen.org/wiki/How_to_test_a_Tizen_PC_or_Netbook_distribution)
* [Linux testing wiki](http://zhigang.org/wiki/LinuxTesting)

