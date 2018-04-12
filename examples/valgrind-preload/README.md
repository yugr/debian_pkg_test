This is integration of [valgrind-preload](https://github.com/yugr/valgrind-preload) to pbuilder.
I didn't invest too much time in it but found some real bugs
(see the [Trophies](https://github.com/yugr/valgrind-preload#trophies) section).

# How to set up a chroot

In addition to standard setup, described in top-level README
* copy `examples/valgrind-preload/*` to `pbuilder-shared`
* copy `valgrind-preload/*` to `pbuilder-shared/valgrind-preload` and build it (via `make clean all`) in chroot

As slowdown is quite huge (1+ hours per package), it makes sense to preinstall most common packages in chroot:
```
# apt-get install fakeroot libfakeroot autoconf automake debhelper file gettext libtool m4 man-db libltdl-dev libarchive-dev
```

# How to analyze results

Valgrind logs will be stored in `pbuilder-shared/output`. Interesting ones can be located via
```
$ examples/valgrind-preload/find_vg_errors pbuilder-shared/output/*
```
