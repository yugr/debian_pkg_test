# What's this?

Debian-test is a set of simple scripts to apply SortChecker
to arbitrary Debian package. The tool would
build the package and run it's builtin testsuite (if any).
All actions are run under SortChecker (dynamic checker of qsort calls)
to detect qsort-related bugs.

Note that I only needed this tool for very pragmatic reasons
so it's quick, dirty and probably not very well designed.

# How to run

Before running the tool, setup your system:
* (optional) register all package repos:
```
$ for type in deb deb-src; do
  for dist in trusty trusty-updates trusty-backports trusty-security; do
    echo $type http://us.archive.ubuntu.com/ubuntu $dist main universe multiverse restricted
  done
  done | sudo tee /etc/apt/sources.list
$ sudo apt-get update
```
* install pbuilder and cowbuilder and add them to sudoers:
```
%username% ALL=(ALL) NOPASSWD: /usr/sbin/pbuilder
```
* setup cowbuilder chroot:
```
$ echo "COMPONENTS='main universe multiverse restricted'" > $HOME/.pbuilderrc
$ sudo cowbuilder --create --distribution trusty
$ sudo cowbuilder --login --distribution trusty --save-after-login
# echo "force-unsafe-io" > /etc/dpkg/dpkg.cfg.d/02apt-speedup
# cat > /etc/apt/source.list  # Copy contents of your host sources.list
# apt-get update
# exit
```
* copy SortChecker source code to pbuilder-shared
* copy /usr/share/doc/pbuilder/examples/B20autopkgtest to hooks subdir (available since pbuilder 2.17)
* collect list of 500 source packages via
```
$ ./list_paks.sh 500 > paks.lst
```
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
Still 70% of packages are testable on average.

