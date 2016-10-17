#!/usr/bin/env bash

# A simple fuzzer for the LLVM parser. Generates random C programs
# with csmith, compiles them to bitcode with clang, and then runs
# llvm-disasm on the bitcode.

# Assumes that llvm-disasm, csmith and clang are in the PATH, and that
# the CSMITH_PATH environment variable is set to the include directory
# of the csmith installation.

# If a -k argument is given, the temporary files generated by csmith
# and clang are not deleted.

# If an -n argument is given, that sets the number of tests to run,
# for example -n 100. In this mode, stdout lists the seeds of csmith
# programs which cause llvm-disasm to exit with a non-0 exit code.

# If an -s argument is given, that sets the seed used by csmith to
# generate the program, and then tests only that program regardless of
# the -n argument, showing the full output of llvm-disasm.

while getopts "kn:s:" opt; do
    case $opt in
        k)
            KEEP=yes
            ;;
        n)
            NUMTESTS=${OPTARG}
            ;;
        s)
            SEED=${OPTARG}
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
  esac
done

trap 'if [ -z ${KEEP} ]; then rm fuzz-temp-test.c fuzz-temp-test.bc; fi' EXIT

if [ ${SEED+x} ]; then
    csmith -s ${SEED} > fuzz-temp-test.c;
    clang -I${CSMITH_PATH}/runtime -O -g -w -c -emit-llvm fuzz-temp-test.c -o fuzz-temp-test.bc;
    set -e
    llvm-disasm fuzz-temp-test.bc
    exit
fi

RESULT_DIR=${PWD}/fuzz-results
if [ -n "${KEEP}" ]; then
    mkdir fuzz-results;
fi

RESULT=0
for i in `seq 1 ${NUMTESTS:-100}`;
do
    csmith > fuzz-temp-test.c;
    clang -I${CSMITH_PATH}/runtime -O -g -w -c -emit-llvm fuzz-temp-test.c -o fuzz-temp-test.bc;
    llvm-disasm fuzz-temp-test.bc &> /dev/null
    if [ $? -ne 0 ]; then
        RESULT=1
        SEED=$(grep '^ \* Seed:\s*\([0-9]*\)' fuzz-temp-test.c | grep -o '[0-9]*$')
        echo ${SEED}
        if [ -n "${KEEP}" ]; then
            cp fuzz-temp-test.c ${RESULT_DIR}/${SEED}.c;
        fi
    fi
done
exit ${RESULT}
