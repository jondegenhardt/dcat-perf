#! /bin/bash

if [ $# -lt 2 ]; then
    echo "Synopsis: $0 <instrumented-program-path> <dcompiler-name-or-path>"
    exit 1
fi

prog=$1
shift

dcompiler=$1
shift

ldc_profdata_tool_name=ldc-profdata
ldc_profdata_tool=$ldc_prof_tool_name

dcompiler_path="$(type -P $dcompiler)"

if [ -n ${dcompiler_path} ]; then
    ldc_profdata_tool=$(dirname $dcompiler_path)/${ldc_profdata_tool_name}
fi

# Delete any prior files
for f in profile.*.raw; do
    if [ -e $f ]; then
        rm $f
    fi
done

if [ -e app.profdata ]; then
   rm -f app.profdata
fi

for t in `$prog --names`; do \
    $prog -t $t profile_data_1.txt > /dev/null;
    cat profile_data_1.txt | $prog -t $t > /dev/null;
done;

${ldc_profdata_tool} merge -o app.profdata profile.*.raw
