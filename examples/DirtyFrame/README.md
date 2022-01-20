Prerequisites:
* install `python` (NOT `python3`!) in chroot

Errors can be checked by grepping for error messages in stdout
```
$ grep -rv -- '\<make.*:\|libsigsegv\|-error\|Timeout process; sleep\|ERROR: 0' test_pkgs.* | grep -i 'SEGV\|SIGBUS\|SIGILL\|Segmentation\|abort\|Program terminated\|\<error\>'
```
and comparing against uninstrumented run.
