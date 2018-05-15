This is an integration of [SortChecker tool](https://github.com/yugr/sortcheck) to pbuilder.

# How to set up a chroot

In addition to std. setup (described in top README)
* copy `examples/SortCheck/*` to `pbuilder-shared`
* copy `SortCheck/*` to `pbuilder-shared/SortCheck` and build it (via `make clean all`) in chroot.
* touch `pbuilder-shared/output/sortcheck.log` (to avoid problems with it being created by default with root-only access)

# How to analyze results

SortChecker logs will be stored in `pbuilder-shared/output/sortcheck.log`.
