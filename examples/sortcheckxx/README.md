This is an integration of [SortChecker++ tool](https://github.com/yugr/sortcheckxx) to pbuilder.

# How to set up a chroot

In addition to std. setup (described in top README)
* copy `examples/SortCheck/*` to `pbuilder-shared`
* clone `https://github.com/yugr/sortcheckxx` to `pbuilder-shared/sortcheckxx` and build it (via `make clean all`) inside chroot
  (need llvm-dev and libclang-dev installed)

# How to analyze results

SortChecker logs will be stored in `pbuilder-shared/output`.
