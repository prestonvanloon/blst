#!/bin/sh -e
#
# The script allows to override 'CC', 'CFLAGS' and 'flavour' at command
# line, as well as specify additional compiler flags. For example to
# compile for x32:
#
#	/some/where/build.sh flavour=elf32 -mx32
#
# To cross-compile for mingw/Windows:
#
#	/some/where/build.sh flavour=mingw64 CC=x86_64-w64-mingw32-gcc
#
# In addition script recognizes -shared flag and creates shared library
# alongside libblst.lib.

TOP=`dirname $0`/src

CC=${CC:-cc}
# if -Werror stands in a way, bypass with -Wno-error on command line
CFLAGS=${CFLAGS:--O -march=native -mno-avx -fPIC -Wall -Wextra -Werror}
PERL=${PERL:-perl}

case `uname -s` in
    Darwin)	flavour=macosx;;
    CYGWIN*)	flavour=mingw64;;
    MINGW*)	flavour=mingw64;;
    *)		flavour=elf;;
esac

unset share
while [ "x$1" != "x" ]; do
    case $1 in
        -shared)    shared=1;;
        -*)         CFLAGS="$CFLAGS $1";;
        *=*)        eval "$1";;
    esac
    shift
done

rm -f libblst.a
trap '[ $? -ne 0 ] && rm -f libblst.a; rm -f *.o' 0

(set -x; ${CC} ${CFLAGS} -c ${TOP}/server.c)

for pl in ${TOP}/asm/*-x86_64.pl; do
    s=`basename $pl .pl`.s
    ${PERL} $pl $flavour > $s
    (set -x; ${CC} ${CFLAGS} -c $s)
    rm -f $s
done

(set -x; ${AR:-ar} rc libblst.a *.o)

if [ $shared ]; then
    case $flavour in
        macosx) echo "-shared is not supported"; exit 1;;
        mingw*) sharedlib=blst.dll;;
	*)      sharedlib=libblst.so;;
    esac
    echo "{ global: blst_*; BLS12_381_*; local: *; };" |\
    (set -x; ${CC} -shared -o $sharedlib ${CFLAGS} libblst.a \
                   -Wl,-Bsymbolic,--require-defined=blst_keygen \
                   -Wl,--version-script=/dev/fd/0)
fi
