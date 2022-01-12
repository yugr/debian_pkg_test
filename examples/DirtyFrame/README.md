Prerequisites:
* install `python` (NOT `python3`!) in chroot

Errors can be checked by grepping for error messages in stdout
```
$ grep -i 'SEGV\|SIGBUS\|SIGILL\|Segmentation\|abort\|Program terminated\|fail' test_pkgs.2
```
and comparing against uninstrumented run.
