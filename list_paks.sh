#!/bin/sh

# Simple script to print list of Ubuntu source packages.
# Run as
#   list_paks.sh max_number

set -e
#set -x

N="$1"
if test -z "$N"; then
  N=100
fi

REL=trusty

is_good_package() {
  # Skip virtual packages
  if apt-cache show $1/$REL 2>&1 | grep -q 'No packages found'; then
    return 1
  fi

  # Skip packages which are not present in our distro
  if apt-cache madison $1 | grep -q 'Unable to locate package'; then
    return 1
  fi

  # Skip packages for which sources are missing in Trusty
  if ! apt-cache madison $1 | grep -q trusty; then
    return 1
  fi

  return 0
}

get_good_version() {
  # Sample output:
  # $ apt-cache madison bash 
  # bash | 4.3-7ubuntu1.5 | http://us.archive.ubuntu.com/ubuntu/ trusty-updates/main amd64 Packages
  # bash | 4.3-6ubuntu1 | http://us.archive.ubuntu.com/ubuntu/ trusty/main Sources
  # TODO: choose most recent version?
  apt-cache madison $1 | grep 'trusty.*Source' | cut -f2 -d \| | tr -d ' ' | head -1
}

apt-cache dump \
  | grep '^Package' \
  | awk '{print $2}' \
  | grep -v ':\|dbgsym' \
  | while read p; do
      src=$(apt-cache show $p/$REL 2>/dev/null | grep Source: | awk '{print $2}')
      # TODO: showsrc
      if test -z "$src"; then
        src=$p
      fi

      if is_good_package $src; then
        if test $N -eq 0; then
          break
        fi
        N=$((N - 1))
        echo $src
      fi
    done \
  | tr ' ' '\n' \
  | sort -u

