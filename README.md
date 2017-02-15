# What's this?

One of the major tasks when developing code analyzers (both static
and dynamic) is testing them on a sufficiently large codebase.

Debian-package-test is a set of simple scripts that simplify
application of code analysis tools to arbitrary Debian packages.
It was originally developed for testing [SortChecker](https://github.com/yugr/sortcheck)
and StackRandomizer (to be published).

Debian-package-test is built on top of standard Debian build tools (pbuilder
et al.). It builds package and runs it's builtin testsuites, if any.
It provides hooks for instrumenting program at compile or at run time.

I only developed this toolset for pragmatic reasons (to test my own tools)
so it's quick, dirty and probably not very well designed.

# Setting up

Firstly you need to inform APT about all existing package repositories:
```
$ SERVER=http://us.archive.ubuntu.com/ubuntu
$ REL=xenial  # trusty for 14.04
$ COMPONENTS='main universe multiverse restricted'
$ for REPO in $REL $REL-updates $REL-backports $REL-security; do
    echo deb $SERVER $REPO $COMPONENTS
    echo deb-src $SERVER $REPO $COMPONENTS
  done | sudo tee /etc/apt/sources.list
$ sudo apt-get update
```

Then you'll need to setup a chroot:
* install pbuilder and cowbuilder and add them to sudoers
  (replace `%username%` with user name):
```
%username% ALL=(ALL) NOPASSWD: /usr/sbin/pbuilder
%username% ALL=(ALL) NOPASSWD: /usr/sbin/cowbuilder
```
* setup the chroot:
```
$ sudo cowbuilder --create --distribution $REL --components 'main universe multiverse restricted'
* copy /usr/share/doc/pbuilder/examples/B20autopkgtest to pbuilder-hooks
  subdir (can't include it directly due to incompatible license)
$ sudo cowbuilder --login --distribution $REL --bindmounts pbuilder-shared --save-after-login
# echo force-unsafe-io > /etc/dpkg/dpkg.cfg.d/02apt-speedup
# # Avoid gpg (used by adt-run) stalling machine due to lack of entropy
# apt-get install -y --force-yes rng-tools
# rngd -b -r /dev/urandom
# apt-get upgrade
# # Turn off man updates to speed up package installation
# echo 'man-db man-db/auto-update boolean false' | debconf-set-selections
# cat > /etc/apt/sources.list
  ...  # Copy contents of your host sources.list
# apt-get update
```
* do tool-specific setup; this usually means installing prerequisites and
  building/installing necessary files inside the chroot; e.g. for
  StackRandomizer:
```
# apt-get install python
# cd /path/to/pbuilder-shared/StackRandomizer
# make clean all
```
* add tool-specific hooks in pbuilder-shared/hooks

There are three types of hooks:
* environment hook `pbuilder-shared/hooks/env` to modify startup envinronment variables e.g.
  set `PATH`, `LD_LIBRARY_PATH`, `CC`, `CXX`, etc.
* startup hook `pbuilder-shared/hooks/start` (this usually contains a quick smoke test of
  tools functionality e.g. that it detects some standard error)
* completion hook `pbuilder-shared/hooks/finish` (this may print additional output to console
  or copy necessary files to pbuilder-shared/output folder)

Here are StackRandomizer hooks:
```
$ cat pbuilder-shared/hooks/env
#!/bin/sh -eu

# Forward all StackRandomizer variables to chroot
for var in $(set | grep '^RAN\w\+=' | cut -d= -f1); do
  echo $(eval "echo $var")
done

# This is useful for debugging
echo 'export V=1'
echo 'export VERBOSE=1'

# We can either intercept CC/CXX environment variables
# or deceive the system by overring GCC with a "fake" wrapper.
# The second approach is ugly but more efficient:
# * some projects simply ignore CC/CXX
# * some treat them differently from GCC
#   (e.g. blt project compilation fails under CC=rancc)
echo 'export PATH=$SHARED_DIR/StackRandomizer/out/fake-gcc:$PATH'

# Do not print warnings to stderr as this may puzzle build system
echo 'export RANCC_OUTPUT=$SHARED_DIR/output/warns.log'$ cat pbuilder-shared/hooks/start
#!/bin/sh -e

# Verify basic functionality
for CC in gcc x86_64-linux-gnu-gcc; do
  echo 'int main() { return 0; }' > /tmp/$$.c
  RANCC_VERBOSE=1 $CC /tmp/$$.c 2>&1 | grep -q 'initial args:'
done

# Create file for warnings with appropriate perms
touch $SHARED_DIR/output/warns.log
chmod a+w $SHARED_DIR/output/warns.log

echo "StackRandomizer: GCC intercepted successfully"
```
and here are SortChecker's ones:
```
$ cat pbuilder-shared/hooks/env
#!/bin/sh -eu
# This will override default gcc and g++ with StackRandomizer's ones
echo 'export SORTCHECK_OPTIONS=print_to_file=$SHARED_DIR/output/sortcheck.log'

$ cat pbuilder-shared/hooks/start
# LD_PRELOAD will not work for setuids
# echo /pbuilder-shared/SortCheck/bin/libsortcheck.so >> /etc/ld.so.preload
```

TODO:
* explain pbuilder-shared
* explain `--disable-hooks`
* provide instructions for sanitizers
* update SR's hooks

# Finding targets

Once you're setup, you'd want to create a list of packages that you want to run your tool on.

Here's a short list of security-critical software in modern Linux
(loosely based on bug reports in existing analyzers like [AFL](http://lcamtuf.coredump.cx/afl/#bugs),
[ASan](https://github.com/google/sanitizers/wiki/AddressSanitizerFoundBugs)
or [Fuzzing project](https://blog.fuzzing-project.org/)):
* media: ffmpeg gimp mesa freetype thunderbird evince opencv alsa-\* cairo libsdl2 pango1.0 tiff djvulibre libjpeg
* network: openssl nginx openvpn xbmc vsftpd curl openssh apache2 gnutls28
* databases: mysql-5.5 mariadb-5.5 postgresql-common db5.3 sqlite3
* system: dbus samba gstreamer1.0 systemd
* interpreters: openjdk-6 ghc php5 perl python2.7 lua50 octave ocaml
* compilers: gcc clang

Another option is getting most popular packages from
[Debian package rating](http://popcon.debian.org/by_vote):
```
# Remove 'head' below to get full list
$ curl http://popcon.debian.org/by_vote 2>/dev/null | awk '/^[0-9]/{print $2}' | xargs ./get_source | head -100 | while read p; do ./is_c_pkg $p && echo $p; done | sort -u
```

Or just use `apt-cache` if you don't care about ratings:
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

TODO
* rerun build without tool on failure (to verify that tool caused it)

# Analyzing results

Filtering, deduplicating and interpreting results are too specific per tool
so must be done by the user.

E.g. in case of SortCheck you can simply apply `sort -u` to all
collected `sortcheck.log`'s. StackRandomizer does not emit it's own error messages
but rather provokes abnormal behavior in application
so you need to mine "interesting" messages yourself e.g. by manually filtering
output of
```
$ grep -riE 'Segmentation fault|Bus error|Illegal instruction|Abort|Terminated|Killed|\<SEGV\>|\<TRAP|Assertion|error:|failed' test_pkgs.3
```

# Known issues

This tool should be easily adaptable to other dynamic checkers
(sanitizers, Valgrind, etc.) although I do not have plans
to implement this any time soon. Ping me if you think it may of help
for your project.

Tool fails to run tests for many packages due to
* non-standard makefile names (e.g. GNUmakefile in batmon.app, makefile in bcpp, Makefile.tests in xml2, etc.)
* weird langs (Haskell, PHP, Ruby, etc.)
* non-standard build system (e.g. SCons in balder2d, waf in sushi, shell scripts in bomstrip, etc.)

Still 50% of packages are testable on average.

# Other approaches

Many Debian packages come with unit-testsuites but most
seem to test only basic functionality and thus do not uncover too many errors
(I've mined just 3 bugs out of ~1000 runs).

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

