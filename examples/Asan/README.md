This is a very draft work on integrating AddressSanitizer to pbuilder.
I didn't invest too much time in it but found some real bugs
(see the Trophies section below).

# How to set up a chroot

In addition to standard setup, described in top-level README,
install GCC 6 as described [here](http://askubuntu.com/questions/781972/how-can-i-update-gcc-5-3-to-6-1):

    # apt-get install software-properties-common
    # add-apt-repository ppa:ubuntu-toolchain-r/test
    # apt update
    # apt install gcc-6 g++-6 libasan3 libasan3-dbg
    # update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-6 60 --slave /usr/bin/g++ g++ /usr/bin/g++-6  --slave /usr/bin/x86_64-linux-gnu-gcc x86_64-linux-gnu-gcc /usr/bin/x86_64-linux-gnu-gcc-6  --slave /usr/bin/x86_64-linux-gnu-g++ x86_64-linux-gnu-g++ /usr/bin/x86_64-linux-gnu-g++-6

Then goes the interesting part. By default AddressSanitizer fails when it's not the
very first preloaded library in application:

    ASan runtime does not come first in initial library list; you should either link runtime to your application or manually preload it with LD_PRELOAD

This will fail to work with cowdancer and fakeroot (which Pbuilder is built upon) because they work via `LD_PRELOAD`.
To circumvent this, you'll need to manually patch libasan.so to disable the check
(I [filed a bug upstream](https://github.com/google/sanitizers/issues/786) and
it even [got fixed](https://reviews.llvm.org/rL299188), but it'll take year(s) till the fix propagates to Debian).

BRUTAL HACK BELOW

Disabling the check depends on version of libasan.so.3 that you have but generally you need to
* start tracing code in public function `__asan_init`
* look for a place with several successive calls - that's probably `AsanInitInternal`
* one of the calls (which contains a call to `dl_iterate_phdr` will be the `AsanCheckDynamicRTPrereqs`
* now we need to replace return value of `dl_iterate_phdr` with 0; one of many ways to achieve this is
  to replace `movl` below

      c69a0:       53                      push   %rbx
      c69a1:       48 8d 3d 58 ff ff ff    lea    -0xa8(%rip),%rdi        # c6900 <__interceptor_fclose@@Base+0x850>
      c69a8:       48 83 ec 10             sub    $0x10,%rsp
      c69ac:       48 89 e6                mov    %rsp,%rsi
      c69af:       48 c7 04 24 00 00 00    movq   $0x0,(%rsp)
      c69b6:       00
      c69b7:       64 48 8b 04 25 28 00    mov    %fs:0x28,%rax
      c69be:       00 00
      c69c0:       48 89 44 24 08          mov    %rax,0x8(%rsp)
      c69c5:       31 c0                   xor    %eax,%eax
      c69c7:       e8 64 82 f5 ff          callq  1ec30 <dl_iterate_phdr@plt>
      c69cc:       48 8b 1c 24             mov    (%rsp),%rbx
      c69d0:       48 85 db                test   %rbx,%rbx
      c69d3:       74 14                   je     c69e9 <__interceptor_fclose@@Base+0x939>

  with

      c69cc:       48 31 db                xor    %rbx, %rbx
      c69cf:       90                      nop

# How to run

As usual but I only tested under pbuilder for now so enable it via

    export PBUILDER=pbuilder

before running `test_pkgs`.

# How to analyze results

As usual, Asan reports will be stored in pbuilder-shared/output

# Trophies

* [tar: Read overflow in strip_compression_suffix](https://savannah.gnu.org/support/index.php?109281)
* [iproute2: Buffer overflow in inverttable](http://lists.openwall.net/netdev/2017/03/24/56)
* [dbus: Read overflow in test/corrupt.c](https://bugs.freedesktop.org/show_bug.cgi?id=100568) (fixed)

(as well as some other bugs already fixed in upstream versions).

# TODO

Investigate build fails:
* fail on missing libpthread in java with preloaded libasan (e.g. in db5.3)
* atk1.0 ("warning: the use of `tmpnam' is dangerous, better use `mkstemp'")
* fix Asan bugs in upstream
