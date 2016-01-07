#!/bin/sh

# Simple hacky script to apply SortChecker to arbitrary Debian packages.
# Run as
#   test.sh pak1 pak2...

set -ex

error() {
  echo >&2 "$(basename $0): error: $@"
  exit 1
}

warn() {
  echo >&2 "$(basename $0): warning: $@"
}

sum() {
  res=0
  while read x; do
    res=$((res + x))
  done
  echo $res
}

SHARED_DIR=$PWD/pbuilder-shared
REL=trusty  # Should match pbuilder's chroot
PBUILDER=cowbuilder

#SHELL_ON_ERROR=1
#SHELL_ON_DONE=1

# Do not hang VM...
ulimit -S -v $((512*1024))

if ! test -f hooks/B*autopkgtest; then
  warn "it's recommended to install B92autopkgtest (available in pbuilder since 2.17)"
fi

if ! test -d $SHARED_DIR/sortcheck; then
  error "sortcheck/ sources missing in shared folder $SHARED_DIR"
fi

mkdir -p src $SHARED_DIR
rm -rf src/* $SHARED_DIR/sortcheck.log sortcheck.log

cat <<EOF > pbuilderrc
export COMPONENTS='main universe multiverse restricted'
export SORTCHECK_OPTIONS=print_to_file=$SHARED_DIR/sortcheck.log
export SHARED_DIR=$SHARED_DIR
export SHELL_ON_ERROR=$SHELL_ON_ERROR
export SHELL_ON_DONE=$SHELL_ON_DONE
EOF

N=$#
I=0
for p in $@; do
  I=$((I+1))
  echo "BUILDING PACKAGE $p ($I/$N)"

  # Skip large assets
  size=$(apt-cache show $p/$REL | grep ^Size: | awk '{print $2}' | sum)
  if test $size -gt $(( 128 * 1024 * 1024 )); then
    continue
  fi

  if ! (cd src && apt-get source $p/$REL); then
    # May be caused by changes on server
    warn "failed to download package $p"
    continue
  fi

  if ! ls src | grep -q '\.dsc'; then
    error "no .dsc file in package $p"
  fi

  if ! nice sudo $PBUILDER --build --configfile pbuilderrc --hookdir hooks --bindmounts $SHARED_DIR src/*.dsc; then
    warn "failed to build package $p"
  fi

  if test -f $SHARED_DIR/sortcheck.log; then
    echo "TESTING PACKAGE $p ($I/$N)" >> sortcheck.log
    cat $SHARED_DIR/sortcheck.log >> sortcheck.log
  fi

  rm -rf src/* $SHARED_DIR/sortcheck.log
done

