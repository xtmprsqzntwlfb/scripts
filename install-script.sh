#!/usr/bin/bash

args="$@"
for file in $args
do
    if [[ -f "install-location.txt" ]]
    then
        link="$(cat install-location.txt)/hack/scripts/$file"
        if [[ -L "$link" ]]
        then
            rm "$link"
        fi
        ln -s "$(realpath $file)" "$link"
    fi
done