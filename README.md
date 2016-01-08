# What's this?

Debian-test is a set of simple scripts to test SortChecker
(which itself is a simple dynamic checker of qsort usage)
with arbitrary Debian packages.
Debian-test builds package and runs it's builtin testsuites (if any).
The system is instrumented with SortChecker to detect qsort-related bugs
in the package code or bugs in SortChecker itself.

Note that I only needed this tool for very pragmatic reasons
so it's quick, dirty and probably not very well designed.

# How to run

Before running the tool, setup your system:
* (optional) register all package repos:
```
$ SERVER=http://us.archive.ubuntu.com/ubuntu
$ REL=trusty
$ COMPONENTS='main universe multiverse restricted'
$ for REPO in $REL $REL-updates $REL-backports $REL-security; do
    echo deb $SERVER $REPO $COMPONENTS
    echo deb-src $SERVER $REPO $COMPONENTS
  done | sudo tee /etc/apt/sources.list
$ sudo apt-get update
```
* install pbuilder and cowbuilder and add them to sudoers:
```
%username% ALL=(ALL) NOPASSWD: /usr/sbin/pbuilder
```
* setup cowbuilder chroot:
```
$ sudo cowbuilder --create --distribution trusty --components 'main universe multiverse restricted'
$ sudo cowbuilder --login --distribution trusty --save-after-login
# echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup
# cat > /etc/apt/source.list  # Copy contents of your host sources.list
# apt-get update
# exit
```
* copy SortChecker source code to pbuilder-shared
* (optional) copy /usr/share/doc/pbuilder/examples/B20autopkgtest to hooks subdir (can't include it directly due to incompatible license)
* collect list of 500 source packages via
```
$ ./list_paks.sh 500 > paks.lst
```
* rather than checking random 500 packages, you could select the most interesting e.g.
  * media: ffmpeg gimp mesa freetype thunderbird evince opencv alsa-\* cairo libsdl2 pango1.0 tiff djvulibre
  * network: openssl nginx openvpn xbmc vsftpd curl openssh apache2 gnutls28
  * databases: mysql-5.5 mariadb-5.5 postgresql-common db5.3 sqlite3
  * system: dbus samba gstreamer1.0 systemd
  * interpreters: openjdk-6 ghc php5 perl python2.7 lua50 octave ocaml
* finally run tests:
```
$ ./test_paks.sh $(cat paks.lst)
```
* after completion, detected errors will be stored in sortcheck.log

You can customize behavior of test\_paks.sh with environment variables:
* SHELL\_ON\_ERROR - drop to root shell on error
* SHELL\_ON\_DONE - drop to root shell after build and test

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

[Debian package rating](http://popcon.debian.org/by_vote)
may be useful to prioritize packages for testing.

# Other approaches

Debian packages provide a huge supply of automated tests but
seem to test only basic functionality and thus do not uncover too many errors
(I've mined just 3 bugs out of ~1000 runs).

It may be that system-level automated tests could achieve
much better coverage and bugcount. Here's a list of popular
system testsuites:
* Phoronix (http://www.phoronix-test-suite.com)
* LDTP (http://ldtp.freedesktop.org)
* Autotest (http://autotest.readthedocs.org/en/latest/)

Some additional info is available at
* [Ubuntu Autotesting wiki](https://wiki.ubuntu.com/Testing/Automation/)
* [How to test a Tizen PC distribution](https://wiki.tizen.org/wiki/How_to_test_a_Tizen_PC_or_Netbook_distribution)
* [Linux testing wiki](http://zhigang.org/wiki/LinuxTesting)

